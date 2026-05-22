//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - RecordingsManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import Combine

/// Tipo di registrazione.
enum RecordingType: String, Codable {
    case sent
    case received
}

/// Metadata di una registrazione audio salvata sul disco.
struct AudioRecording: Identifiable, Codable {
    let id: UUID
    let filename: String
    let timestamp: Date
    let type: RecordingType
    let peerName: String?
    let durationSeconds: TimeInterval
    let fileSize: Int
}

/// Manager singleton per la persistenza delle registrazioni audio.
/// Le registrazioni sono Pro-only: i metodi di save no-op silenziosamente se l'utente non è Pro.
@MainActor
final class RecordingsManager: ObservableObject {
    static let shared = RecordingsManager()

    // MARK: - Published

    @Published var recordings: [AudioRecording] = []

    // MARK: - Costanti

    /// Numero massimo di registrazioni conservate. Le più vecchie vengono droppate.
    private let maxRecordings = 100

    /// Sample rate stimato per il PCM Float32 mono utilizzato: 8000 frame/s -> 32000 bytes/s.
    /// (Float32 = 4 byte, mono, 8kHz nominale lato trasmissione.)
    private let bytesPerSecond: Double = 32000

    private let logger = Logger.shared
    private let fileManager = FileManager.default
    private let indexFilename = "index.json"

    // MARK: - Init

    private init() {
        ensureDirectoryExists()
        loadIndex()
    }

    // MARK: - Pro

    var isProUser: Bool {
        UserDefaults.standard.bool(forKey: "fastboot_isProUser")
    }

    // MARK: - Paths

    private var recordingsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("recordings", isDirectory: true)
    }

    private var indexURL: URL {
        recordingsDirectory.appendingPathComponent(indexFilename)
    }

    private func fileURL(for filename: String) -> URL {
        recordingsDirectory.appendingPathComponent(filename)
    }

    private func ensureDirectoryExists() {
        do {
            if !fileManager.fileExists(atPath: recordingsDirectory.path) {
                try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
                logger.logAudioInfo("Cartella recordings creata: \(recordingsDirectory.path)")
            }
        } catch {
            logger.logAudioError(error, context: "Creazione cartella recordings")
        }
    }

    // MARK: - Public API

    /// DEPRECATA per motivi di privacy: registrare audio di altri peer senza il loro
    /// consenso esplicito viola guidelines App Store + GDPR. La funzione è no-op
    /// permanente. Mantenuta solo come stub per compatibilità con eventuali call site
    /// non ancora rimossi. Eliminare quando confermato che nessun chiamante esiste.
    @available(*, deprecated, message: "Privacy: non si registrano voci di terzi. Usa saveTransmittedAudio per le proprie trasmissioni.")
    func saveReceivedAudio(_ data: Data, peerName: String) {
        // no-op intenzionale
    }

    /// Salva audio trasmesso. No-op se non Pro.
    func saveTransmittedAudio(_ data: Data) {
        guard isProUser else { return }
        save(data: data, type: .sent, peerName: nil)
    }

    /// Elimina una registrazione (file + metadata).
    func delete(_ recording: AudioRecording) {
        let url = fileURL(for: recording.filename)
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch {
            logger.logAudioError(error, context: "Eliminazione file registrazione")
        }
        recordings.removeAll { $0.id == recording.id }
        persistIndex()
        logger.logAudioInfo("Registrazione eliminata: \(recording.filename)")
    }

    /// Elimina tutte le registrazioni.
    func deleteAll() {
        for recording in recordings {
            let url = fileURL(for: recording.filename)
            try? fileManager.removeItem(at: url)
        }
        recordings.removeAll()
        persistIndex()
        logger.logAudioInfo("Tutte le registrazioni eliminate")
    }

    /// Riproduce una registrazione tramite AudioManager (passa PCM raw a playReceivedAudio).
    func playRecording(_ recording: AudioRecording) {
        let url = fileURL(for: recording.filename)
        guard fileManager.fileExists(atPath: url.path) else {
            logger.logAudioWarning("File registrazione non trovato: \(recording.filename)")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            AudioManager.shared.playReceivedAudio(data)
            logger.logAudioInfo("Riproduzione registrazione: \(recording.filename) (\(data.count) bytes)")
        } catch {
            logger.logAudioError(error, context: "Caricamento PCM registrazione")
        }
    }

    // MARK: - Private save

    private func save(data: Data, type: RecordingType, peerName: String?) {
        guard !data.isEmpty else {
            logger.logAudioDebug("Skip salvataggio: dati vuoti")
            return
        }
        ensureDirectoryExists()

        let id = UUID()
        let filename = "\(id.uuidString).pcm"
        let url = fileURL(for: filename)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.logAudioError(error, context: "Salvataggio PCM registrazione")
            return
        }

        let duration = Double(data.count) / bytesPerSecond
        let recording = AudioRecording(
            id: id,
            filename: filename,
            timestamp: Date(),
            type: type,
            peerName: peerName,
            durationSeconds: duration,
            fileSize: data.count
        )

        // Newest first
        recordings.insert(recording, at: 0)
        enforceCap()
        persistIndex()
        logger.logAudioInfo("Registrazione salvata: \(filename) (type=\(type.rawValue), \(data.count) bytes)")
    }

    private func enforceCap() {
        guard recordings.count > maxRecordings else { return }
        let toDrop = recordings.suffix(recordings.count - maxRecordings)
        for old in toDrop {
            let url = fileURL(for: old.filename)
            try? fileManager.removeItem(at: url)
        }
        recordings = Array(recordings.prefix(maxRecordings))
        logger.logAudioInfo("Cap registrazioni applicato: \(toDrop.count) rimosse")
    }

    // MARK: - Index persistence

    private func loadIndex() {
        let url = indexURL
        guard fileManager.fileExists(atPath: url.path) else {
            recordings = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([AudioRecording].self, from: data)
            // Filtra entry il cui file non esiste più
            recordings = loaded.filter { fileManager.fileExists(atPath: fileURL(for: $0.filename).path) }
            // Garantisci ordine newest first
            recordings.sort { $0.timestamp > $1.timestamp }
            logger.logAudioInfo("Index registrazioni caricato: \(recordings.count) entries")
        } catch {
            logger.logAudioError(error, context: "Caricamento index registrazioni")
            recordings = []
        }
    }

    private func persistIndex() {
        let url = indexURL
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(recordings)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.logAudioError(error, context: "Persistenza index registrazioni")
        }
    }
}
