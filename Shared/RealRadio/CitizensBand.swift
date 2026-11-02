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
nonisolated final class Squelch: @unchecked Sendable {
    /// Sopra il rumore di tanto per aprire, di meno per restare aperto.
    static let openMargin = 7.0
    static let closeMargin = 4.0
    /// Coda dopo la fine del segnale, per non tagliare le pause fra le parole.
    static let hang: TimeInterval = 0.9
    /// Dopo un cambio di frequenza arrivano ancora pacchetti della vecchia.
    static let settle: TimeInterval = 0.3
    /// Un livello piatto cosi' a lungo e' una portante muta o un disturbo,
    /// non qualcuno che parla: la voce fa oscillare l'S-meter di piu'.
    static let steadyWindow: TimeInterval = 4
    static let steadySpread = 1.2

    private let lock = NSLock()
    private var enabled: Bool
    private var floor: Double?
    private var smoothed: Double?
    private var open = false
    private var lastAbove = Date.distantPast
    private var lastFeed = Date.distantPast
    private var settleUntil = Date.distantPast
    private var recent: [(at: Date, dBm: Double)] = []

    init(enabled: Bool) {
        self.enabled = enabled
    }

    var isEnabled: Bool {
        get { locked { enabled } }
        set { locked { enabled = newValue } }
    }

    /// C'e' un segnale adesso (vale anche a squelch spento, per la scansione).
    var isOpen: Bool { locked { open } }

    /// Frequenza cambiata: il rumore di fondo resta, il segnale no.
    func retuned() {
        locked {
            open = false
            smoothed = nil
            recent = []
            settleUntil = Date().addingTimeInterval(Self.settle)
        }
    }

    /// Ricevitore nuovo: anche il rumore di fondo e' da reimparare.
    func reset() {
        locked {
            open = false
            floor = nil
            smoothed = nil
            recent = []
            settleUntil = Date().addingTimeInterval(Self.settle)
        }
    }

    /// Un pacchetto con il suo S-meter. `pass`: l'audio va all'altoparlante.
    /// `changed`: lo stato aperto/chiuso e' appena cambiato.
    func feed(dBm: Double) -> (pass: Bool, open: Bool, changed: Bool) {
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
            recent.append((now, dBm))
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
                lastAbove = now
            } else {
                // Giu' in fretta, su piano, un dB al secondo. A squelch aperto
                // il fondo resta fermo, cosi' un passaggio lungo non lo alza.
                floor = s < f ? f + (s - f) * min(1, dt * 4) : f + min(s - f, dt)
            }
            if let level = steadyLevel(now: now), level > (floor ?? level) {
                floor = level
                open = false
            }
            return (open || !enabled, open, open != was)
        }
    }

    /// Il livello medio, se negli ultimi secondi e' rimasto piatto.
    private func steadyLevel(now: Date) -> Double? {
        guard let first = recent.first, now.timeIntervalSince(first.at) > Self.steadyWindow - 0.25,
              recent.count >= 8 else { return nil }
        let mean = recent.reduce(0) { $0 + $1.dBm } / Double(recent.count)
        let spread = (recent.reduce(0) { $0 + ($1.dBm - mean) * ($1.dBm - mean) } / Double(recent.count)).squareRoot()
        return spread < Self.steadySpread ? mean : nil
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
