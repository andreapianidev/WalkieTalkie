//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - TransmissionHistoryManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import Combine

/// Gestisce la cronologia delle trasmissioni audio ricevute.
/// Persistenza su file JSON nella Documents directory (non UserDefaults
/// perché il limite di 4MB sarebbe facilmente superato con molte entry).
@MainActor
final class TransmissionHistoryManager: ObservableObject {
    static let shared = TransmissionHistoryManager()

    @Published var entries: [TransmissionEntry] = []

    /// Stima byte/secondo per audio PCM 16-bit 16kHz mono.
    private let bytesPerSecond: Double = 32000.0
    /// Numero massimo di entry mantenute (le più vecchie vengono droppate).
    private let maxEntries = 500
    private let logger = Logger.shared
    private let fileName = "transmission_history.json"

    private init() {
        loadFromDisk()
    }

    // MARK: - API pubblica

    /// Registra una nuova ricezione, la prepende alla lista e persiste su disco.
    func recordReception(peerName: String, dataSize: Int) {
        let duration = Double(dataSize) / bytesPerSecond
        let entry = TransmissionEntry(
            peerName: peerName,
            timestamp: Date(),
            estimatedDurationSeconds: duration
        )

        // Inserimento in testa: l'elemento più recente è sempre il primo
        entries.insert(entry, at: 0)

        // Cap a maxEntries scartando le più vecchie in coda
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        logger.logInfo("History: registrata trasmissione da \(peerName) (\(dataSize) bytes, ~\(String(format: "%.2f", duration))s)")
        persistToDisk()
    }

    /// Svuota la cronologia e persiste lo stato vuoto.
    func clearAll() {
        entries.removeAll()
        logger.logInfo("History: cronologia trasmissioni cancellata")
        persistToDisk()
    }

    // MARK: - Persistenza

    private var fileURL: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent(fileName)
    }

    private func loadFromDisk() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode([TransmissionEntry].self, from: data)
            self.entries = loaded
            logger.logInfo("History: caricate \(loaded.count) entry da disco")
        } catch {
            logger.logError(error, context: "TransmissionHistoryManager.loadFromDisk")
        }
    }

    private func persistToDisk() {
        guard let url = fileURL else {
            logger.logWarning("History: URL documents non disponibile, persistenza saltata")
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: url, options: [.atomic])
        } catch {
            logger.logError(error, context: "TransmissionHistoryManager.persistToDisk")
        }
    }
}
