//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - TransmissionEntry.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation

/// Rappresenta una singola trasmissione audio ricevuta, persistita su disco.
struct TransmissionEntry: Codable, Identifiable {
    let id: UUID
    let peerName: String
    let timestamp: Date
    let estimatedDurationSeconds: TimeInterval

    init(id: UUID = UUID(),
         peerName: String,
         timestamp: Date = Date(),
         estimatedDurationSeconds: TimeInterval) {
        self.id = id
        self.peerName = peerName
        self.timestamp = timestamp
        self.estimatedDurationSeconds = estimatedDurationSeconds
    }

    /// Stringa relativa in italiano: "ora", "5 min fa", "2 h fa", "3 g fa".
    var relativeTimeString: String {
        let interval = Date().timeIntervalSince(timestamp)
        // Sotto il minuto consideriamo l'evento appena accaduto
        if interval < 60 {
            return "ora"
        }
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes) min fa"
        }
        let hours = Int(interval / 3600)
        if hours < 24 {
            return "\(hours) h fa"
        }
        let days = Int(interval / 86400)
        return "\(days) g fa"
    }

    /// Durata formattata m:ss (es. "0:08", "1:23")
    var durationFormatted: String {
        let total = max(0, Int(estimatedDurationSeconds.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
