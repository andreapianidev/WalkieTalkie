//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - SleepTimerManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import Combine

/// Durate disponibili per lo sleep timer della radio.
enum SleepTimerDuration: Int, CaseIterable, Identifiable {
    case fiveMin = 5
    case tenMin = 10
    case fifteenMin = 15
    case thirtyMin = 30
    case sixtyMin = 60

    var id: Int { rawValue }
    var displayName: String { "\(rawValue) min" }
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }
}

/// Gestore dello sleep timer della radio.
/// Feature Pro-locked: controlla `UserDefaults.standard.bool(forKey: "fastboot_isProUser")`.
/// Lo stato non è persistente (timer attivo solo nella sessione corrente).
@MainActor
final class SleepTimerManager: ObservableObject {
    static let shared = SleepTimerManager()

    @Published var isActive: Bool = false
    @Published var remainingSeconds: TimeInterval = 0
    @Published var selectedDuration: SleepTimerDuration? = nil

    private var timer: Timer?
    private let logger = Logger.shared

    /// Verifica lo stato Pro tramite il bridge UserDefaults.
    var isProUser: Bool {
        UserDefaults.standard.bool(forKey: "fastboot_isProUser")
    }

    private init() {}

    /// Avvia lo sleep timer con la durata indicata.
    /// - Returns: `false` se l'utente non è Pro, `true` se il timer è stato avviato.
    @discardableResult
    func start(duration: SleepTimerDuration) -> Bool {
        guard isProUser else {
            logger.logInfo("SleepTimer: avvio bloccato, utente non Pro")
            return false
        }

        // Annulla un eventuale timer precedente prima di avviarne uno nuovo.
        cancel()

        selectedDuration = duration
        remainingSeconds = duration.seconds
        isActive = true

        logger.logInfo("SleepTimer: avviato per \(duration.displayName)")

        // Timer che decrementa il countdown ogni secondo.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        return true
    }

    /// Annulla lo sleep timer e resetta lo stato.
    func cancel() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingSeconds = 0
        selectedDuration = nil
        logger.logInfo("SleepTimer: annullato")
    }

    /// Decremento del countdown; quando arriva a 0 ferma la radio.
    private func tick() {
        guard isActive else { return }
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            logger.logInfo("SleepTimer: scaduto, fermo la radio")
            RadioManager.shared.stopRadio()
            cancel()
        }
    }

    /// Formatta i secondi rimanenti come "MM:SS".
    var formattedRemaining: String {
        let total = max(0, Int(remainingSeconds))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
