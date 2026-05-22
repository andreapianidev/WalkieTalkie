//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - RadioManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer
import os.log

struct RadioStation {
    let id: Int
    let name: String
    let country: String
    let frequency: String
    let streamURL: String
    let genre: String

    /// Le stazioni con id > 10 sono internazionali premium (Brasile, Giappone, Australia, Canada, ecc.)
    /// e richiedono Talky Pro per essere riprodotte.
    var isPro: Bool { id > 10 }
}

class RadioManager: NSObject, ObservableObject {
    static let shared = RadioManager()
    
    private var radioPlayer: AVPlayer?
    private let logger = Logger.shared
    private let firebaseManager = FirebaseManager.shared
    
    @Published var isPlaying = false
    @Published var currentStation: RadioStation?
    @Published var volume: Float = 0.5
    @Published var isBuffering = false
    /// Diventa `true` quando l'utente tenta di riprodurre una stazione Pro senza essere Pro.
    /// La UI dovrebbe osservare questo flag, mostrare il paywall e poi resettarlo a `false`.
    @Published var blockedByPaywall: Bool = false
    
    // Lista di stazioni radio internazionali — URL verificati live (maggio 2026).
    // Le prime 10 (id 1-10) sono Free; dalla 11 in poi sono Pro.
    let radioStations: [RadioStation] = [
        // MARK: - Free (Italia + grandi broadcaster europei)
        RadioStation(id: 1, name: "RTL 102.5", country: "Italia", frequency: "102.5", streamURL: "https://streamingv2.shoutcast.com/rtl-1025", genre: "Pop"),
        RadioStation(id: 2, name: "Radio Deejay", country: "Italia", frequency: "106.2", streamURL: "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/radiodeejay/radiodeejay/master_ma.m3u8", genre: "Pop"),
        RadioStation(id: 3, name: "Rai Radio 1", country: "Italia", frequency: "89.7", streamURL: "http://icestreaming.rai.it/1.mp3", genre: "News"),
        RadioStation(id: 4, name: "Radio 24", country: "Italia", frequency: "104.4", streamURL: "http://shoutcast2.radio24.it:8000/", genre: "News"),
        RadioStation(id: 5, name: "NRJ", country: "Francia", frequency: "100.3", streamURL: "https://streaming.nrjaudio.fm/oumvmk8fnozc", genre: "Pop"),
        RadioStation(id: 6, name: "France Inter", country: "Francia", frequency: "87.8", streamURL: "http://icecast.radiofrance.fr/franceinter-hifi.aac", genre: "Talk"),
        RadioStation(id: 7, name: "Antenne Bayern", country: "Germania", frequency: "103.2", streamURL: "https://s1-webradio.antenne.de/antenne", genre: "Pop"),
        RadioStation(id: 8, name: "BBC Radio 2", country: "UK", frequency: "88.0", streamURL: "http://as-hls-ww-live.akamaized.net/pool_74208725/live/ww/bbc_radio_two/bbc_radio_two.isml/bbc_radio_two-audio%3d128000.norewind.m3u8", genre: "Pop"),
        RadioStation(id: 9, name: "Capital FM", country: "UK", frequency: "95.8", streamURL: "https://media-ssl.musicradio.com/CapitalMP3", genre: "Pop"),
        RadioStation(id: 10, name: "Los 40", country: "Spagna", frequency: "93.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40.mp3", genre: "Pop"),

        // MARK: - Pro internazionali
        // Francia
        RadioStation(id: 11, name: "Europe 1", country: "Francia", frequency: "104.7", streamURL: "https://europe1.lmn.fm/europe1.mp3", genre: "News"),
        RadioStation(id: 12, name: "FIP", country: "Francia", frequency: "105.1", streamURL: "http://icecast.radiofrance.fr/fip-hifi.aac", genre: "Eclectic"),
        RadioStation(id: 13, name: "France Info", country: "Francia", frequency: "105.5", streamURL: "http://direct.franceinfo.fr/live/franceinfo-midfi.mp3", genre: "News"),
        // Germania
        RadioStation(id: 14, name: "1LIVE", country: "Germania", frequency: "106.7", streamURL: "http://wdr-1live-live.icecast.wdr.de/wdr/1live/live/mp3/128/stream.mp3", genre: "Pop"),
        RadioStation(id: 15, name: "SWR3", country: "Germania", frequency: "99.9", streamURL: "https://liveradio.swr.de/sw282p3/swr3/play.mp3", genre: "Pop"),
        // UK
        RadioStation(id: 16, name: "BBC Radio 4", country: "UK", frequency: "92.4", streamURL: "http://as-hls-ww-live.akamaized.net/pool_55057080/live/ww/bbc_radio_fourfm/bbc_radio_fourfm.isml/bbc_radio_fourfm-audio%3d128000.norewind.m3u8", genre: "Talk"),
        RadioStation(id: 17, name: "BBC World Service", country: "UK", frequency: "648", streamURL: "http://stream.live.vc.bbcmedia.co.uk/bbc_world_service", genre: "News"),
        RadioStation(id: 18, name: "LBC", country: "UK", frequency: "97.3", streamURL: "http://media-ice.musicradio.com/LBCUK", genre: "Talk"),
        // Spagna
        RadioStation(id: 19, name: "Cadena SER", country: "Spagna", frequency: "105.4", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/CADENASER.mp3", genre: "News"),
        RadioStation(id: 20, name: "Cadena 100", country: "Spagna", frequency: "100.0", streamURL: "http://cadena100-streamers-mp3.flumotion.com/cope/cadena100.mp3", genre: "Pop"),
        // USA
        RadioStation(id: 21, name: "Radio Paradise", country: "USA", frequency: "—", streamURL: "http://stream-uk1.radioparadise.com/aac-320", genre: "Eclectic"),
        RadioStation(id: 22, name: "101 Smooth Jazz", country: "USA", frequency: "101.0", streamURL: "http://jking.cdnstream1.com/b22139_128mp3", genre: "Jazz"),
        RadioStation(id: 23, name: "Classic Vinyl HD", country: "USA", frequency: "—", streamURL: "https://icecast.walmradio.com:8443/classic", genre: "Oldies"),
        RadioStation(id: 24, name: "Adroit Jazz Underground", country: "USA", frequency: "—", streamURL: "https://icecast.walmradio.com:8443/jazz", genre: "Jazz"),
        // Australia
        RadioStation(id: 25, name: "Triple J", country: "Australia", frequency: "105.7", streamURL: "https://live-radio01.mediahubaustralia.com/2TJW/mp3/", genre: "Alternative"),
        RadioStation(id: 26, name: "ABC News Radio", country: "Australia", frequency: "630", streamURL: "http://abc.streamguys1.com/live/newsradio/icecast.audio", genre: "News"),
        RadioStation(id: 27, name: "2GB Sydney", country: "Australia", frequency: "873", streamURL: "http://playerservices.streamtheworld.com/api/livestream-redirect/2GB.mp3", genre: "Talk"),
        // Olanda
        RadioStation(id: 28, name: "Radio 538", country: "Olanda", frequency: "102.1", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO538.mp3", genre: "Dance"),
        RadioStation(id: 29, name: "NPO Radio 2", country: "Olanda", frequency: "92.6", streamURL: "http://icecast.omroep.nl/radio2-bb-mp3", genre: "Pop"),
        RadioStation(id: 30, name: "Qmusic", country: "Olanda", frequency: "100.7", streamURL: "https://icecast-qmusicnl-cdp.triple-it.nl/Qmusic_nl_live_96.mp3", genre: "Pop"),
        // Belgio
        RadioStation(id: 31, name: "Studio Brussel", country: "Belgio", frequency: "100.7", streamURL: "https://icecast.vrtcdn.be/stubru-high.mp3", genre: "Alternative"),
        RadioStation(id: 32, name: "VRT Radio 1", country: "Belgio", frequency: "91.7", streamURL: "http://icecast.vrtcdn.be/radio1-high.mp3", genre: "Talk"),
        RadioStation(id: 33, name: "Joe", country: "Belgio", frequency: "95.0", streamURL: "https://icecast-qmusicbe-cdp.triple-it.nl/joe.mp3", genre: "Oldies"),
        // Svizzera
        RadioStation(id: 34, name: "Energy Zurich", country: "Svizzera", frequency: "100.9", streamURL: "https://energyzuerich.ice.infomaniak.ch/energyzuerich-high.mp3", genre: "Dance"),
        RadioStation(id: 35, name: "SRF 3", country: "Svizzera", frequency: "99.1", streamURL: "http://stream.srg-ssr.ch/m/drs3/mp3_128", genre: "Pop"),
        RadioStation(id: 36, name: "Radio Swiss Jazz", country: "Svizzera", frequency: "—", streamURL: "http://stream.srg-ssr.ch/m/rsj/mp3_128", genre: "Jazz"),
        // Austria
        RadioStation(id: 37, name: "Ö3 Hitradio", country: "Austria", frequency: "99.9", streamURL: "https://orf-live.ors-shoutcast.at/oe3-q2a", genre: "Pop"),
        // Norvegia
        RadioStation(id: 38, name: "NRK P3", country: "Norvegia", frequency: "92.0", streamURL: "https://cdn0-47115-liveicecast0.dna.contentdelivery.net/p3_mp3_h", genre: "Pop"),
        RadioStation(id: 39, name: "P4 Norge", country: "Norvegia", frequency: "100.7", streamURL: "https://p4.p4groupaudio.com/P04_AH", genre: "Pop"),
        // Danimarca
        RadioStation(id: 40, name: "DR P3", country: "Danimarca", frequency: "96.5", streamURL: "http://live-icy.gslb01.dr.dk/A/A05H.mp3", genre: "Pop"),
        RadioStation(id: 41, name: "Nova FM", country: "Danimarca", frequency: "94.6", streamURL: "https://live-bauerdk.sharp-stream.com/nova_dk_mp3", genre: "Pop"),
        // Svezia
        RadioStation(id: 42, name: "Sveriges Radio P3", country: "Svezia", frequency: "99.3", streamURL: "https://live1.sr.se/p3-mp3-96", genre: "Pop"),
        RadioStation(id: 43, name: "RIX FM", country: "Svezia", frequency: "106.7", streamURL: "https://fm01-ice.stream.khz.se/fm01_mp3", genre: "Pop"),
        RadioStation(id: 44, name: "Bandit Rock", country: "Svezia", frequency: "106.3", streamURL: "http://fm02-ice.stream.khz.se/fm02_mp3", genre: "Rock"),
        // Finlandia
        RadioStation(id: 45, name: "Yle Radio Suomi", country: "Finlandia", frequency: "94.0", streamURL: "http://icecast.live.yle.fi/radio/YleRS/icecast.audio", genre: "Talk"),
        RadioStation(id: 46, name: "Radio Nova", country: "Finlandia", frequency: "106.2", streamURL: "https://stream-redirect.bauermedia.fi/radionova/radionova_64.aac", genre: "Pop"),
        // Polonia
        RadioStation(id: 47, name: "RMF FM", country: "Polonia", frequency: "102.8", streamURL: "http://195.150.20.242:8000/rmf_fm", genre: "Pop"),
        RadioStation(id: 48, name: "Radio Zet", country: "Polonia", frequency: "90.9", streamURL: "http://zet-net-01.cdn.eurozet.pl:8400/", genre: "Pop"),
        RadioStation(id: 49, name: "Radio 357", country: "Polonia", frequency: "—", streamURL: "https://n-11-21.dcs.redcdn.pl/sc/o2/radio357/live/radio357_pr.livx?preroll=0", genre: "Talk"),
        // Repubblica Ceca
        RadioStation(id: 50, name: "Evropa 2", country: "Rep. Ceca", frequency: "88.2", streamURL: "https://ice.actve.net/fm-evropa2-128", genre: "Pop"),
        RadioStation(id: 51, name: "Frekvence 1", country: "Rep. Ceca", frequency: "102.5", streamURL: "https://ice.actve.net/fm-frekvence1-128", genre: "Pop"),
        // Ungheria
        RadioStation(id: 52, name: "Retro Rádió", country: "Ungheria", frequency: "104.2", streamURL: "https://icast.connectmedia.hu/5001/live.mp3", genre: "Oldies"),
        RadioStation(id: 53, name: "Klubrádió", country: "Ungheria", frequency: "92.9", streamURL: "https://a7.asurahosting.com:8160/radio.mp3", genre: "Talk"),
        // Romania
        RadioStation(id: 54, name: "Kiss FM", country: "Romania", frequency: "96.1", streamURL: "https://live.kissfm.ro/kissfm.aacp", genre: "Pop"),
        RadioStation(id: 55, name: "Radio România Actualități", country: "Romania", frequency: "98.6", streamURL: "http://89.238.227.6:8006/", genre: "News"),
        // Ucraina
        RadioStation(id: 56, name: "Hit FM", country: "Ucraina", frequency: "96.4", streamURL: "http://195.95.206.17/HitFM", genre: "Pop"),
        RadioStation(id: 57, name: "Kiss FM Ukraine", country: "Ucraina", frequency: "106.5", streamURL: "http://online.kissfm.ua/KissFM", genre: "Dance"),
        // Russia
        RadioStation(id: 58, name: "Europa Plus", country: "Russia", frequency: "106.2", streamURL: "http://ep256.hostingradio.ru:8052/europaplus256.mp3", genre: "Pop"),
        RadioStation(id: 59, name: "Vesti FM", country: "Russia", frequency: "97.6", streamURL: "http://icecast.vgtrk.cdnvideo.ru/vestifm_mp3_192kbps", genre: "News"),
        RadioStation(id: 60, name: "Retro FM", country: "Russia", frequency: "88.3", streamURL: "http://retroserver.streamr.ru:8043/retro256.mp3", genre: "Oldies"),
        // Grecia
        RadioStation(id: 61, name: "Sfera 102.2", country: "Grecia", frequency: "102.2", streamURL: "http://sfera.live24.gr/sfera4132", genre: "Pop"),
        RadioStation(id: 62, name: "Sport FM 94.6", country: "Grecia", frequency: "94.6", streamURL: "http://netradio.live24.gr/sportfm7712", genre: "Sport"),
        // Turchia
        RadioStation(id: 63, name: "Power FM", country: "Turchia", frequency: "103.2", streamURL: "https://listen.powerapp.com.tr/powerfm/mpeg/icecast.audio", genre: "Pop"),
        // Israele
        RadioStation(id: 64, name: "Galgalatz", country: "Israele", frequency: "91.8", streamURL: "https://glzwizzlv.bynetcdn.com/glglz_mp3", genre: "Rock"),
        RadioStation(id: 65, name: "Kan Bet", country: "Israele", frequency: "95.5", streamURL: "https://25583.live.streamtheworld.com/KAN_BET.mp3", genre: "Talk"),
        // Portogallo
        RadioStation(id: 66, name: "Antena 1", country: "Portogallo", frequency: "95.7", streamURL: "http://streaming-live-app.rtp.pt/liveradio/antena180a/playlist.m3u8", genre: "Pop"),
        RadioStation(id: 67, name: "RFM", country: "Portogallo", frequency: "93.2", streamURL: "https://23603.live.streamtheworld.com/RFMAAC.aac", genre: "Pop"),
        // Sud Africa
        RadioStation(id: 68, name: "5FM", country: "Sud Africa", frequency: "98.4", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/5FM.mp3", genre: "Pop"),
        RadioStation(id: 69, name: "Metro FM", country: "Sud Africa", frequency: "94.7", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/METRO_FM.mp3", genre: "Urban"),
        RadioStation(id: 70, name: "Jacaranda FM", country: "Sud Africa", frequency: "94.2", streamURL: "https://edge.iono.fm/xice/jacarandafm_live_medium.aac", genre: "Pop"),
        // India
        RadioStation(id: 71, name: "Red FM", country: "India", frequency: "93.5", streamURL: "http://air.pc.cdn.bitgravity.com/air/live/pbaudio056/playlist.m3u8", genre: "Bollywood"),
        RadioStation(id: 72, name: "Vividh Bharati", country: "India", frequency: "1188", streamURL: "https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8", genre: "Bollywood"),
        // Giappone
        RadioStation(id: 73, name: "Japan Hits", country: "Giappone", frequency: "—", streamURL: "http://quincy.torontocast.com:2020/stream.mp3", genre: "J-Pop"),
        RadioStation(id: 74, name: "Jazz Sakura", country: "Giappone", frequency: "—", streamURL: "http://kathy.torontocast.com:3330/stream/1/", genre: "Jazz"),
        // Thailandia
        RadioStation(id: 75, name: "Cool Fahrenheit", country: "Thailandia", frequency: "93.0", streamURL: "https://coolism-web.cdn.byteark.com/live/playlist.m3u8", genre: "Pop"),
        // Messico
        RadioStation(id: 76, name: "Los 40 México", country: "Messico", frequency: "102.5", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40_MEXICOAAC.aac", genre: "Pop"),
        RadioStation(id: 77, name: "Exa FM", country: "Messico", frequency: "104.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/XHPSFMAAC.aac", genre: "Pop"),
        // Argentina
        RadioStation(id: 78, name: "Aspen 102.3", country: "Argentina", frequency: "102.3", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/ASPEN.mp3", genre: "Pop"),
        RadioStation(id: 79, name: "La 100", country: "Argentina", frequency: "99.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/FM999_56.mp3", genre: "Pop"),
        // Brasile
        RadioStation(id: 80, name: "Alpha FM", country: "Brasile", frequency: "101.7", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_ALPHAFM_ADP.aac", genre: "Easy"),
        RadioStation(id: 81, name: "Rádio Mix FM", country: "Brasile", frequency: "106.3", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/MIXFM_SAOPAULOAAC.aac", genre: "Pop"),
        // Cile
        RadioStation(id: 82, name: "Pudahuel", country: "Cile", frequency: "90.5", streamURL: "http://26593.live.streamtheworld.com:3690/PUDAHUEL_SC", genre: "Pop"),
        // Colombia
        RadioStation(id: 83, name: "Caracol Radio", country: "Colombia", frequency: "100.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/CARACOL_RADIOAAC.aac", genre: "News")
    ]
    
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .mixWithOthers])
            try audioSession.setActive(true)
            logger.logAudioInfo("Radio audio session configurata per background playback")
        } catch {
            logger.logAudioError(error, context: "Configurazione radio audio session")
        }
    }
    
    // MARK: - Radio Controls
    
    func playStation(_ station: RadioStation) {
        // Pro gate: blocca la riproduzione delle stazioni internazionali premium per utenti non Pro.
        // La UI osserva `blockedByPaywall` e si occupa di mostrare il paywall.
        if station.isPro && !UserDefaults.standard.bool(forKey: "fastboot_isProUser") {
            logger.logInfo("Riproduzione bloccata da paywall per stazione Pro: \(station.name)")
            blockedByPaywall = true
            return
        }

        stopRadio()

        guard let url = URL(string: station.streamURL) else {
            logger.logAudioError(NSError(domain: "RadioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL non valido"]), context: "Play station")
            return
        }
        
        isBuffering = true
        currentStation = station
        
        radioPlayer = AVPlayer(url: url)
        radioPlayer?.volume = volume
        
        // Osserva lo stato del player e gli errori
        radioPlayer?.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
        radioPlayer?.addObserver(self, forKeyPath: "error", options: [.new], context: nil)
        
        // Reset errore precedente
        lastError = nil
        
        radioPlayer?.play()
        isPlaying = true
        
        // Configura Now Playing Info per Control Center
        setupNowPlayingInfo(for: station)
        
        // Traccia l'uso della radio in Firebase
        firebaseManager.trackRadioUsage(station: "\(station.name) - \(station.country)")
        
        logger.logAudioInfo("Avviata riproduzione: \(station.name) - \(station.country)")
    }
    
    func stopRadio() {
        radioPlayer?.pause()
        radioPlayer?.removeObserver(self, forKeyPath: "timeControlStatus")
        radioPlayer?.removeObserver(self, forKeyPath: "error")
        radioPlayer = nil
        isPlaying = false
        isBuffering = false
        currentStation = nil
        lastError = nil
        
        // Cancella Now Playing Info
        clearNowPlayingInfo()
        
        logger.logAudioInfo("Radio fermata")
    }
    
    func pauseRadio() {
        radioPlayer?.pause()
        isPlaying = false
        
        // Aggiorna Now Playing Info
        if let station = currentStation {
            setupNowPlayingInfo(for: station)
        }
        
        logger.logAudioInfo("Radio in pausa")
    }
    
    func resumeRadio() {
        radioPlayer?.play()
        isPlaying = true
        
        // Aggiorna Now Playing Info
        if let station = currentStation {
            setupNowPlayingInfo(for: station)
        }
        
        logger.logAudioInfo("Radio ripresa")
    }
    
    func setVolume(_ newVolume: Float) {
        volume = newVolume
        radioPlayer?.volume = newVolume
    }
    
    // MARK: - Free / Pro Stations

    /// Prime 10 stazioni (id 1...10) disponibili a tutti gli utenti.
    var freeStations: [RadioStation] {
        radioStations.filter { $0.id <= 10 }
    }

    /// Stazioni internazionali premium (id > 10) sbloccabili con Talky Pro.
    var proStations: [RadioStation] {
        radioStations.filter { $0.id > 10 }
    }

    // MARK: - Station Selection

    func getStationByFrequency(_ frequency: String) -> RadioStation? {
        return radioStations.first { $0.frequency == frequency }
    }
    
    func getStationsByCountry(_ country: String) -> [RadioStation] {
        return radioStations.filter { $0.country == country }
    }
    
    func getStationsByGenre(_ genre: String) -> [RadioStation] {
        return radioStations.filter { $0.genre == genre }
    }
    
    func nextStation() {
        guard let current = currentStation,
              let currentIndex = radioStations.firstIndex(where: { $0.id == current.id }) else {
            if !radioStations.isEmpty {
                playStation(radioStations[0])
            }
            return
        }
        
        let nextIndex = (currentIndex + 1) % radioStations.count
        playStation(radioStations[nextIndex])
    }
    
    func previousStation() {
        guard let current = currentStation,
              let currentIndex = radioStations.firstIndex(where: { $0.id == current.id }) else {
            if !radioStations.isEmpty, let lastStation = radioStations.last {
                playStation(lastStation)
            }
            return
        }
        
        let previousIndex = currentIndex == 0 ? radioStations.count - 1 : currentIndex - 1
        playStation(radioStations[previousIndex])
    }
    
    // MARK: - Now Playing Info
    
    private func setupNowPlayingInfo(for station: RadioStation) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = station.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = "\(station.country) - \(station.frequency) FM"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Talky Radio"
        nowPlayingInfo[MPMediaItemPropertyGenre] = station.genre
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        logger.logAudioInfo("Now Playing Info configurato per \(station.name)")
    }
    
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        logger.logAudioInfo("Now Playing Info cancellato")
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resumeRadio()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pauseRadio()
            return .success
        }
        
        // Next track command
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextStation()
            return .success
        }
        
        // Previous track command
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousStation()
            return .success
        }
        
        logger.logAudioInfo("Remote Command Center configurato")
    }
    
    // MARK: - Error Handling
    
    @Published var lastError: String?
    
    private func handlePlaybackError(_ error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let error = error {
                self.lastError = "Errore riproduzione: \(error.localizedDescription)"
                self.logger.logAudioError(error, context: "Errore stream radio")
            } else {
                self.lastError = "Stream non disponibile (404 - File Not Found)"
                self.logger.logAudioWarning("Stream radio non disponibile - URL potrebbe essere scaduto")
            }
            
            self.isPlaying = false
            self.isBuffering = false
        }
    }
    
    // MARK: - KVO Observer
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      let player = self.radioPlayer else { return }
                
                switch player.timeControlStatus {
                case .playing:
                    self.isBuffering = false
                    self.isPlaying = true
                    self.lastError = nil // Reset errore quando la riproduzione funziona
                case .paused:
                    self.isBuffering = false
                    self.isPlaying = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                @unknown default:
                    break
                }
            }
        } else if keyPath == "error" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      let player = self.radioPlayer else { return }
                
                if let error = player.error {
                    self.handlePlaybackError(error)
                }
            }
        }
    }
    
    deinit {
        stopRadio()
    }
}