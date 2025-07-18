//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - RadioManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import Foundation
import AVFoundation
import Combine
import os.log

struct RadioStation {
    let id: Int
    let name: String
    let country: String
    let frequency: String
    let streamURL: String
    let genre: String
}

class RadioManager: NSObject, ObservableObject {
    static let shared = RadioManager()
    
    private var radioPlayer: AVPlayer?
    private let logger = Logger.shared
    
    @Published var isPlaying = false
    @Published var currentStation: RadioStation?
    @Published var volume: Float = 0.5
    @Published var isBuffering = false
    
    // Lista di stazioni radio internazionali
    let radioStations: [RadioStation] = [
        // Italia
        RadioStation(id: 1, name: "RTL 102.5", country: "Italia", frequency: "102.5", streamURL: "https://streamingv2.shoutcast.com/rtl-1025", genre: "Pop"),
        RadioStation(id: 2, name: "Radio Deejay", country: "Italia", frequency: "106.2", streamURL: "https://radiodeejay-lh.akamaihd.net/i/RadioDeejay_Live_1@189857/master.m3u8", genre: "Pop"),
        RadioStation(id: 3, name: "Radio Capital", country: "Italia", frequency: "103.0", streamURL: "https://radiocapital-lh.akamaihd.net/i/RadioCapital_Live_1@196312/master.m3u8", genre: "Rock"),
        
        // Francia
        RadioStation(id: 4, name: "NRJ", country: "Francia", frequency: "100.3", streamURL: "https://streaming.nrjaudio.fm/oumvmk8fnozc", genre: "Pop"),
        RadioStation(id: 5, name: "Europe 1", country: "Francia", frequency: "104.7", streamURL: "https://europe1.lmn.fm/europe1.mp3", genre: "News"),
        
        // Germania
        RadioStation(id: 6, name: "Antenne Bayern", country: "Germania", frequency: "103.2", streamURL: "https://s1-webradio.antenne.de/antenne", genre: "Pop"),
        RadioStation(id: 7, name: "Radio Hamburg", country: "Germania", frequency: "103.6", streamURL: "https://frontend.streamonkey.net/radiohamburg-live/stream/mp3", genre: "Pop"),
        
        // Regno Unito
        RadioStation(id: 8, name: "BBC Radio 1", country: "UK", frequency: "97.7", streamURL: "https://stream.live.vc.bbcmedia.co.uk/bbc_radio_one", genre: "Pop"),
        RadioStation(id: 9, name: "Capital FM", country: "UK", frequency: "95.8", streamURL: "https://media-ssl.musicradio.com/CapitalMP3", genre: "Pop"),
        
        // Spagna
        RadioStation(id: 10, name: "Los 40", country: "Spagna", frequency: "93.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40.mp3", genre: "Pop"),
        RadioStation(id: 11, name: "Cadena SER", country: "Spagna", frequency: "105.4", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/CADENASER.mp3", genre: "News"),
        
        // USA
        RadioStation(id: 12, name: "KIIS FM", country: "USA", frequency: "102.7", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/KIISFMAAC.aac", genre: "Pop"),
        RadioStation(id: 13, name: "Z100", country: "USA", frequency: "100.3", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/Z100AAC.aac", genre: "Pop"),
        
        // Brasile
        RadioStation(id: 14, name: "Jovem Pan", country: "Brasile", frequency: "100.9", streamURL: "https://r13.ciclano.io:15045/stream", genre: "Pop"),
        
        // Giappone
        RadioStation(id: 15, name: "J-Wave", country: "Giappone", frequency: "81.3", streamURL: "https://radiko.jp/v2/api/ts/playlist.m3u8?station_id=FMJ", genre: "J-Pop"),
        
        // Australia
        RadioStation(id: 16, name: "Triple J", country: "Australia", frequency: "105.7", streamURL: "https://live-radio01.mediahubaustralia.com/2TJW/mp3/", genre: "Alternative"),
        
        // Canada
        RadioStation(id: 17, name: "Virgin Radio", country: "Canada", frequency: "99.9", streamURL: "https://live.leanstream.co/CFMGFM", genre: "Pop"),
        
        // Olanda
        RadioStation(id: 18, name: "Radio 538", country: "Olanda", frequency: "102.1", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO538.mp3", genre: "Dance"),
        
        // Belgio
        RadioStation(id: 19, name: "Studio Brussel", country: "Belgio", frequency: "100.7", streamURL: "https://icecast.vrtcdn.be/stubru-high.mp3", genre: "Alternative"),
        
        // Svizzera
        RadioStation(id: 20, name: "Energy Zurich", country: "Svizzera", frequency: "100.9", streamURL: "https://energyzuerich.ice.infomaniak.ch/energyzuerich-high.mp3", genre: "Dance"),
        
        // Russia
        RadioStation(id: 21, name: "Europa Plus", country: "Russia", frequency: "106.2", streamURL: "http://ep256.hostingradio.ru:8052/europaplus256.mp3", genre: "Pop"),
        RadioStation(id: 22, name: "Radio Energy", country: "Russia", frequency: "104.2", streamURL: "http://ic7.101.ru:8000/v1_1", genre: "Dance"),
        
        // India
        RadioStation(id: 23, name: "Radio City", country: "India", frequency: "91.1", streamURL: "http://prclive1.listenon.in:9960/", genre: "Bollywood"),
        RadioStation(id: 24, name: "Red FM", country: "India", frequency: "93.5", streamURL: "http://air.pc.cdn.bitgravity.com/air/live/pbaudio056/playlist.m3u8", genre: "Bollywood"),
        
        // Messico
        RadioStation(id: 25, name: "Los 40 Mexico", country: "Messico", frequency: "102.5", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40_MEXICOAAC.aac", genre: "Pop"),
        RadioStation(id: 26, name: "Exa FM", country: "Messico", frequency: "104.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/XHPSFMAAC.aac", genre: "Pop"),
        
        // Argentina
        RadioStation(id: 27, name: "Los 40 Argentina", country: "Argentina", frequency: "105.5", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40_ARGENTINA.mp3", genre: "Pop"),
        RadioStation(id: 28, name: "Rock & Pop", country: "Argentina", frequency: "95.9", streamURL: "http://5.9.56.134:8106/stream", genre: "Rock"),
        
        // Svezia
        RadioStation(id: 29, name: "NRJ Sweden", country: "Svezia", frequency: "103.8", streamURL: "http://tx-bauerse.sharp-stream.com/http_live.php?i=nrj_instreamtest_se_mp3", genre: "Pop"),
        RadioStation(id: 30, name: "Mix Megapol", country: "Svezia", frequency: "106.7", streamURL: "https://live-bauerse-fm.sharp-stream.com/mixmegapol_se_mp3", genre: "Pop"),
        
        // Norvegia
        RadioStation(id: 31, name: "NRK P1", country: "Norvegia", frequency: "96.8", streamURL: "https://lyd.nrk.no/nrk_radio_p1_ostlandssendingen_mp3_h", genre: "Pop"),
        RadioStation(id: 32, name: "Radio Norge", country: "Norvegia", frequency: "99.1", streamURL: "https://live-bauerse-fm.sharp-stream.com/radionorge_no_mp3", genre: "Pop"),
        
        // Danimarca
        RadioStation(id: 33, name: "DR P3", country: "Danimarca", frequency: "96.8", streamURL: "https://live-icy.gss.dr.dk/A/A05H.mp3", genre: "Pop"),
        RadioStation(id: 34, name: "The Voice", country: "Danimarca", frequency: "106.4", streamURL: "https://live-bauerse-fm.sharp-stream.com/thevoice_dk_mp3", genre: "Pop"),
        
        // Polonia
        RadioStation(id: 35, name: "RMF FM", country: "Polonia", frequency: "102.8", streamURL: "https://rs9-krk2.rmfstream.pl/RMFFM48", genre: "Pop"),
        RadioStation(id: 36, name: "Radio Zet", country: "Polonia", frequency: "90.9", streamURL: "https://n-22-12.dcs.redcdn.pl/sc/o2/Eurozet/live/audio.livx", genre: "Pop"),
        
        // Repubblica Ceca
        RadioStation(id: 37, name: "Evropa 2", country: "Rep. Ceca", frequency: "88.2", streamURL: "https://ice.actve.net/fm-evropa2-128", genre: "Pop"),
        RadioStation(id: 38, name: "Frekvence 1", country: "Rep. Ceca", frequency: "102.5", streamURL: "https://ice.actve.net/fm-frekvence1-128", genre: "Pop"),
        
        // Grecia
        RadioStation(id: 39, name: "Skai 100.3", country: "Grecia", frequency: "100.3", streamURL: "https://liveradio.skai.gr/skai1003/skai1003/playlist.m3u8", genre: "Pop"),
        RadioStation(id: 40, name: "Red 96.3", country: "Grecia", frequency: "96.3", streamURL: "http://s1.onweb.gr:8422/", genre: "Pop"),
        
        // Turchia
        RadioStation(id: 41, name: "Power FM", country: "Turchia", frequency: "103.2", streamURL: "https://listen.powerapp.com.tr/powerfm/mpeg/icecast.audio", genre: "Pop"),
        RadioStation(id: 42, name: "Radyo D", country: "Turchia", frequency: "100.8", streamURL: "https://radyod.radyotvonline.com/radyod", genre: "Pop"),
        
        // Israele
        RadioStation(id: 43, name: "Galgalatz", country: "Israele", frequency: "91.8", streamURL: "https://glzwizzlv.bynetcdn.com/glglz_mp3", genre: "Rock"),
        RadioStation(id: 44, name: "Radio Tel Aviv", country: "Israele", frequency: "102.0", streamURL: "https://radiotelaviv.streamgates.net/RadioTelAviv", genre: "Pop"),
        
        // Sud Africa
        RadioStation(id: 45, name: "5FM", country: "Sud Africa", frequency: "94.7", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/5FM.mp3", genre: "Pop"),
        RadioStation(id: 46, name: "Metro FM", country: "Sud Africa", frequency: "94.7", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/METRO_FM.mp3", genre: "Urban"),
        
        // Corea del Sud
        RadioStation(id: 47, name: "KBS Cool FM", country: "Corea del Sud", frequency: "89.1", streamURL: "https://cfm.kbs.co.kr/cfm_live.mp3", genre: "K-Pop"),
        RadioStation(id: 48, name: "SBS Power FM", country: "Corea del Sud", frequency: "107.7", streamURL: "https://streaming.sbs.co.kr/powerfm/powerfm.stream/playlist.m3u8", genre: "K-Pop"),
        
        // Thailandia
        RadioStation(id: 49, name: "Cool Fahrenheit", country: "Thailandia", frequency: "93.0", streamURL: "https://coolism-web.cdn.byteark.com/live/playlist.m3u8", genre: "Pop"),
        RadioStation(id: 50, name: "Green Wave", country: "Thailandia", frequency: "106.5", streamURL: "https://greenwave.cdn.byteark.com/live/playlist.m3u8", genre: "Pop")
    ]
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP])
            try audioSession.setActive(true)
            logger.logAudioInfo("Radio audio session configurata")
        } catch {
            logger.logAudioError(error, context: "Configurazione radio audio session")
        }
    }
    
    // MARK: - Radio Controls
    
    func playStation(_ station: RadioStation) {
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
        
        logger.logAudioInfo("Radio fermata")
    }
    
    func pauseRadio() {
        radioPlayer?.pause()
        isPlaying = false
        logger.logAudioInfo("Radio in pausa")
    }
    
    func resumeRadio() {
        radioPlayer?.play()
        isPlaying = true
        logger.logAudioInfo("Radio ripresa")
    }
    
    func setVolume(_ newVolume: Float) {
        volume = newVolume
        radioPlayer?.volume = newVolume
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