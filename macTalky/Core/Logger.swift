//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - Logger.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import Foundation
import os.log

/// Sistema di logging centralizzato per l'app WalkieTalkie
class Logger {
    static let shared = Logger()
    
    private let subsystem = "com.andreapiani.walkietalkie"

    
    // Logger specifici per diverse categorie
    private let networkLogger = OSLog(subsystem: "com.andreapiani.walkietalkie", category: "Network")
    private let audioLogger = OSLog(subsystem: "com.andreapiani.walkietalkie", category: "Audio")
    private let uiLogger = OSLog(subsystem: "com.andreapiani.walkietalkie", category: "UI")
    private let generalLogger = OSLog(subsystem: "com.andreapiani.walkietalkie", category: "General")
    
    private init() {}
    
    // MARK: - Network Logging
    
    func logNetworkInfo(_ message: String) {
        os_log("%@", log: networkLogger, type: .info, message)
    }
    
    func logNetworkError(_ error: Error, context: String = "") {
        let errorMessage = context.isEmpty ? "\(error.localizedDescription)" : "\(context): \(error.localizedDescription)"
        os_log("%@", log: networkLogger, type: .error, errorMessage)
        

    }
    
    func logNetworkDebug(_ message: String) {
        os_log("%@", log: networkLogger, type: .debug, message)
    }
    
    func logNetworkWarning(_ message: String) {
        os_log("%@", log: networkLogger, type: .default, message)
    }
    
    // MARK: - Audio Logging
    
    func logAudioInfo(_ message: String) {
        os_log("%@", log: audioLogger, type: .info, message)
    }
    
    func logAudioError(_ error: Error, context: String = "") {
        let errorMessage = context.isEmpty ? "\(error.localizedDescription)" : "\(context): \(error.localizedDescription)"
        os_log("%@", log: audioLogger, type: .error, errorMessage)
        

    }
    
    func logAudioDebug(_ message: String) {
        os_log("%@", log: audioLogger, type: .debug, message)
    }
    
    func logAudioWarning(_ message: String) {
        os_log("%@", log: audioLogger, type: .default, message)
    }
    
    // MARK: - UI Logging
    
    func logUIInfo(_ message: String) {
        os_log("%@", log: uiLogger, type: .info, message)
    }
    
    func logUIError(_ error: Error, context: String = "") {
        let errorMessage = context.isEmpty ? "\(error.localizedDescription)" : "\(context): \(error.localizedDescription)"
        os_log("%@", log: uiLogger, type: .error, errorMessage)
        

    }
    
    // MARK: - General Logging
    
    func logInfo(_ message: String) {
        os_log("%@", log: generalLogger, type: .info, message)
    }
    
    func logError(_ error: Error, context: String = "") {
        let errorMessage = context.isEmpty ? "\(error.localizedDescription)" : "\(context): \(error.localizedDescription)"
        os_log("%@", log: generalLogger, type: .error, errorMessage)
        

    }
    
    func logDebug(_ message: String) {
        os_log("%@", log: generalLogger, type: .debug, message)
    }
    
    func logWarning(_ message: String) {
        os_log("%@", log: generalLogger, type: .default, "⚠️ \(message)")
    }
}

// MARK: - Error Types

enum WalkieTalkieError: LocalizedError {
    case audioSetupFailed(underlying: Error)
    case audioTransmissionFailed(underlying: Error)
    case networkConnectionFailed(underlying: Error)
    case peerInvitationFailed(peerName: String)
    case audioEngineNotAvailable
    case audioPermissionDenied
    case noConnectedPeers
    case invalidAudioFormat
    case invalidPeer
    
    var errorDescription: String? {
        switch self {
        case .audioSetupFailed(let error):
            return "Errore configurazione audio: \(error.localizedDescription)"
        case .audioTransmissionFailed(let error):
            return "Errore trasmissione audio: \(error.localizedDescription)"
        case .networkConnectionFailed(let error):
            return "Errore connessione di rete: \(error.localizedDescription)"
        case .peerInvitationFailed(let peerName):
            return "Impossibile invitare il dispositivo \(peerName)"
        case .audioEngineNotAvailable:
            return "Audio engine non disponibile"
        case .audioPermissionDenied:
            return "Permessi microfono negati"
        case .noConnectedPeers:
            return "Nessun dispositivo connesso"
        case .invalidAudioFormat:
            return "Formato audio non valido"
        case .invalidPeer:
            return "Dispositivo non autorizzato rilevato"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .audioSetupFailed:
            return "Verifica i permessi del microfono nelle impostazioni"
        case .audioTransmissionFailed:
            return "Riprova la trasmissione o riavvia l'app"
        case .networkConnectionFailed:
            return "Verifica la connessione di rete e i permessi"
        case .peerInvitationFailed:
            return "Assicurati che l'altro dispositivo sia disponibile"
        case .audioEngineNotAvailable:
            return "Riavvia l'app per reinizializzare l'audio"
        case .audioPermissionDenied:
            return "Concedi i permessi del microfono nelle impostazioni dell'app"
        case .noConnectedPeers:
            return "Connetti almeno un dispositivo prima di trasmettere"
        case .invalidAudioFormat:
            return "Riavvia l'app per ripristinare il formato audio"
        case .invalidPeer:
            return "Connettiti solo a dispositivi fidati nella tua rete"
        }
    }
}