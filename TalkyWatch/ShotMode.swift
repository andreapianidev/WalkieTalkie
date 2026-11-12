//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - ShotMode.swift
//  TalkyWatch
//
//  Solo Debug, per le schermate dello Store dal simulatore, dove non c'e' un
//  iPhone che mandi le stazioni. Si accende con gli argomenti di lancio:
//  -wristShots 1 (stazioni vere del catalogo, due dispositivi sul walkie),
//  -wristPage 0/1/2 (radio, walkie, bande), -wristPlay <id> (suona quella).
//  -wristProbe 1, con l'iPhone accoppiato: aspetta le stazioni, poi preme e
//  lascia il PTT da solo, perche' nel simulatore il tasto non si puo' toccare.

#if DEBUG
import Foundation

enum ShotMode {
    static var on: Bool { UserDefaults.standard.bool(forKey: "wristShots") }
    static var page: Int { UserDefaults.standard.integer(forKey: "wristPage") }
    /// Id della stazione da far suonare all'avvio, 0 per nessuna.
    static var play: Int { UserDefaults.standard.integer(forKey: "wristPlay") }
    static var probe: Bool { UserDefaults.standard.bool(forKey: "wristProbe") }

    static func runProbe(_ phone: PhoneLink) async {
        for _ in 0 ..< 60 where phone.stations.isEmpty {
            try? await Task.sleep(for: .milliseconds(500))
        }
        _ = await phone.ptt(true)
        try? await Task.sleep(for: .seconds(1))
        _ = await phone.ptt(false)
    }

    /// Le stesse voci di RadioManager.catalog sull'iPhone, con il paese nella
    /// lingua del simulatore come lo manderebbe l'iPhone.
    static var stations: [WristStation] {
        let rows: [(Int, String, String, String, String, String)] = [
            (19, "FIP", "🇫🇷", "FR", "105.1", "http://icecast.radiofrance.fr/fip-hifi.aac"),
            (33, "Classic FM", "🇬🇧", "GB", "100.0", "http://ice-the.musicradio.com/ClassicFMMP3"),
            (49, "Radio Swiss Jazz", "🇨🇭", "CH", "JAZZ", "http://stream.srg-ssr.ch/m/rsj/mp3_128"),
            (1, "RTL 102.5", "🇮🇹", "IT", "102.5", "https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/audiostream/S97044836/tbbP8T1ZRPBL/playlist_audio.m3u8"),
            (21, "1LIVE", "🇩🇪", "DE", "106.7", "http://wdr-1live-live.icecast.wdr.de/wdr/1live/live/mp3/128/stream.mp3"),
            (28, "Cadena SER", "🇪🇸", "ES", "105.4", "https://playerservices.streamtheworld.com/api/livestream-redirect/CADENASER.mp3"),
            (155, "NPR News", "🇺🇸", "US", "NEWS", "https://npr-ice.streamguys1.com/live.mp3"),
            (16, "NRJ", "🇫🇷", "FR", "100.3", "https://streaming.nrjaudio.fm/oumvmk8fnozc"),
            (3, "Rai Radio 1", "🇮🇹", "IT", "89.7", "http://icestreaming.rai.it/1.mp3"),
        ]
        return rows.map { id, name, flag, region, dial, url in
            WristStation(id: id, name: name, flag: flag,
                         place: Locale.current.localizedString(forRegionCode: region) ?? region,
                         dial: dial, url: url, isPro: id > 30)
        }
    }
}
#endif
