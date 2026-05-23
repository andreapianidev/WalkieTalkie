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

/// Qualità nominale dello stream — derivata dall'URL.
enum StreamQuality: String {
    case hls = "HLS"
    case aac = "AAC"
    case mp3 = "MP3"
    case unknown = "—"
}

struct RadioStation: Identifiable {
    let id: Int
    let name: String
    let country: String
    let frequency: String
    let streamURL: String
    let genre: String
    /// `true` se la stazione richiede Talky Pro. Stored (non computed) per consentire
    /// di aggiungere stazioni Free anche con id > 30 senza dover renumerare la lista
    /// (i preferiti utente sono memorizzati per id, renumerare li romperebbe).
    let isPro: Bool

    /// Init pubblico: se `isPro` è nil applica la regola storica `id > 30`,
    /// preservando il comportamento delle stazioni 1-135 esistenti.
    init(id: Int, name: String, country: String, frequency: String, streamURL: String, genre: String, isPro: Bool? = nil) {
        self.id = id
        self.name = name
        self.country = country
        self.frequency = frequency
        self.streamURL = streamURL
        self.genre = genre
        self.isPro = isPro ?? (id > 30)
    }

    /// Qualità inferita dall'URL (HLS > AAC > MP3 in affidabilità su iOS).
    var quality: StreamQuality {
        let lower = streamURL.lowercased()
        if lower.contains(".m3u8") || lower.contains("/playlist") { return .hls }
        if lower.contains(".aac") || lower.contains("aac") { return .aac }
        if lower.contains(".mp3") || lower.contains("mp3") { return .mp3 }
        return .unknown
    }

    /// Etichetta da mostrare quando la frequenza è "—" (stazioni internet senza FM reale).
    /// Mostra il genere in uppercase per riempire il display vintage.
    var displayLabel: String {
        if frequency == "—" || frequency.isEmpty {
            return genre.uppercased()
        }
        return frequency
    }

    /// Emoji bandiera del paese, derivata dal nome paese italiano.
    var flagEmoji: String { RadioStation.flagMap[country] ?? "🌍" }

    private static let flagMap: [String: String] = [
        "Italia": "🇮🇹", "Francia": "🇫🇷", "Germania": "🇩🇪", "UK": "🇬🇧",
        "Spagna": "🇪🇸", "USA": "🇺🇸", "Olanda": "🇳🇱", "Belgio": "🇧🇪",
        "Svizzera": "🇨🇭", "Austria": "🇦🇹", "Norvegia": "🇳🇴", "Danimarca": "🇩🇰",
        "Svezia": "🇸🇪", "Finlandia": "🇫🇮", "Islanda": "🇮🇸", "Polonia": "🇵🇱",
        "Rep. Ceca": "🇨🇿", "Slovacchia": "🇸🇰", "Slovenia": "🇸🇮", "Croazia": "🇭🇷",
        "Serbia": "🇷🇸", "Bulgaria": "🇧🇬", "Estonia": "🇪🇪", "Lettonia": "🇱🇻",
        "Lituania": "🇱🇹", "Ungheria": "🇭🇺", "Romania": "🇷🇴", "Ucraina": "🇺🇦",
        "Russia": "🇷🇺", "Grecia": "🇬🇷", "Turchia": "🇹🇷", "Israele": "🇮🇱",
        "Portogallo": "🇵🇹", "Sud Africa": "🇿🇦", "Marocco": "🇲🇦", "Egitto": "🇪🇬",
        "Kenya": "🇰🇪", "Nigeria": "🇳🇬", "India": "🇮🇳", "Pakistan": "🇵🇰",
        "Giappone": "🇯🇵", "Thailandia": "🇹🇭", "Indonesia": "🇮🇩", "Malesia": "🇲🇾",
        "Filippine": "🇵🇭", "Singapore": "🇸🇬", "Vietnam": "🇻🇳", "Nuova Zelanda": "🇳🇿",
        "Australia": "🇦🇺", "Messico": "🇲🇽", "Argentina": "🇦🇷", "Brasile": "🇧🇷",
        "Cile": "🇨🇱", "Colombia": "🇨🇴", "Perù": "🇵🇪", "Uruguay": "🇺🇾",
        "Cuba": "🇨🇺", "Hong Kong": "🇭🇰",
        "Irlanda": "🇮🇪", "Capo Verde": "🇨🇻", "Groenlandia": "🇬🇱", "Bermuda": "🇧🇲",
        "Giamaica": "🇯🇲", "Bahamas": "🇧🇸", "Trinidad": "🇹🇹", "Senegal": "🇸🇳",
        "Canada": "🇨🇦", "Cina": "🇨🇳", "Taiwan": "🇹🇼", "Arabia Saudita": "🇸🇦",
        "Venezuela": "🇻🇪",
        "Internet": "🌐"
    ]
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

    // MARK: - Favorites & Recents (persisted in UserDefaults)
    @Published private(set) var favoriteStationIds: Set<Int> = []
    @Published private(set) var recentStationIds: [Int] = []

    private let favoritesKey = "talky_favorite_station_ids"
    private let recentsKey = "talky_recent_station_ids"
    private let lastStationKey = "talky_last_station_id"
    private let maxRecents = 10
    
    // Lista di stazioni radio internazionali — URL verificati live (maggio 2026).
    // Il flag Pro è esplicito per ogni stazione; la regola storica `id > 30` vale
    // come default per le prime 135 stazioni, le nuove specificano `isPro` esplicito.
    let radioStations: [RadioStation] = [
        // MARK: - Free (Italia + grandi broadcaster europei)
        // Italia
        RadioStation(id: 1, name: "RTL 102.5", country: "Italia", frequency: "102.5", streamURL: "https://streamingv2.shoutcast.com/rtl-1025", genre: "Pop"),
        RadioStation(id: 2, name: "Radio Deejay", country: "Italia", frequency: "106.2", streamURL: "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/radiodeejay/radiodeejay/master_ma.m3u8", genre: "Pop"),
        RadioStation(id: 3, name: "Rai Radio 1", country: "Italia", frequency: "89.7", streamURL: "http://icestreaming.rai.it/1.mp3", genre: "News"),
        RadioStation(id: 4, name: "Rai Radio 2", country: "Italia", frequency: "91.7", streamURL: "http://icestreaming.rai.it/2.mp3", genre: "Pop"),
        RadioStation(id: 5, name: "Rai Radio 3", country: "Italia", frequency: "93.7", streamURL: "http://icestreaming.rai.it/3.mp3", genre: "Classical"),
        RadioStation(id: 6, name: "Radio Italia", country: "Italia", frequency: "98.7", streamURL: "https://radioitaliasmi.akamaized.net/hls/live/2093120/RISMI/stream01/streamPlaylist.m3u8", genre: "Italian"),
        RadioStation(id: 7, name: "Radio 24", country: "Italia", frequency: "104.4", streamURL: "http://shoutcast2.radio24.it:8000/", genre: "News"),
        RadioStation(id: 8, name: "Radio 105", country: "Italia", frequency: "105.0", streamURL: "http://icecast.unitedradio.it/Radio105.mp3", genre: "Pop"),
        RadioStation(id: 9, name: "Virgin Radio Italia", country: "Italia", frequency: "104.5", streamURL: "http://icecast.unitedradio.it/Virgin.mp3", genre: "Rock"),
        RadioStation(id: 10, name: "Radio Capital", country: "Italia", frequency: "103.0", streamURL: "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/radiocapital/radiocapital/master_ma.m3u8", genre: "Rock"),
        RadioStation(id: 11, name: "Radio Kiss Kiss", country: "Italia", frequency: "97.0", streamURL: "http://wma08.fluidstream.net:4610/", genre: "Pop"),
        RadioStation(id: 12, name: "RMC Radio Monte Carlo", country: "Italia", frequency: "100.7", streamURL: "http://icecast.unitedradio.it/RMC.mp3", genre: "Easy"),
        RadioStation(id: 13, name: "RDS", country: "Italia", frequency: "100.3", streamURL: "https://stream.rds.radio/audio/rds.stream_aac64/chunklist.m3u8", genre: "Pop"),
        RadioStation(id: 14, name: "Radio M2O", country: "Italia", frequency: "92.8", streamURL: "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/radiom2o/radiom2o/master_ma.m3u8", genre: "Dance"),
        RadioStation(id: 15, name: "Radio Freccia", country: "Italia", frequency: "94.5", streamURL: "https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/live/S3160845/0tuSetc8UFkF/playlist_audio.m3u8", genre: "Rock"),
        // Francia
        RadioStation(id: 16, name: "NRJ", country: "Francia", frequency: "100.3", streamURL: "https://streaming.nrjaudio.fm/oumvmk8fnozc", genre: "Pop"),
        RadioStation(id: 17, name: "France Inter", country: "Francia", frequency: "87.8", streamURL: "http://icecast.radiofrance.fr/franceinter-hifi.aac", genre: "Talk"),
        RadioStation(id: 18, name: "France Info", country: "Francia", frequency: "105.5", streamURL: "http://direct.franceinfo.fr/live/franceinfo-midfi.mp3", genre: "News"),
        RadioStation(id: 19, name: "FIP", country: "Francia", frequency: "105.1", streamURL: "http://icecast.radiofrance.fr/fip-hifi.aac", genre: "Eclectic"),
        // Germania
        RadioStation(id: 20, name: "Antenne Bayern", country: "Germania", frequency: "103.2", streamURL: "https://s1-webradio.antenne.de/antenne", genre: "Pop"),
        RadioStation(id: 21, name: "1LIVE", country: "Germania", frequency: "106.7", streamURL: "http://wdr-1live-live.icecast.wdr.de/wdr/1live/live/mp3/128/stream.mp3", genre: "Pop"),
        RadioStation(id: 22, name: "SWR3", country: "Germania", frequency: "99.9", streamURL: "https://liveradio.swr.de/sw282p3/swr3/play.mp3", genre: "Pop"),
        // UK
        RadioStation(id: 23, name: "BBC Radio 2", country: "UK", frequency: "88.0", streamURL: "http://as-hls-ww-live.akamaized.net/pool_74208725/live/ww/bbc_radio_two/bbc_radio_two.isml/bbc_radio_two-audio%3d128000.norewind.m3u8", genre: "Pop"),
        RadioStation(id: 24, name: "BBC Radio 4", country: "UK", frequency: "92.4", streamURL: "http://as-hls-ww-live.akamaized.net/pool_55057080/live/ww/bbc_radio_fourfm/bbc_radio_fourfm.isml/bbc_radio_fourfm-audio%3d128000.norewind.m3u8", genre: "Talk"),
        RadioStation(id: 25, name: "BBC World Service", country: "UK", frequency: "648", streamURL: "http://stream.live.vc.bbcmedia.co.uk/bbc_world_service", genre: "News"),
        RadioStation(id: 26, name: "Capital FM", country: "UK", frequency: "95.8", streamURL: "https://media-ssl.musicradio.com/CapitalMP3", genre: "Pop"),
        // Spagna
        RadioStation(id: 27, name: "Los 40", country: "Spagna", frequency: "93.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40.mp3", genre: "Pop"),
        RadioStation(id: 28, name: "Cadena SER", country: "Spagna", frequency: "105.4", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/CADENASER.mp3", genre: "News"),
        // Olanda + Belgio
        RadioStation(id: 29, name: "Radio 538", country: "Olanda", frequency: "102.1", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO538.mp3", genre: "Dance"),
        RadioStation(id: 30, name: "Studio Brussel", country: "Belgio", frequency: "100.7", streamURL: "https://icecast.vrtcdn.be/stubru-high.mp3", genre: "Alternative"),

        // MARK: - Pro internazionali (id 31+)
        // Francia
        RadioStation(id: 31, name: "Europe 1", country: "Francia", frequency: "104.7", streamURL: "https://europe1.lmn.fm/europe1.mp3", genre: "News"),
        // UK
        RadioStation(id: 32, name: "BBC Radio 6 Music", country: "UK", frequency: "—", streamURL: "http://as-hls-ww-live.akamaized.net/pool_81827798/live/ww/bbc_6music/bbc_6music.isml/bbc_6music-audio%3d320000.norewind.m3u8", genre: "Alternative"),
        RadioStation(id: 33, name: "Classic FM", country: "UK", frequency: "100.0", streamURL: "http://ice-the.musicradio.com/ClassicFMMP3", genre: "Classical"),
        RadioStation(id: 34, name: "LBC", country: "UK", frequency: "97.3", streamURL: "http://media-ice.musicradio.com/LBCUK", genre: "Talk"),
        // Spagna
        RadioStation(id: 35, name: "Cadena 100", country: "Spagna", frequency: "100.0", streamURL: "http://cadena100-streamers-mp3.flumotion.com/cope/cadena100.mp3", genre: "Pop"),
        // USA
        RadioStation(id: 36, name: "Radio Paradise", country: "USA", frequency: "—", streamURL: "http://stream-uk1.radioparadise.com/aac-320", genre: "Eclectic"),
        RadioStation(id: 37, name: "101 Smooth Jazz", country: "USA", frequency: "101.0", streamURL: "http://jking.cdnstream1.com/b22139_128mp3", genre: "Jazz"),
        RadioStation(id: 38, name: "Classic Vinyl HD", country: "USA", frequency: "—", streamURL: "https://icecast.walmradio.com:8443/classic", genre: "Oldies"),
        RadioStation(id: 39, name: "Adroit Jazz Underground", country: "USA", frequency: "—", streamURL: "https://icecast.walmradio.com:8443/jazz", genre: "Jazz"),
        // Australia
        RadioStation(id: 40, name: "Triple J", country: "Australia", frequency: "105.7", streamURL: "https://live-radio01.mediahubaustralia.com/2TJW/mp3/", genre: "Alternative"),
        RadioStation(id: 41, name: "ABC News Radio", country: "Australia", frequency: "630", streamURL: "http://abc.streamguys1.com/live/newsradio/icecast.audio", genre: "News"),
        RadioStation(id: 42, name: "2GB Sydney", country: "Australia", frequency: "873", streamURL: "http://playerservices.streamtheworld.com/api/livestream-redirect/2GB.mp3", genre: "Talk"),
        // Olanda
        RadioStation(id: 43, name: "NPO Radio 2", country: "Olanda", frequency: "92.6", streamURL: "http://icecast.omroep.nl/radio2-bb-mp3", genre: "Pop"),
        RadioStation(id: 44, name: "Qmusic", country: "Olanda", frequency: "100.7", streamURL: "https://icecast-qmusicnl-cdp.triple-it.nl/Qmusic_nl_live_96.mp3", genre: "Pop"),
        // Belgio
        RadioStation(id: 45, name: "VRT Radio 1", country: "Belgio", frequency: "91.7", streamURL: "http://icecast.vrtcdn.be/radio1-high.mp3", genre: "Talk"),
        RadioStation(id: 46, name: "Joe", country: "Belgio", frequency: "95.0", streamURL: "https://icecast-qmusicbe-cdp.triple-it.nl/joe.mp3", genre: "Oldies"),
        // Svizzera
        RadioStation(id: 47, name: "Energy Zurich", country: "Svizzera", frequency: "100.9", streamURL: "https://energyzuerich.ice.infomaniak.ch/energyzuerich-high.mp3", genre: "Dance"),
        RadioStation(id: 48, name: "SRF 3", country: "Svizzera", frequency: "99.1", streamURL: "http://stream.srg-ssr.ch/m/drs3/mp3_128", genre: "Pop"),
        RadioStation(id: 49, name: "Radio Swiss Jazz", country: "Svizzera", frequency: "—", streamURL: "http://stream.srg-ssr.ch/m/rsj/mp3_128", genre: "Jazz"),
        // Austria
        RadioStation(id: 50, name: "Ö3 Hitradio", country: "Austria", frequency: "99.9", streamURL: "https://orf-live.ors-shoutcast.at/oe3-q2a", genre: "Pop"),
        RadioStation(id: 51, name: "FM4", country: "Austria", frequency: "103.8", streamURL: "https://orf-live.ors-shoutcast.at/fm4-q2a", genre: "Alternative"),
        // Norvegia
        RadioStation(id: 52, name: "NRK P3", country: "Norvegia", frequency: "92.0", streamURL: "https://cdn0-47115-liveicecast0.dna.contentdelivery.net/p3_mp3_h", genre: "Pop"),
        RadioStation(id: 53, name: "P4 Norge", country: "Norvegia", frequency: "100.7", streamURL: "https://p4.p4groupaudio.com/P04_AH", genre: "Pop"),
        // Danimarca
        RadioStation(id: 54, name: "DR P3", country: "Danimarca", frequency: "96.5", streamURL: "http://live-icy.gslb01.dr.dk/A/A05H.mp3", genre: "Pop"),
        RadioStation(id: 55, name: "Nova FM", country: "Danimarca", frequency: "94.6", streamURL: "https://live-bauerdk.sharp-stream.com/nova_dk_mp3", genre: "Pop"),
        // Svezia
        RadioStation(id: 56, name: "Sveriges Radio P3", country: "Svezia", frequency: "99.3", streamURL: "https://live1.sr.se/p3-mp3-96", genre: "Pop"),
        RadioStation(id: 57, name: "RIX FM", country: "Svezia", frequency: "106.7", streamURL: "https://fm01-ice.stream.khz.se/fm01_mp3", genre: "Pop"),
        RadioStation(id: 58, name: "Bandit Rock", country: "Svezia", frequency: "106.3", streamURL: "http://fm02-ice.stream.khz.se/fm02_mp3", genre: "Rock"),
        // Finlandia
        RadioStation(id: 59, name: "Yle Radio Suomi", country: "Finlandia", frequency: "94.0", streamURL: "http://icecast.live.yle.fi/radio/YleRS/icecast.audio", genre: "Talk"),
        RadioStation(id: 60, name: "Radio Nova", country: "Finlandia", frequency: "106.2", streamURL: "https://stream-redirect.bauermedia.fi/radionova/radionova_64.aac", genre: "Pop"),
        // Islanda
        RadioStation(id: 61, name: "Bylgjan", country: "Islanda", frequency: "98.9", streamURL: "http://icecast.365net.is:8000/orbbylgjan.aac", genre: "Pop"),
        RadioStation(id: 62, name: "Rás 2", country: "Islanda", frequency: "90.1", streamURL: "http://netradio.ruv.is/ras2.aac", genre: "Pop"),
        // Polonia
        RadioStation(id: 63, name: "RMF FM", country: "Polonia", frequency: "102.8", streamURL: "http://195.150.20.242:8000/rmf_fm", genre: "Pop"),
        RadioStation(id: 64, name: "Radio Zet", country: "Polonia", frequency: "90.9", streamURL: "http://zet-net-01.cdn.eurozet.pl:8400/", genre: "Pop"),
        RadioStation(id: 65, name: "Radio 357", country: "Polonia", frequency: "—", streamURL: "https://n-11-21.dcs.redcdn.pl/sc/o2/radio357/live/radio357_pr.livx?preroll=0", genre: "Talk"),
        // Repubblica Ceca
        RadioStation(id: 66, name: "Evropa 2", country: "Rep. Ceca", frequency: "88.2", streamURL: "https://ice.actve.net/fm-evropa2-128", genre: "Pop"),
        RadioStation(id: 67, name: "Frekvence 1", country: "Rep. Ceca", frequency: "102.5", streamURL: "https://ice.actve.net/fm-frekvence1-128", genre: "Pop"),
        // Slovacchia
        RadioStation(id: 68, name: "Fun Radio", country: "Slovacchia", frequency: "94.3", streamURL: "http://stream.funradio.sk:8000/fun128.mp3", genre: "Pop"),
        RadioStation(id: 69, name: "Rádio Expres", country: "Slovacchia", frequency: "92.5", streamURL: "https://stream.bauermedia.sk/128.mp3", genre: "Pop"),
        // Slovenia
        RadioStation(id: 70, name: "Radio 1", country: "Slovenia", frequency: "94.9", streamURL: "http://live.radio.si/Radio1", genre: "Pop"),
        RadioStation(id: 71, name: "Val 202", country: "Slovenia", frequency: "98.9", streamURL: "http://mp3.rtvslo.si/val202", genre: "Pop"),
        // Croazia
        RadioStation(id: 72, name: "Otvoreni Radio", country: "Croazia", frequency: "97.1", streamURL: "http://stream.otvoreni.hr/otvoreni", genre: "Pop"),
        RadioStation(id: 73, name: "Extra FM", country: "Croazia", frequency: "93.6", streamURL: "http://streams.extrafm.hr:8110/", genre: "Pop"),
        // Serbia
        RadioStation(id: 74, name: "Naxi ExYu", country: "Serbia", frequency: "—", streamURL: "https://naxidigital-exyu128ssl.streaming.rs:8242/", genre: "Pop"),
        // Bulgaria
        RadioStation(id: 75, name: "BG Radio", country: "Bulgaria", frequency: "91.9", streamURL: "http://stream.radioreklama.bg/bgradio128", genre: "Pop"),
        RadioStation(id: 76, name: "NRJ Bulgaria", country: "Bulgaria", frequency: "104.5", streamURL: "http://play.global.audio/nrj128", genre: "Pop"),
        // Estonia
        RadioStation(id: 77, name: "Vikerraadio", country: "Estonia", frequency: "104.1", streamURL: "http://icecast.err.ee/vikerraadio.mp3", genre: "Talk"),
        RadioStation(id: 78, name: "Retro FM Estonia", country: "Estonia", frequency: "92.8", streamURL: "https://edge02.cdn.bitflip.ee:8888/RETRO?_i=258f436b", genre: "Oldies"),
        // Lettonia
        RadioStation(id: 79, name: "Radio SWH", country: "Lettonia", frequency: "105.2", streamURL: "http://80.232.162.149:8000/swh96mp3", genre: "Pop"),
        // Lituania
        RadioStation(id: 80, name: "M-1 Plius", country: "Lituania", frequency: "106.8", streamURL: "http://radio.m-1.fm/m1plius/mp3", genre: "Pop"),
        // Ungheria
        RadioStation(id: 81, name: "Retro Rádió", country: "Ungheria", frequency: "104.2", streamURL: "https://icast.connectmedia.hu/5001/live.mp3", genre: "Oldies"),
        RadioStation(id: 82, name: "Klubrádió", country: "Ungheria", frequency: "92.9", streamURL: "https://a7.asurahosting.com:8160/radio.mp3", genre: "Talk"),
        // Romania
        RadioStation(id: 83, name: "Kiss FM", country: "Romania", frequency: "96.1", streamURL: "https://live.kissfm.ro/kissfm.aacp", genre: "Pop"),
        RadioStation(id: 84, name: "Radio România", country: "Romania", frequency: "98.6", streamURL: "http://89.238.227.6:8006/", genre: "News"),
        // Ucraina
        RadioStation(id: 85, name: "Hit FM", country: "Ucraina", frequency: "96.4", streamURL: "http://195.95.206.17/HitFM", genre: "Pop"),
        RadioStation(id: 86, name: "Kiss FM Ukraine", country: "Ucraina", frequency: "106.5", streamURL: "http://online.kissfm.ua/KissFM", genre: "Dance"),
        // Russia
        RadioStation(id: 87, name: "Europa Plus", country: "Russia", frequency: "106.2", streamURL: "http://ep256.hostingradio.ru:8052/europaplus256.mp3", genre: "Pop"),
        RadioStation(id: 88, name: "Vesti FM", country: "Russia", frequency: "97.6", streamURL: "http://icecast.vgtrk.cdnvideo.ru/vestifm_mp3_192kbps", genre: "News"),
        RadioStation(id: 89, name: "Retro FM", country: "Russia", frequency: "88.3", streamURL: "http://retroserver.streamr.ru:8043/retro256.mp3", genre: "Oldies"),
        // Grecia
        RadioStation(id: 90, name: "Sfera", country: "Grecia", frequency: "102.2", streamURL: "http://sfera.live24.gr/sfera4132", genre: "Pop"),
        RadioStation(id: 91, name: "Sport FM", country: "Grecia", frequency: "94.6", streamURL: "http://netradio.live24.gr/sportfm7712", genre: "Sport"),
        // Turchia
        RadioStation(id: 92, name: "Power FM", country: "Turchia", frequency: "103.2", streamURL: "https://listen.powerapp.com.tr/powerfm/mpeg/icecast.audio", genre: "Pop"),
        // Israele
        RadioStation(id: 93, name: "Galgalatz", country: "Israele", frequency: "91.8", streamURL: "https://glzwizzlv.bynetcdn.com/glglz_mp3", genre: "Rock"),
        RadioStation(id: 94, name: "Kan Bet", country: "Israele", frequency: "95.5", streamURL: "https://25583.live.streamtheworld.com/KAN_BET.mp3", genre: "Talk"),
        // Portogallo
        RadioStation(id: 95, name: "Antena 1", country: "Portogallo", frequency: "95.7", streamURL: "http://streaming-live-app.rtp.pt/liveradio/antena180a/playlist.m3u8", genre: "Pop"),
        RadioStation(id: 96, name: "RFM", country: "Portogallo", frequency: "93.2", streamURL: "https://23603.live.streamtheworld.com/RFMAAC.aac", genre: "Pop"),
        // Sud Africa
        RadioStation(id: 97, name: "5FM", country: "Sud Africa", frequency: "98.4", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/5FM.mp3", genre: "Pop"),
        RadioStation(id: 98, name: "Metro FM", country: "Sud Africa", frequency: "94.7", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/METRO_FM.mp3", genre: "Urban"),
        RadioStation(id: 99, name: "Jacaranda FM", country: "Sud Africa", frequency: "94.2", streamURL: "https://edge.iono.fm/xice/jacarandafm_live_medium.aac", genre: "Pop"),
        // Marocco
        RadioStation(id: 100, name: "Radio Aswat", country: "Marocco", frequency: "97.9", streamURL: "http://broadcast.ice.infomaniak.ch/aswat-high.mp3", genre: "Pop"),
        RadioStation(id: 101, name: "Radio Mars", country: "Marocco", frequency: "98.4", streamURL: "https://radiomars.ice.infomaniak.ch/radiomars-128.mp3", genre: "Sport"),
        // Egitto
        RadioStation(id: 102, name: "Nogoum FM", country: "Egitto", frequency: "100.6", streamURL: "https://9090streaming.mobtada.com/9090FMEGYPT", genre: "Pop"),
        // Kenya
        RadioStation(id: 103, name: "Kameme FM", country: "Kenya", frequency: "101.1", streamURL: "https://kamemefm-atunwadigital.streamguys1.com/kamemefm", genre: "World"),
        // Nigeria
        RadioStation(id: 104, name: "Splash FM", country: "Nigeria", frequency: "105.5", streamURL: "https://edge.mixlr.com/channel/cfeki", genre: "World"),
        // India
        RadioStation(id: 105, name: "Red FM", country: "India", frequency: "93.5", streamURL: "http://air.pc.cdn.bitgravity.com/air/live/pbaudio056/playlist.m3u8", genre: "Bollywood"),
        RadioStation(id: 106, name: "Vividh Bharati", country: "India", frequency: "1188", streamURL: "https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8", genre: "Bollywood"),
        // Pakistan
        RadioStation(id: 107, name: "FM 101 Islamabad", country: "Pakistan", frequency: "101.0", streamURL: "https://whmsonic.radio.gov.pk:7008/stream", genre: "World"),
        // Giappone
        RadioStation(id: 108, name: "Japan Hits", country: "Giappone", frequency: "—", streamURL: "http://quincy.torontocast.com:2020/stream.mp3", genre: "J-Pop"),
        RadioStation(id: 109, name: "Jazz Sakura", country: "Giappone", frequency: "—", streamURL: "http://kathy.torontocast.com:3330/stream/1/", genre: "Jazz"),
        // Thailandia
        RadioStation(id: 110, name: "Cool Fahrenheit", country: "Thailandia", frequency: "93.0", streamURL: "https://coolism-web.cdn.byteark.com/live/playlist.m3u8", genre: "Pop"),
        // Indonesia
        RadioStation(id: 111, name: "Prambors FM", country: "Indonesia", frequency: "102.2", streamURL: "http://103.24.105.90:9300/pjkt", genre: "Pop"),
        // Malesia
        RadioStation(id: 112, name: "988 FM", country: "Malesia", frequency: "98.8", streamURL: "https://28103.live.streamtheworld.com/988_FMAAC.aac", genre: "Pop"),
        // Filippine
        RadioStation(id: 113, name: "Easy Rock Manila", country: "Filippine", frequency: "96.3", streamURL: "https://azura.easyrock.com.ph/listen/easy_rock_manila/radio.mp3", genre: "Rock"),
        // Singapore
        RadioStation(id: 114, name: "YES 933", country: "Singapore", frequency: "93.3", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/YES933_PREM.aac", genre: "Pop"),
        RadioStation(id: 115, name: "Love 972", country: "Singapore", frequency: "97.2", streamURL: "http://playerservices.streamtheworld.com/api/livestream-redirect/LOVE972FMAAC.aac", genre: "Pop"),
        // Vietnam
        RadioStation(id: 116, name: "VOV1", country: "Vietnam", frequency: "100.0", streamURL: "https://str.vov.gov.vn/vovlive/vov1vov5Vietnamese.sdp_aac/playlist.m3u8", genre: "News"),
        // Nuova Zelanda
        RadioStation(id: 117, name: "The Rock", country: "Nuova Zelanda", frequency: "90.2", streamURL: "https://digitalstreams.mediaworks.nz/rock_net_icy", genre: "Rock"),
        RadioStation(id: 118, name: "Magic FM NZ", country: "Nuova Zelanda", frequency: "97.4", streamURL: "https://mediaworks.streamguys1.com/magic_net_icy", genre: "Easy"),
        // Messico
        RadioStation(id: 119, name: "Los 40 México", country: "Messico", frequency: "102.5", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40_MEXICOAAC.aac", genre: "Pop"),
        RadioStation(id: 120, name: "Exa FM", country: "Messico", frequency: "104.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/XHPSFMAAC.aac", genre: "Pop"),
        // Argentina
        RadioStation(id: 121, name: "Aspen 102.3", country: "Argentina", frequency: "102.3", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/ASPEN.mp3", genre: "Pop"),
        RadioStation(id: 122, name: "La 100", country: "Argentina", frequency: "99.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/FM999_56.mp3", genre: "Pop"),
        // Brasile
        RadioStation(id: 123, name: "Alpha FM", country: "Brasile", frequency: "101.7", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_ALPHAFM_ADP.aac", genre: "Easy"),
        RadioStation(id: 124, name: "Rádio Mix FM", country: "Brasile", frequency: "106.3", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/MIXFM_SAOPAULOAAC.aac", genre: "Pop"),
        // Cile
        RadioStation(id: 125, name: "Pudahuel", country: "Cile", frequency: "90.5", streamURL: "http://26593.live.streamtheworld.com:3690/PUDAHUEL_SC", genre: "Pop"),
        // Colombia
        RadioStation(id: 126, name: "Caracol Radio", country: "Colombia", frequency: "100.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/CARACOL_RADIOAAC.aac", genre: "News"),
        // Perù
        RadioStation(id: 127, name: "RPP Noticias", country: "Perù", frequency: "89.7", streamURL: "https://mdstrm.com/audio/5fab3416b5f9ef165cfab6e9/icecast.audio", genre: "News"),
        RadioStation(id: 128, name: "Radio Panamericana", country: "Perù", frequency: "100.5", streamURL: "https://mdstrm.com/audio/6598b62dded1380470f4e539/icecast.audio", genre: "Pop"),
        // Uruguay
        RadioStation(id: 129, name: "Azul FM", country: "Uruguay", frequency: "101.9", streamURL: "https://azul-2.nty.uy/", genre: "Pop"),
        RadioStation(id: 130, name: "Del Sol FM", country: "Uruguay", frequency: "99.5", streamURL: "http://radio.dl.uy:9950/radio", genre: "Talk"),
        // Cuba
        RadioStation(id: 131, name: "Cubania Radio", country: "Cuba", frequency: "—", streamURL: "https://streamingv2.shoutcast.com/cubania?type=.mp3", genre: "Latin"),
        // Internet/Genre-based
        RadioStation(id: 132, name: "Frisky", country: "Internet", frequency: "—", streamURL: "http://stream2.friskyradio.com/frisky_mp3_hi", genre: "Electronic"),
        RadioStation(id: 133, name: "Dance Wave!", country: "Internet", frequency: "—", streamURL: "https://dancewave.online/dance.mp3", genre: "Dance"),
        RadioStation(id: 134, name: "Rock Antenne Heavy Metal", country: "Internet", frequency: "—", streamURL: "http://mp3channels.webradio.rockantenne.de/heavy-metal", genre: "Metal"),
        RadioStation(id: 135, name: "Deep House Lounge", country: "Internet", frequency: "—", streamURL: "http://198.15.94.34:8006/stream", genre: "Electronic"),

        // MARK: - Free aggiuntive (verificate maggio 2026) — isPro: false esplicito
        RadioStation(id: 136, name: "RTL 102.5 Best", country: "Italia", frequency: "—", streamURL: "https://streamingv2.shoutcast.com/rtl-1025-best", genre: "Pop", isPro: false),
        RadioStation(id: 137, name: "Skyrock", country: "Francia", frequency: "96.0", streamURL: "http://icecast.skyrock.net/s/natio_mp3_128k", genre: "Hip-Hop", isPro: false),
        RadioStation(id: 138, name: "RFI Monde", country: "Francia", frequency: "89.0", streamURL: "http://live02.rfi.fr/rfimonde-64.mp3", genre: "News", isPro: false),
        RadioStation(id: 139, name: "NDR 2", country: "Germania", frequency: "87.6", streamURL: "https://icecast.ndr.de/ndr/ndr2/niedersachsen/mp3/128/stream.mp3", genre: "Pop", isPro: false),
        RadioStation(id: 140, name: "Heart London", country: "UK", frequency: "106.2", streamURL: "https://media-ssl.musicradio.com/HeartLondon", genre: "Pop", isPro: false),
        RadioStation(id: 141, name: "Smooth Radio", country: "UK", frequency: "100.0", streamURL: "https://media-ssl.musicradio.com/SmoothUK", genre: "Easy", isPro: false),
        RadioStation(id: 142, name: "talkSPORT", country: "UK", frequency: "1089", streamURL: "https://radio.talksport.com/stream", genre: "Sport", isPro: false),
        RadioStation(id: 143, name: "NPO Radio 1", country: "Olanda", frequency: "97.5", streamURL: "https://icecast.omroep.nl/radio1-bb-mp3", genre: "News", isPro: false),

        // MARK: - Pro aggiuntive (verificate maggio 2026) — espansione USA / UK / Asia / NL / Oceania
        // Olanda + Polonia
        RadioStation(id: 144, name: "NPO 3FM", country: "Olanda", frequency: "96.5", streamURL: "https://icecast.omroep.nl/3fm-bb-mp3", genre: "Pop"),
        RadioStation(id: 145, name: "Sky Radio NL", country: "Olanda", frequency: "101.2", streamURL: "https://22343.live.streamtheworld.com/SKYRADIO.mp3", genre: "Pop"),
        RadioStation(id: 146, name: "Antyradio", country: "Polonia", frequency: "94.0", streamURL: "https://an.cdn.eurozet.pl/ant-waw.mp3", genre: "Rock"),
        // UK extra
        RadioStation(id: 147, name: "talkRADIO", country: "UK", frequency: "—", streamURL: "https://radio.talkradio.co.uk/stream", genre: "Talk"),
        RadioStation(id: 148, name: "Times Radio", country: "UK", frequency: "—", streamURL: "https://timesradio.wireless.radio/stream", genre: "News"),
        RadioStation(id: 149, name: "Heart 80s", country: "UK", frequency: "—", streamURL: "https://media-ssl.musicradio.com/Heart80s", genre: "Oldies"),
        // USA extra
        RadioStation(id: 150, name: "KEXP 90.3", country: "USA", frequency: "90.3", streamURL: "https://kexp.streamguys1.com/kexp160.aac", genre: "Alternative"),
        RadioStation(id: 151, name: "WNYC FM", country: "USA", frequency: "93.9", streamURL: "https://fm939.wnyc.org/wnycfm", genre: "News"),
        RadioStation(id: 152, name: "WBEZ Chicago", country: "USA", frequency: "91.5", streamURL: "https://stream.wbez.org/wbez128.mp3", genre: "News"),
        RadioStation(id: 153, name: "KQED FM", country: "USA", frequency: "88.5", streamURL: "https://streams.kqed.org/kqedradio", genre: "News"),
        RadioStation(id: 154, name: "WFMU", country: "USA", frequency: "91.1", streamURL: "https://stream0.wfmu.org/freeform-128k", genre: "Eclectic"),
        RadioStation(id: 155, name: "NPR News", country: "USA", frequency: "—", streamURL: "https://npr-ice.streamguys1.com/live.mp3", genre: "News"),
        RadioStation(id: 156, name: "WBLS", country: "USA", frequency: "107.5", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/WBLSFMAAC.aac", genre: "Urban"),
        RadioStation(id: 157, name: "Hot 97", country: "USA", frequency: "97.1", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/WQHTFMAAC.aac", genre: "Hip-Hop"),
        RadioStation(id: 158, name: "Bloomberg Radio", country: "USA", frequency: "1130", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/WBBRAMAAC.aac", genre: "News"),
        // Messico
        RadioStation(id: 159, name: "W Radio", country: "Messico", frequency: "96.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/WRADIO_MEXICOAAC.aac", genre: "News"),
        // Australia extra
        RadioStation(id: 160, name: "ABC Classic FM", country: "Australia", frequency: "92.9", streamURL: "https://live-radio01.mediahubaustralia.com/2FMW/mp3/", genre: "Classical"),
        // Hong Kong
        RadioStation(id: 161, name: "RTHK Radio 1", country: "Hong Kong", frequency: "92.6", streamURL: "http://stm.rthk.hk/radio1", genre: "Talk"),
        RadioStation(id: 162, name: "RTHK Radio 2", country: "Hong Kong", frequency: "94.8", streamURL: "http://stm.rthk.hk/radio2", genre: "Pop"),
        RadioStation(id: 163, name: "RTHK Radio 3", country: "Hong Kong", frequency: "97.9", streamURL: "http://stm.rthk.hk/radio3", genre: "Talk"),

        // MARK: - Free aggiuntive (round 2, verificate maggio 2026 via radio-browser API)
        // Major broadcaster atlantici/europei occidentali estesi al Free tier.
        RadioStation(id: 164, name: "RTÉ Radio 1", country: "Irlanda", frequency: "89.0", streamURL: "http://icecast.rte.ie/radio1", genre: "News", isPro: false),
        RadioStation(id: 165, name: "Today FM", country: "Irlanda", frequency: "100.0", streamURL: "https://stream.audioxi.com/TD", genre: "Pop", isPro: false),
        RadioStation(id: 166, name: "Rádio Renascença", country: "Portogallo", frequency: "103.4", streamURL: "http://22653.live.streamtheworld.com/RADIO_RENASCENCA_SC", genre: "News", isPro: false),

        // MARK: - Pro aggiuntive (round 2) — focus Oceano Atlantico + espansione globale
        // Irlanda extra
        RadioStation(id: 167, name: "Newstalk", country: "Irlanda", frequency: "106.0", streamURL: "https://edge.audioxi.com/NT", genre: "News"),
        RadioStation(id: 168, name: "8radio", country: "Irlanda", frequency: "—", streamURL: "https://edge4.audioxi.com/8RADIO", genre: "Alternative"),
        // Portogallo extra
        RadioStation(id: 169, name: "Rádio Observador", country: "Portogallo", frequency: "98.7", streamURL: "http://195.23.85.126:8455/stream", genre: "News"),
        // Islanda extra
        RadioStation(id: 170, name: "X977", country: "Islanda", frequency: "97.7", streamURL: "http://icecast.365net.is:8000/orbXid.aac", genre: "Rock"),
        // Atlantico — isole + africa atlantica
        RadioStation(id: 171, name: "RCV Rádio Cabo Verde", country: "Capo Verde", frequency: "—", streamURL: "https://a3.asurahosting.com:6980/radio.mp3", genre: "World"),
        RadioStation(id: 172, name: "Nanoq FM", country: "Groenlandia", frequency: "—", streamURL: "http://getnanoq.retro-radio.dk/Nanoq-TX-1", genre: "Pop"),
        RadioStation(id: 173, name: "Dr. Dick's Dub Shack", country: "Bermuda", frequency: "—", streamURL: "http://streamer.radio.co/s0635c8b0d/listen", genre: "Reggae"),
        RadioStation(id: 174, name: "Dakar Musique", country: "Senegal", frequency: "—", streamURL: "http://listen.senemultimedia.net:8090/stream", genre: "World"),
        // Caraibi atlantici
        RadioStation(id: 175, name: "Alpha Boys School Radio", country: "Giamaica", frequency: "—", streamURL: "http://alphaboys-live.streamguys1.com/alphaboys.mp3", genre: "Jazz"),
        RadioStation(id: 176, name: "Mello FM", country: "Giamaica", frequency: "88.0", streamURL: "http://peridot.streamguys.com:5660/live", genre: "Reggae"),
        RadioStation(id: 177, name: "Global FM", country: "Bahamas", frequency: "99.5", streamURL: "http://ice64.securenetsystems.net/GLOBALBS", genre: "Pop"),
        RadioStation(id: 178, name: "Guardian Radio", country: "Bahamas", frequency: "96.9", streamURL: "https://radiostreams.streamcomedia.com:8000/969guardianradio", genre: "News"),
        RadioStation(id: 179, name: "Hot 93", country: "Trinidad", frequency: "93.5", streamURL: "http://ice41.securenetsystems.net/HOTT93", genre: "Pop"),
        RadioStation(id: 180, name: "Radio Tambrin", country: "Trinidad", frequency: "92.7", streamURL: "http://ice42.securenetsystems.net/TAMBRIN", genre: "News"),
        // Atlantico nord — Canada
        RadioStation(id: 181, name: "680 News Toronto", country: "Canada", frequency: "680", streamURL: "https://rogers-hls.leanstream.co/rogers/tor680.stream/playlist.m3u8", genre: "News"),
        // Asia
        RadioStation(id: 182, name: "CCTV-13 News", country: "Cina", frequency: "—", streamURL: "https://piccpndali.v.myalicdn.com/audio/cctv13_2.m3u8", genre: "News"),
        RadioStation(id: 183, name: "FM Kahoku", country: "Giappone", frequency: "78.7", streamURL: "http://radio.kahoku.net:8000/;", genre: "Talk"),
        RadioStation(id: 184, name: "J1 Gold", country: "Giappone", frequency: "—", streamURL: "http://jenny.torontocast.com:8062/", genre: "J-Pop"),
        RadioStation(id: 185, name: "Taipei Radio", country: "Taiwan", frequency: "93.1", streamURL: "https://stream.ginnet.cloud/live0130lo-yfyo/_definst_/fm/playlist.m3u8", genre: "News"),
        RadioStation(id: 186, name: "Radio Taiwan International", country: "Taiwan", frequency: "—", streamURL: "https://streamak0138.akamaized.net/live0138lh-mbm9/_definst_/rti3/chunklist.m3u8", genre: "News"),
        RadioStation(id: 187, name: "Barangay LS 97.1", country: "Filippine", frequency: "97.1", streamURL: "http://28093.live.streamtheworld.com:3690/MORFM_S01AAC_SC", genre: "Talk"),
        RadioStation(id: 188, name: "Love Radio Dagupan", country: "Filippine", frequency: "98.3", streamURL: "https://loveradiodagupan.radioca.st/", genre: "Pop"),
        RadioStation(id: 189, name: "RFI Tiếng Việt", country: "Vietnam", frequency: "—", streamURL: "https://rfienvietnamien64k.ice.infomaniak.ch/rfienvietnamien-64.mp3", genre: "News"),
        RadioStation(id: 190, name: "VOH FM", country: "Vietnam", frequency: "99.9", streamURL: "https://strm.voh.com.vn/radio/channel3/chunklist_w1005696319.m3u8", genre: "Pop"),
        // Mediterraneo orientale + Medio Oriente
        RadioStation(id: 191, name: "Real FM", country: "Grecia", frequency: "97.8", streamURL: "http://netradio.live24.gr/realfm", genre: "News"),
        RadioStation(id: 192, name: "Arabesk FM", country: "Turchia", frequency: "—", streamURL: "http://yayin.arabeskfm.biz:8042/", genre: "Pop"),
        RadioStation(id: 193, name: "Al Arabiya FM", country: "Arabia Saudita", frequency: "99.0", streamURL: "https://fm.alarabiya.net/fm/myStream/playlist.m3u8", genre: "News"),
        RadioStation(id: 194, name: "Mp3Quran Tarateel", country: "Arabia Saudita", frequency: "—", streamURL: "https://qurango.net/radio/tarateel", genre: "World"),
        // America Latina
        RadioStation(id: 195, name: "La Ranchera Monterrey", country: "Messico", frequency: "1050", streamURL: "http://streamingcwsradio20.com:9410/stream", genre: "Latin"),
        RadioStation(id: 196, name: "La Kalle", country: "Colombia", frequency: "96.9", streamURL: "http://26683.live.streamtheworld.com/LA_KALLE_SC", genre: "Urban"),
        RadioStation(id: 197, name: "Radiónica RTVC", country: "Colombia", frequency: "99.1", streamURL: "http://shoutcast.rtvc.gov.co:8010/;", genre: "Alternative"),
        RadioStation(id: 198, name: "Unión Radio", country: "Venezuela", frequency: "90.3", streamURL: "http://ur58.lorini.net:2080/stream", genre: "News"),
        RadioStation(id: 199, name: "Bío-Bío Chile", country: "Cile", frequency: "99.7", streamURL: "https://unlimited3-cl.dps.live/biobiosantiago/aac/icecast.audio", genre: "News"),
        RadioStation(id: 200, name: "Radio Rivadavia", country: "Argentina", frequency: "630", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/RIVADAVIA.mp3", genre: "News"),
        RadioStation(id: 201, name: "Rock & Pop", country: "Argentina", frequency: "95.9", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/ROCKANDPOPAAC.aac", genre: "Rock"),
        RadioStation(id: 202, name: "Rádio Saudade FM", country: "Brasile", frequency: "99.7", streamURL: "https://playerservices.streamtheworld.com/api/livestream-redirect/SAUDADE_FMAAC.aac", genre: "Oldies"),
        // Oceania
        RadioStation(id: 203, name: "ABC Radio National", country: "Australia", frequency: "—", streamURL: "http://abc.streamguys1.com/live/rnnsw/icecast.audio", genre: "News"),
        RadioStation(id: 204, name: "ABC Country", country: "Australia", frequency: "—", streamURL: "http://live-radio01.mediahubaustralia.com/CTRW/mp3/", genre: "Country"),
        RadioStation(id: 205, name: "RNZ National", country: "Nuova Zelanda", frequency: "101.4", streamURL: "http://radionz-ice.streamguys.com/national.mp3", genre: "News"),
        // Europa centrale extra
        RadioStation(id: 206, name: "Rádió 1 Budapest", country: "Ungheria", frequency: "96.4", streamURL: "http://icast.connectmedia.hu/5201/live.mp3", genre: "Pop"),
        RadioStation(id: 207, name: "Kossuth Rádió", country: "Ungheria", frequency: "107.8", streamURL: "http://mr-stream.mediaconnect.hu/4734/mr1.aac", genre: "News"),
        // Africa
        RadioStation(id: 208, name: "94.7 Joburg", country: "Sud Africa", frequency: "94.7", streamURL: "http://27953.live.streamtheworld.com/FM947AAC_SC", genre: "Pop"),
        RadioStation(id: 209, name: "702 Johannesburg", country: "Sud Africa", frequency: "92.7", streamURL: "http://23543.live.streamtheworld.com:3690/FM702_SC", genre: "Talk")
    ]
    
    private override init() {
        super.init()
        loadPersistedState()
        // NOTE: do NOT activate an audio session here. AudioManager already owns
        // the active session (.playAndRecord) for the walkie. Activating .playback
        // at init clobbers it and triggers OSStatus -50 (paramErr) because the two
        // categories are incompatible. We swap categories lazily at play time via
        // `activateAudioSessionForPlayback()` and restore on stopRadio.
        setupRemoteCommandCenter()
        setupAudioInterruptionObserver()
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        if let favs = defaults.array(forKey: favoritesKey) as? [Int] {
            favoriteStationIds = Set(favs)
        }
        if let rec = defaults.array(forKey: recentsKey) as? [Int] {
            recentStationIds = rec
        }
    }

    /// Swap the shared `AVAudioSession` to `.playback` for radio streaming.
    /// Pure playback (no `.mixWithOthers`) so Now Playing widget works and
    /// we pause Apple Music / Spotify instead of layering on top of them.
    /// Called from `playStation()` — never at init, to avoid clobbering the
    /// walkie's `.playAndRecord` session (would yield OSStatus -50).
    private func activateAudioSessionForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .allowAirPlay])
            try audioSession.setActive(true)
            logger.logAudioInfo("Radio audio session attivata (.playback)")
        } catch {
            logger.logAudioError(error, context: "Attivazione radio audio session")
        }
    }

    /// Restore the walkie session (`.playAndRecord` + `.defaultToSpeaker`) when
    /// the user explicitly stops the radio, so mic capture works again.
    private func restoreWalkieAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            logger.logAudioInfo("Audio session ripristinata per walkie (.playAndRecord)")
        } catch {
            logger.logAudioError(error, context: "Ripristino walkie audio session")
        }
    }

    /// Subscribe to audio session interruptions so the radio auto-resumes after
    /// phone calls / Siri / alarms when the system requests it.
    private func setupAudioInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

        switch type {
        case .began:
            // System paused us (phone call / Siri / alarm). Reflect this in state
            // so the LA and Now Playing widget show the paused state immediately.
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isPlaying else { return }
                self.isPlaying = false
                if let station = self.currentStation {
                    self.setupNowPlayingInfo(for: station)
                    self.startOrUpdateLiveActivity(for: station)
                }
                self.logger.logAudioInfo("Audio interruption began — radio paused")
            }
        case .ended:
            let optionsRaw = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            guard options.contains(.shouldResume) else {
                self.logger.logAudioInfo("Audio interruption ended — system says no resume")
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.currentStation != nil, !self.isPlaying else { return }
                // Reactivate the session and resume playback. Reactivation can fail
                // if another app stole the focus permanently (rare); log and bail.
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    self.logger.logAudioError(error, context: "Reattivazione audio session post-interruzione")
                    return
                }
                self.resumeRadio()
                self.logger.logAudioInfo("Audio interruption ended — radio resumed")
            }
        @unknown default:
            break
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

        // Cleanup intermedio: chiamato da playStation come reset, NON come stop
        // utente. Saltiamo il resync walkie altrimenti per un frame appare la
        // walkie LA fra una stazione e l'altra.
        stopRadio(resyncWalkieAfter: false)

        guard let url = URL(string: station.streamURL) else {
            logger.logAudioError(NSError(domain: "RadioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL non valido"]), context: "Play station")
            return
        }

        // Switch the shared audio session to .playback BEFORE creating the
        // AVPlayer. Doing it after `player.play()` triggers a momentary
        // interruption and the lock-screen Now Playing widget can desync.
        activateAudioSessionForPlayback()

        isBuffering = true
        currentStation = station

        let player = AVPlayer(url: url)
        player.volume = volume
        radioPlayer = player

        // KVO sul player per stato di riproduzione e sul currentItem per il fallimento
        // dello stream. AVPlayer.error NON è KVO-osservabile in modo affidabile: gli
        // errori di rete (404, expired stream, redirect rotto) si propagano via
        // AVPlayerItem.status = .failed e via la notifica AVPlayerItemFailedToPlayToEndTime.
        player.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
        if let item = player.currentItem {
            item.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePlayerItemFailedToPlay(_:)),
                name: .AVPlayerItemFailedToPlayToEndTime,
                object: item
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePlayerItemNewErrorLogEntry(_:)),
                name: .AVPlayerItemNewErrorLogEntry,
                object: item
            )
        }

        // Reset errore precedente
        lastError = nil

        player.play()
        isPlaying = true

        // Configura Now Playing Info per Control Center
        setupNowPlayingInfo(for: station)

        // Avvia / aggiorna Live Activity (Dynamic Island + Lock Screen banner).
        startOrUpdateLiveActivity(for: station)

        // Traccia l'uso della radio in Firebase
        firebaseManager.trackRadioUsage(station: "\(station.name) - \(station.country)")

        // Registra come ultima stazione e nei recenti
        recordPlayedStation(station)

        logger.logAudioInfo("Avviata riproduzione: \(station.name) - \(station.country)")
    }

    private func recordPlayedStation(_ station: RadioStation) {
        UserDefaults.standard.set(station.id, forKey: lastStationKey)
        // Sposta in cima ai recenti (rimuovi duplicato precedente)
        var rec = recentStationIds.filter { $0 != station.id }
        rec.insert(station.id, at: 0)
        if rec.count > maxRecents { rec = Array(rec.prefix(maxRecents)) }
        recentStationIds = rec
        UserDefaults.standard.set(rec, forKey: recentsKey)
    }
    
    func stopRadio(resyncWalkieAfter: Bool = true) {
        teardownPlayer()
        isPlaying = false
        isBuffering = false
        currentStation = nil
        lastError = nil

        // Cancella Now Playing Info
        clearNowPlayingInfo()

        // Termina la Live Activity radio se attiva. Se si tratta di uno stop
        // utente esplicito (non un reset interno fra una stazione e l'altra),
        // lascia che il walkie riconquisti la Dynamic Island se ci sono ancora
        // peer connessi.
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.endRadio()
            if resyncWalkieAfter {
                LiveActivityManager.shared.resyncWalkieFromCurrentState()
            }
        }

        // Only on explicit user stop: hand the audio session back to the
        // walkie. Inter-station resets (resyncWalkieAfter=false) keep the
        // .playback category so the next playStation() doesn't pay another
        // category-swap latency.
        if resyncWalkieAfter {
            restoreWalkieAudioSession()
        }

        logger.logAudioInfo("Radio fermata")
    }

    func pauseRadio() {
        radioPlayer?.pause()
        isPlaying = false

        // Aggiorna Now Playing Info
        if let station = currentStation {
            setupNowPlayingInfo(for: station)
            startOrUpdateLiveActivity(for: station)
        }

        logger.logAudioInfo("Radio in pausa")
    }

    func resumeRadio() {
        radioPlayer?.play()
        isPlaying = true

        // Aggiorna Now Playing Info
        if let station = currentStation {
            setupNowPlayingInfo(for: station)
            startOrUpdateLiveActivity(for: station)
        }

        logger.logAudioInfo("Radio ripresa")
    }

    // MARK: - Live Activity glue

    /// Avvia la LA radio se non esiste, altrimenti la aggiorna.
    /// Chiamato dai punti che già aggiornano `MPNowPlayingInfoCenter`.
    private func startOrUpdateLiveActivity(for station: RadioStation) {
        guard #available(iOS 16.2, *) else { return }
        let manager = LiveActivityManager.shared
        // Il manager gestisce internamente start vs update: end+request se non c'è già
        // un'activity, update altrimenti. La logica "esiste già?" è incapsulata lì.
        manager.startOrUpdateRadio(
            stationName: station.name,
            country: station.country,
            flag: station.flagEmoji,
            frequency: station.frequency,
            genre: station.genre,
            isPlaying: isPlaying,
            isBuffering: isBuffering
        )
    }
    
    func setVolume(_ newVolume: Float) {
        volume = newVolume
        radioPlayer?.volume = newVolume
    }
    
    // MARK: - Free / Pro Stations

    /// Stazioni disponibili a tutti gli utenti (italiane + grandi broadcaster europei).
    var freeStations: [RadioStation] {
        radioStations.filter { !$0.isPro }
    }

    /// Stazioni internazionali premium sbloccabili con Talky Pro.
    var proStations: [RadioStation] {
        radioStations.filter { $0.isPro }
    }

    /// Pool di stazioni effettivamente navigabili dall'utente:
    /// - utente Pro → tutte
    /// - utente Free → solo le free
    /// Usata da next/prev/jump/resume per evitare di sbattere sul paywall a ogni tap.
    var availableStations: [RadioStation] {
        let isProUser = UserDefaults.standard.bool(forKey: "fastboot_isProUser")
        return isProUser ? radioStations : freeStations
    }

    // MARK: - Favorites

    /// Stazioni preferite ordinate alfabeticamente per nome.
    var favoriteStations: [RadioStation] {
        favoriteStationIds.compactMap { id in radioStations.first { $0.id == id } }
            .sorted { $0.name < $1.name }
    }

    func isFavorite(_ station: RadioStation) -> Bool {
        favoriteStationIds.contains(station.id)
    }

    func toggleFavorite(_ station: RadioStation) {
        if favoriteStationIds.contains(station.id) {
            favoriteStationIds.remove(station.id)
        } else {
            favoriteStationIds.insert(station.id)
        }
        UserDefaults.standard.set(Array(favoriteStationIds), forKey: favoritesKey)
        logger.logInfo("Favorites: toggled \(station.name) → \(favoriteStationIds.contains(station.id) ? "ON" : "OFF")")
    }

    // MARK: - Recents

    /// Ultime stazioni riprodotte (più recenti prima, max 10).
    var recentStations: [RadioStation] {
        recentStationIds.compactMap { id in radioStations.first { $0.id == id } }
    }

    // MARK: - Last Station (auto-resume)

    /// ID dell'ultima stazione riprodotta, persistito tra sessioni.
    var lastStationId: Int? {
        let v = UserDefaults.standard.integer(forKey: lastStationKey)
        return v == 0 ? nil : v
    }

    /// Restituisce l'ultima stazione riprodotta filtrata in base ai diritti utente.
    /// Per gli utenti Free, se l'ultima stazione era Pro si effettua fallback alla prima Free
    /// (evita di sbattere sul paywall ad ogni ingresso in modalità FM).
    /// Usata da ContentView per auto-resume all'apertura della modalità FM.
    var resumeStation: RadioStation {
        let pool = availableStations
        if let id = lastStationId, let s = pool.first(where: { $0.id == id }) {
            return s
        }
        // Fallback sicuro: prima stazione disponibile, altrimenti prima free (RTL 102.5).
        // freeStations è derivata da radioStations (let) che contiene sempre gli id 1...30,
        // quindi `freeStations.first` non può essere nil. Se mai dovesse esserlo (catastrofe
        // di build con array vuoto), restituiamo una stazione stub invece di crashare.
        return pool.first
            ?? freeStations.first
            ?? RadioStation(id: 1, name: "RTL 102.5", country: "Italia", frequency: "102.5", streamURL: "https://streamingv2.shoutcast.com/rtl-1025", genre: "Pop")
    }

    // MARK: - Locale-based grouping

    /// Paese del dispositivo mappato in italiano (es. "IT" → "Italia").
    /// Usato per mostrare la sezione "Vicino a te" in cima al browser.
    var deviceCountry: String {
        let code: String
        if #available(iOS 16, *) {
            code = Locale.current.region?.identifier ?? "IT"
        } else {
            code = Locale.current.regionCode ?? "IT"
        }
        return RadioManager.regionToCountry[code] ?? "Italia"
    }

    /// Stazioni del paese dell'utente (sezione "Vicino a te").
    var localStations: [RadioStation] {
        radioStations.filter { $0.country == deviceCountry }
    }

    /// Tutte le coppie (paese, stazioni) ordinate: paese locale per primo, poi alfabetico.
    /// Cache lazy: `radioStations` è `let` e `deviceCountry` è derivato dal Locale (immutabile
    /// a runtime), quindi è sicuro calcolare una sola volta ed evitare il re-bucket
    /// di 135 record su ogni keystroke della search bar.
    var stationsGroupedByCountry: [(country: String, stations: [RadioStation])] {
        _stationsGroupedByCountry
    }

    private lazy var _stationsGroupedByCountry: [(country: String, stations: [RadioStation])] = {
        let local = deviceCountry
        let grouped = Dictionary(grouping: radioStations) { $0.country }
        return grouped
            .map { (country: $0.key, stations: $0.value.sorted { $0.name < $1.name }) }
            .sorted { a, b in
                if a.country == local { return true }
                if b.country == local { return false }
                return a.country < b.country
            }
    }()

    /// Tutte le coppie (genere, stazioni) ordinate alfabeticamente.
    /// Cache lazy: i dati sono statici, calcoliamo una sola volta.
    var stationsGroupedByGenre: [(genre: String, stations: [RadioStation])] {
        _stationsGroupedByGenre
    }

    private lazy var _stationsGroupedByGenre: [(genre: String, stations: [RadioStation])] = {
        let grouped = Dictionary(grouping: radioStations) { $0.genre }
        return grouped
            .map { (genre: $0.key, stations: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.genre < $1.genre }
    }()

    // MARK: - Jump navigation (long-press +10/-10)

    /// Salta avanti di N stazioni (con wrap-around).
    /// Naviga solo tra le stazioni accessibili all'utente (free per Free, tutte per Pro)
    /// così un long-press +10 non finisce mai su una stazione Pro per un utente Free.
    func jumpStations(by offset: Int) {
        let pool = availableStations
        guard !pool.isEmpty else { return }
        // Se la stazione corrente non è nel pool (es. Pro scaduto mid-sessione) si parte da 0.
        let currentIndex = currentStation.flatMap { c in pool.firstIndex { $0.id == c.id } } ?? 0
        let count = pool.count
        let newIndex = ((currentIndex + offset) % count + count) % count
        playStation(pool[newIndex])
    }

    private static let regionToCountry: [String: String] = [
        "IT": "Italia", "FR": "Francia", "DE": "Germania", "GB": "UK", "UK": "UK",
        "ES": "Spagna", "US": "USA", "NL": "Olanda", "BE": "Belgio",
        "CH": "Svizzera", "AT": "Austria", "NO": "Norvegia", "DK": "Danimarca",
        "SE": "Svezia", "FI": "Finlandia", "IS": "Islanda", "PL": "Polonia",
        "CZ": "Rep. Ceca", "SK": "Slovacchia", "SI": "Slovenia", "HR": "Croazia",
        "RS": "Serbia", "BG": "Bulgaria", "EE": "Estonia", "LV": "Lettonia",
        "LT": "Lituania", "HU": "Ungheria", "RO": "Romania", "UA": "Ucraina",
        "RU": "Russia", "GR": "Grecia", "TR": "Turchia", "IL": "Israele",
        "PT": "Portogallo", "ZA": "Sud Africa", "MA": "Marocco", "EG": "Egitto",
        "KE": "Kenya", "NG": "Nigeria", "IN": "India", "PK": "Pakistan",
        "JP": "Giappone", "TH": "Thailandia", "ID": "Indonesia", "MY": "Malesia",
        "PH": "Filippine", "SG": "Singapore", "VN": "Vietnam", "NZ": "Nuova Zelanda",
        "AU": "Australia", "MX": "Messico", "AR": "Argentina", "BR": "Brasile",
        "CL": "Cile", "CO": "Colombia", "PE": "Perù", "UY": "Uruguay", "CU": "Cuba"
    ]

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
        // Naviga solo tra le stazioni effettivamente disponibili per evitare paywall storm.
        let pool = availableStations
        guard let current = currentStation,
              let currentIndex = pool.firstIndex(where: { $0.id == current.id }) else {
            if let first = pool.first {
                playStation(first)
            }
            return
        }

        let nextIndex = (currentIndex + 1) % pool.count
        playStation(pool[nextIndex])
    }

    func previousStation() {
        // Naviga solo tra le stazioni effettivamente disponibili per evitare paywall storm.
        let pool = availableStations
        guard let current = currentStation,
              let currentIndex = pool.firstIndex(where: { $0.id == current.id }) else {
            if let lastStation = pool.last {
                playStation(lastStation)
            }
            return
        }

        let previousIndex = currentIndex == 0 ? pool.count - 1 : currentIndex - 1
        playStation(pool[previousIndex])
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

        // I callback di MPRemoteCommandCenter sono invocati off-main da MediaPlayer.
        // La classe non è @MainActor per evitare ripple negli altri call site
        // (ContentView, AudioManager etc), quindi marshal-iamo esplicitamente sul main
        // dentro ogni handler. Tutte le mutazioni di @Published avvengono su main.

        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.resumeRadio() }
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.pauseRadio() }
            return .success
        }

        // Next track command
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.nextStation() }
            return .success
        }

        // Previous track command
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.previousStation() }
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
        // Identity guard: KVO callbacks for a previously-released player can land
        // here after `radioPlayer` was replaced. Without this check, we'd read state
        // from the NEW player while the event came from the OLD one, producing
        // stale `isBuffering`/`isPlaying` updates and "stuck spinner" bugs.
        if keyPath == "timeControlStatus", let player = object as? AVPlayer {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, player === self.radioPlayer else { return }
                switch player.timeControlStatus {
                case .playing:
                    self.isBuffering = false
                    self.isPlaying = true
                    self.lastError = nil
                    if let station = self.currentStation {
                        self.startOrUpdateLiveActivity(for: station)
                    }
                case .paused:
                    self.isBuffering = false
                    self.isPlaying = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                    if let station = self.currentStation {
                        self.startOrUpdateLiveActivity(for: station)
                    }
                @unknown default:
                    break
                }
            }
        } else if keyPath == "status", let item = object as? AVPlayerItem {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, item === self.radioPlayer?.currentItem else { return }
                if item.status == .failed {
                    self.handlePlaybackError(item.error)
                }
            }
        }
    }

    @objc private func handlePlayerItemFailedToPlay(_ notification: Notification) {
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Treat stream cutoffs as a soft failure: surface the error but keep the
            // station context so a manual retry from the LA / Now Playing works.
            self.handlePlaybackError(error)
        }
    }

    @objc private func handlePlayerItemNewErrorLogEntry(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem,
              let entry = item.errorLog()?.events.last else { return }
        self.logger.logAudioWarning("Stream errorLog: \(entry.errorComment ?? "?") (\(entry.errorStatusCode))")
    }

    /// Removes all observers and tears down the current player. Centralised so
    /// stop/replace paths can share one idempotent implementation — duplicating
    /// `removeObserver` in two places risked NSInternalInconsistencyException
    /// if a path nilled the player without removing the observer first.
    private func teardownPlayer() {
        guard let player = radioPlayer else { return }
        player.pause()
        player.removeObserver(self, forKeyPath: "timeControlStatus")
        if let item = player.currentItem {
            item.removeObserver(self, forKeyPath: "status")
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: item)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemNewErrorLogEntry, object: item)
        }
        radioPlayer = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopRadio()
    }
}