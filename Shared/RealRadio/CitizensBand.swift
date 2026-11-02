//creato da Andrea Piani - 02/11/26 - https://www.andreapiani.com - CitizensBand.swift
//  Talky
//
//  La CB vera sui 27 MHz: i 40 canali e la zona DX sopra il 40, ascoltati
//  dai KiwiSDR pubblici. Piu' lo squelch che tiene muto il fruscio fra un
//  passaggio e l'altro.

import Foundation

/// I 40 canali CB, uguali nei paesi CEPT e FCC, e la zona DX in SSB sopra
/// il canale 40, dove si chiama sulla 27.555 USB. La CEPT ammette AM, FM e
/// SSB su tutti i canali senza assegnarli: AM dall'1 al 35 e LSB dal 36 al
/// 40 e' l'uso degli operatori, non una regola.
nonisolated enum CitizensBand {
    /// Canale 1 in testa. Il 24 e il 25 stanno sotto il 23, da sempre.
    static let channels: [Int] = [
        26_965, 26_975, 26_985, 27_005, 27_015, 27_025, 27_035, 27_055, 27_065, 27_075,
        27_085, 27_105, 27_115, 27_125, 27_135, 27_155, 27_165, 27_175, 27_185, 27_205,
        27_215, 27_225, 27_255, 27_235, 27_245, 27_265, 27_275, 27_285, 27_295, 27_305,
        27_315, 27_325, 27_335, 27_345, 27_355, 27_365, 27_375, 27_385, 27_395, 27_405
    ].map { $0 * 1000 }

    /// Zona DX: chi lavora in SSB fuori canale tende a stare sui 5 kHz.
    static let dxLow = 27_415_000
    static let dxHigh = 27_855_000
    static let dxRaster = 5_000
    static let dxCall = 27_555_000

    /// Dove la manopola puo' andare: dal canale 1 alla fine della zona DX.
    static let dial = 26_960_000 ... 27_860_000

    /// Le frequenze che la scansione DX tocca, sul passo di 5 kHz.
    static let dxSteps: [Int] = Array(stride(from: dxLow, through: dxHigh, by: dxRaster))

    /// Numero del canale (1...40) se la frequenza e' esattamente su un canale.
    static func channel(at hz: Int) -> Int? {
        channels.firstIndex(of: hz).map { $0 + 1 }
    }

    static func isDX(_ hz: Int) -> Bool { hz > channels[39] + 5_000 }

    /// L'emissione che si usa di solito su un canale.
    static func usualEmission(channel: Int) -> Emission {
        channel >= 36 ? .lsb : .am
    }

    static func usualEmission(at hz: Int) -> Emission {
        if isDX(hz) { return .usb }
        return channel(at: hz).map(usualEmission(channel:)) ?? .am
    }

    /// Larghezza di banda giusta per l'emissione su un canale da 10 kHz.
    static func tuning(hz: Int, emission: Emission) -> Tuning {
        let bandwidth: Int
        switch emission {
        case .am: bandwidth = 2250      // passa +-4,5 kHz
        case .fm: bandwidth = 5000
        case .lsb, .usb: bandwidth = 2700
        case .cw: bandwidth = 500
        }
        return Tuning(hz: hz, emission: emission, bandwidth: bandwidth)
    }

    /// Prima accensione: la chiamata DX, dove c'e' piu' gente quando la banda e' aperta.
    static let firstTuning = tuning(hz: dxCall, emission: .usb)
}

/// Squelch automatico sull'S-meter del ricevitore: impara il rumore di fondo
/// e apre solo quando un segnale gli sta sopra. Lo legge il thread del
/// WebSocket, che decide per ogni pacchetto se l'audio passa, e la
/// scansione, che si ferma quando apre.
///
/// Tarato il 2/11/2026 su due KiwiSDR veri: in Dordogna il fondo CB
/// oscillava meno di 1 dB e una stazione sulla 27.555 saliva di 30; a
/// Fuerteventura il fondo cambiava di 15 dB da un canale all'altro e il
/// primo pacchetto portava l'S-meter a zero. Un ricevitore manda 6
/// pacchetti al secondo, l'altro 50: per questo i tempi sono in secondi.
/// E siccome il fondo cambia da un canale all'altro, si ricorda frequenza
/// per frequenza: la scansione si ferma su un canale rumoroso solo al primo
/// giro.
nonisolated final class Squelch: @unchecked Sendable {
    /// Sopra il rumore di tanto per aprire, di meno per restare aperto.
    static let openMargin = 7.0
    static let closeMargin = 4.0
    /// Coda dopo la fine del segnale, per non tagliare le pause fra le parole.
    static let hang: TimeInterval = 0.9
    /// Dopo un cambio di frequenza arrivano ancora pacchetti della vecchia.
    static let settle: TimeInterval = 0.3
    /// Un livello piatto cosi' a lungo e' rumore, una portante muta o un
    /// disturbo, non qualcuno che parla. Piatto deve esserlo l'S-meter e
    /// insieme l'audio: in SSB l'S-meter segue la voce, ma in AM misura la
    /// portante, che resta ferma mentre si parla, e in FM l'ampiezza non
    /// cambia mai. L'audio invece, con la voce, sale e scende di parecchi
    /// dB fra sillabe e pause; il fruscio e un fischio no.
    static let steadyWindow: TimeInterval = 4
    /// Scarto tipo dell'S-meter, in dB.
    static let steadySpread = 1.2
    /// Distanza fra il 10 e il 90 percentile del livello dei pacchetti
    /// audio, in dB. Misurato su 45 minuti di registrazioni radio, a 6 e a
    /// 50 pacchetti al secondo: il fruscio resta fra 0,2 e 2 dB, la voce
    /// sta quasi sempre sopra i 3.
    static let steadyAudioSpread = 2.5
    /// Si aggiunge al livello audio prima di passare ai dB (-60 dBFS): una
    /// portante senza modulazione da' un audio quasi muto, che senza questo
    /// gradino ballerebbe di qualche dB e non sembrerebbe piatto.
    static let audioFloor = 0.001
    /// Portante muta chiusa e poi qualcuno ci parla sopra: in AM e in FM
    /// l'S-meter non si muove, l'audio si'. Riapre quando la mediana
    /// dell'audio dell'ultimo secondo sale di tanto sopra quella del muto.
    static let wakeWindow: TimeInterval = 1
    static let wakeRise = 10.0

    /// Dove si ascolta: il rumore di fondo cambia con la frequenza e con la
    /// larghezza di banda, che segue l'emissione.
    nonisolated private struct Spot: Hashable {
        let hz: Int
        let emission: Emission
    }

    /// Il fondo prima della portante muta e la mediana dell'audio del muto.
    private typealias Muted = (floor: Double, audioDB: Double)

    private let lock = NSLock()
    private var enabled: Bool
    private var spot: Spot?
    private var floor: Double?
    /// Fondo imparato su ogni frequenza ascoltata con questo ricevitore.
    private var floors: [Spot: Double] = [:]
    /// Ultimo fondo per emissione, per le frequenze mai ascoltate.
    private var modeFloors: [Emission: Double] = [:]
    private var smoothed: Double?
    private var open = false
    private var noiseOnly = false
    /// Chiuso dalla regola del livello piatto con un segnale ancora sopra il
    /// fondo: il fondo di prima e la mediana dell'audio quando si e' chiuso.
    private var muted: Muted?
    /// Le portanti mute lasciate su ogni frequenza, per riaprire se ci si
    /// torna e qualcuno ci sta parlando sopra.
    private var mutes: [Spot: Muted] = [:]
    private var lastAbove = Date.distantPast
    private var lastFeed = Date.distantPast
    private var settleUntil = Date.distantPast
    private var recent: [(at: Date, dBm: Double, audioDB: Double)] = []

    init(enabled: Bool) {
        self.enabled = enabled
    }

    var isEnabled: Bool {
        get { locked { enabled } }
        set { locked { enabled = newValue } }
    }

    /// C'e' un segnale adesso (vale anche a squelch spento, per la scansione).
    var isOpen: Bool { locked { open } }

    /// L'ultima apertura era solo rumore o una portante muta: la scansione
    /// puo' andare avanti subito, senza aspettare la coda.
    var closedOnNoise: Bool { locked { noiseOnly } }

    /// Frequenza o emissione cambiata: il segnale non c'e' piu', il rumore
    /// di fondo e' quello gia' imparato li', o il piu' recente per quella
    /// emissione.
    func retuned(to tuning: Tuning) {
        locked {
            remember()
            let next = Spot(hz: tuning.hz, emission: tuning.emission)
            spot = next
            floor = floors[next] ?? modeFloors[next.emission] ?? floor
            restart()
            muted = mutes[next]
        }
    }

    /// Ricevitore nuovo: anche il rumore di fondo e' da reimparare.
    func reset(for tuning: Tuning) {
        locked {
            spot = Spot(hz: tuning.hz, emission: tuning.emission)
            floor = nil
            floors = [:]
            modeFloors = [:]
            mutes = [:]
            restart()
        }
    }

    /// Un pacchetto con il suo S-meter e il livello RMS del suo audio.
    /// `pass`: l'audio va all'altoparlante. `changed`: lo stato
    /// aperto/chiuso e' appena cambiato.
    func feed(dBm: Double, audio rms: Float) -> (pass: Bool, open: Bool, changed: Bool) {
        locked {
            let was = open
            let now = Date()
            // S-meter a zero: il ricevitore non ha ancora misurato niente.
            guard dBm > -126.5 else { return (open || !enabled, open, false) }
            guard now >= settleUntil else {
                open = false
                return (!enabled, false, was)
            }
            let dt = min(0.5, now.timeIntervalSince(lastFeed))
            lastFeed = now
            let s = smoothed.map { $0 + (dBm - $0) * min(1, dt * 6) } ?? dBm
            smoothed = s
            recent.append((now, dBm, 20 * log10(Double(rms) + Self.audioFloor)))
            recent.removeAll { now.timeIntervalSince($0.at) > Self.steadyWindow }

            guard let f = floor else {
                floor = s
                return (!enabled, false, was)
            }
            if open {
                if s > f + Self.closeMargin {
                    lastAbove = now
                } else if now.timeIntervalSince(lastAbove) > Self.hang {
                    open = false
                }
            } else if s > f + Self.openMargin {
                open = true
                noiseOnly = false
                lastAbove = now
            } else {
                // Giu' in fretta, su piano, un dB al secondo. A squelch aperto
                // il fondo resta fermo, cosi' un passaggio lungo non lo alza.
                floor = s < f ? f + (s - f) * min(1, dt * 4) : f + min(s - f, dt)
            }
            if let level = steadyLevel(now: now), level > (floor ?? level) {
                if muted == nil, let before = floor, let audio = audioMedian(since: now - Self.steadyWindow) {
                    muted = (before, audio)
                }
                floor = level
                if open { noiseOnly = true }
                open = false
            } else if !open, let m = muted {
                if s < m.floor + Self.openMargin {
                    // La portante non c'e' piu': si torna allo squelch normale.
                    muted = nil
                } else if let audio = audioMedian(since: now - Self.wakeWindow), audio > m.audioDB + Self.wakeRise {
                    floor = m.floor
                    muted = nil
                    open = true
                    noiseOnly = false
                    lastAbove = now
                }
            }
            return (open || !enabled, open, open != was)
        }
    }

    /// Il livello medio dell'S-meter, se negli ultimi secondi sono rimasti
    /// piatti sia lui sia l'audio.
    private func steadyLevel(now: Date) -> Double? {
        guard let first = recent.first, now.timeIntervalSince(first.at) > Self.steadyWindow - 0.25,
              recent.count >= 8 else { return nil }
        let count = Double(recent.count)
        let mean = recent.reduce(0) { $0 + $1.dBm } / count
        let spread = (recent.reduce(0) { $0 + ($1.dBm - mean) * ($1.dBm - mean) } / count).squareRoot()
        guard spread < Self.steadySpread else { return nil }
        let audio = recent.map { $0.audioDB }.sorted()
        let low = audio[Int(Double(audio.count - 1) * 0.1)]
        let high = audio[Int(Double(audio.count - 1) * 0.9)]
        return high - low < Self.steadyAudioSpread ? mean : nil
    }

    /// Mediana del livello audio dei pacchetti arrivati da `start` in poi.
    private func audioMedian(since start: Date) -> Double? {
        let audio = recent.filter { $0.at >= start }.map { $0.audioDB }.sorted()
        guard audio.count >= 4 else { return nil }
        return audio[audio.count / 2]
    }

    /// Salva il fondo della frequenza che si lascia.
    private func remember() {
        guard let spot, let floor else { return }
        // Tanti passi di sintonia fine: basta ripartire da capo.
        if floors.count > 600 {
            floors = [:]
            mutes = [:]
        }
        floors[spot] = floor
        modeFloors[spot.emission] = floor
        mutes[spot] = muted
    }

    private func restart() {
        open = false
        noiseOnly = false
        muted = nil
        smoothed = nil
        recent = []
        settleUntil = Date().addingTimeInterval(Self.settle)
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
