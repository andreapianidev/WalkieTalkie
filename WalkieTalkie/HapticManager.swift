//creato da Andrea Piani - Immaginet Srl - 15/01/25 - https://www.andreapiani.com - HapticManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 15/01/25.
//

import Foundation
import UIKit
import Combine

/// Gestisce il feedback aptico dell'app
class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Generatori di feedback aptico
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        setupGenerators()
        observeSettings()
        checkHapticSupport()
    }
    
    private func checkHapticSupport() {
        // Verifica se il dispositivo supporta il feedback aptico
        #if targetEnvironment(simulator)
        print("⚠️ HapticManager: Il feedback aptico non è supportato nel simulatore")
        #else
        print("✅ HapticManager: Feedback aptico disponibile su dispositivo fisico")
        #endif
    }
    
    private func setupGenerators() {
        // Pre-prepara i generatori per ridurre latenza
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    private func observeSettings() {
        // Osserva i cambiamenti nelle impostazioni haptic
        settingsManager.$isHapticFeedbackEnabled
            .sink { [weak self] _ in
                self?.setupGenerators()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Feedback leggero per interazioni semplici (tap su pulsanti)
    func lightTap() {
        guard settingsManager.isHapticFeedbackEnabled else { 
            print("🔇 HapticManager: Feedback aptico disabilitato nelle impostazioni")
            return 
        }
        print("📳 HapticManager: Eseguendo lightTap")
        lightImpact.impactOccurred()
    }
    
    /// Feedback medio per azioni importanti (cambio frequenza, toggle)
    func mediumTap() {
        guard settingsManager.isHapticFeedbackEnabled else { 
            print("🔇 HapticManager: Feedback aptico disabilitato nelle impostazioni")
            return 
        }
        print("📳 HapticManager: Eseguendo mediumTap")
        mediumImpact.impactOccurred()
    }
    
    /// Feedback pesante per azioni critiche (inizio/fine trasmissione)
    func heavyTap() {
        guard settingsManager.isHapticFeedbackEnabled else { return }
        heavyImpact.impactOccurred()
    }
    
    /// Feedback di selezione per navigazione (cambio tab, selezione elementi)
    func selectionChanged() {
        guard settingsManager.isHapticFeedbackEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    /// Feedback di successo
    func success() {
        guard settingsManager.isHapticFeedbackEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Feedback di errore
    func error() {
        guard settingsManager.isHapticFeedbackEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
    }
    
    /// Feedback di avviso
    func warning() {
        guard settingsManager.isHapticFeedbackEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Feedback per inizio trasmissione
    func transmissionStarted() {
        guard settingsManager.isHapticFeedbackEnabled else { return }
        heavyTap()
        // Doppio tap per enfatizzare l'inizio trasmissione
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.lightTap()
        }
    }
    
    /// Feedback per fine trasmissione
    func transmissionEnded() {
        guard settingsManager.isHapticFeedbackEnabled else { return }
        mediumTap()
    }
    
    /// Feedback per connessione stabilita
    func connectionEstablished() {
        guard settingsManager.isHapticFeedbackEnabled else { return }
        success()
    }
    
    /// Feedback per connessione persa
    func connectionLost() {
        guard settingsManager.isHapticFeedbackEnabled else { return }
        warning()
    }
}