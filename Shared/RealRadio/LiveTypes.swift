//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - LiveTypes.swift
//  Talky
//
//  Ascolto dal vivo: tipi comuni a HF (KiwiSDR) e POC (Mumble).
//  Portato da RadioKit di Etere, ridotto alla sola ricezione.

import Foundation

/// Un blocco di audio ricevuto, mono, in float.
nonisolated struct PCMChunk: Sendable {
    var samples: [Float]
    var sampleRate: Double

    /// Inviluppo 0...1, abbastanza per un indicatore di livello.
    var envelope: Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        let rms = (sum / Float(samples.count)).squareRoot()
        return min(1, rms * 2.2)
    }
}

/// Perché un collegamento non va. Il testo per l'utente lo sceglie l'interfaccia.
nonisolated enum LiveProblem: Sendable, Equatable {
    case full          // ricevitore o server pieno
    case refused       // rifiuto esplicito (indirizzo bloccato, password)
    case down          // fuori servizio
    case closed        // chiusura dall'altra parte, tempo limite
    case timeout       // nessuna risposta
    case needsCertificate
}

nonisolated enum LinkState: Sendable, Equatable {
    case idle
    case connecting
    case online
    case refused(LiveProblem)
    case dropped(LiveProblem)
}

nonisolated enum LiveEvent: Sendable {
    case link(LinkState)
    /// Chi sta parlando adesso su un canale POC, nil a fine passaggio.
    case talker(String?)
    /// Persone nel canale POC, noi esclusi.
    case audience(Int)
    /// Nome del canale in cui siamo davvero entrati.
    case channel(String)
    /// Segnale in dBm misurato dal ricevitore HF.
    case signal(dBm: Double)
    /// Livello dell'audio in arrivo, 0...1.
    case level(Float)
}

nonisolated enum Emission: String, Sendable, Codable, CaseIterable {
    case lsb = "LSB"
    case usb = "USB"
    case am = "AM"
    case cw = "CW"
}

nonisolated struct Tuning: Sendable, Hashable, Codable {
    var hz: Int
    var emission: Emission
    var bandwidth: Int

    static let hfRange = 100_000 ... 30_000_000

    /// "5.505" per 5 505 000 Hz.
    var megahertzText: String {
        String(format: "%.3f", Double(hz) / 1_000_000)
    }
}

/// Convenzione IARU per l'HF: S9 vale -73 dBm, ogni unita' S 6 dB.
nonisolated enum SignalScale {
    static func label(dBm: Double) -> String {
        if dBm <= -73 {
            let units = max(0, 9 + (dBm + 73) / 6)
            return "S\(Int(units.rounded(.down)))"
        }
        return "S9+\(Int(min(60, dBm + 73).rounded()))"
    }

    /// 0...1 su tutta la scala S0...S9+40, per una barra.
    static func fraction(dBm: Double) -> Double {
        let low = -127.0, high = -33.0
        return max(0, min(1, (dBm - low) / (high - low)))
    }
}

nonisolated enum LinkError: Error {
    case closed(LiveProblem)
    case timeout
}
