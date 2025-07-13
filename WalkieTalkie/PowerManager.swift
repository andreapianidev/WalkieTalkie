//creato da Andrea Piani - Immaginet Srl - 15/01/25 - https://www.andreapiani.com - PowerManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 15/01/25.
//

import Foundation
import UIKit
import Combine

/// Gestisce l'ottimizzazione energetica dell'app
class PowerManager: ObservableObject {
    static let shared = PowerManager()
    
    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isLowPowerModeActive = false
    @Published var batteryLevel: Float = 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    
    // Configurazioni per low power mode
    private struct LowPowerConfig {
        static let reducedScanInterval: TimeInterval = 10.0 // Invece di 5.0
        static let reducedHeartbeatInterval: TimeInterval = 30.0 // Invece di 15.0
        static let reducedAudioQuality: Float = 0.6 // Riduce qualità audio
        static let reducedBackgroundVolume: Float = 0.5 // Riduce volume background
        static let disableAnimations = true
        static let reducedNotificationFrequency: TimeInterval = 60.0
    }
    
    private init() {
        setupBatteryMonitoring()
        observeSettings()
        updateLowPowerMode()
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Osserva i cambiamenti della batteria
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        // Osserva il low power mode del sistema
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemLowPowerModeChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        updateBatteryInfo()
    }
    
    private func observeSettings() {
        settingsManager.$isLowPowerModeEnabled
            .sink { [weak self] _ in
                self?.updateLowPowerMode()
            }
            .store(in: &cancellables)
    }
    
    @objc private func batteryLevelChanged() {
        updateBatteryInfo()
    }
    
    @objc private func batteryStateChanged() {
        updateBatteryInfo()
    }
    
    @objc private func systemLowPowerModeChanged() {
        updateLowPowerMode()
    }
    
    private func updateBatteryInfo() {
        DispatchQueue.main.async {
            self.batteryLevel = UIDevice.current.batteryLevel
            self.batteryState = UIDevice.current.batteryState
        }
    }
    
    private func updateLowPowerMode() {
        let shouldActivate = settingsManager.isLowPowerModeEnabled || 
                           ProcessInfo.processInfo.isLowPowerModeEnabled ||
                           batteryLevel < 0.2 // Attiva automaticamente sotto il 20%
        
        DispatchQueue.main.async {
            self.isLowPowerModeActive = shouldActivate
        }
    }
    
    // MARK: - Public Methods
    
    /// Ottiene l'intervallo di scansione ottimizzato
    func getOptimizedScanInterval() -> TimeInterval {
        return isLowPowerModeActive ? LowPowerConfig.reducedScanInterval : 5.0
    }
    
    /// Ottiene l'intervallo di heartbeat ottimizzato
    func getOptimizedHeartbeatInterval() -> TimeInterval {
        return isLowPowerModeActive ? LowPowerConfig.reducedHeartbeatInterval : 15.0
    }
    
    /// Ottiene il fattore di qualità audio ottimizzato
    func getOptimizedAudioQuality() -> Float {
        return isLowPowerModeActive ? LowPowerConfig.reducedAudioQuality : 1.0
    }
    
    /// Ottiene il volume di background ottimizzato
    func getOptimizedBackgroundVolume(_ originalVolume: Float) -> Float {
        return isLowPowerModeActive ? originalVolume * LowPowerConfig.reducedBackgroundVolume : originalVolume
    }
    
    /// Verifica se le animazioni dovrebbero essere disabilitate
    func shouldDisableAnimations() -> Bool {
        return isLowPowerModeActive && LowPowerConfig.disableAnimations
    }
    
    /// Ottiene la frequenza di notifiche ottimizzata
    func getOptimizedNotificationFrequency() -> TimeInterval {
        return isLowPowerModeActive ? LowPowerConfig.reducedNotificationFrequency : 30.0
    }
    
    /// Verifica se dovrebbe ridurre la frequenza di aggiornamento UI
    func shouldReduceUIUpdates() -> Bool {
        return isLowPowerModeActive
    }
    
    /// Ottiene il delay ottimizzato per operazioni non critiche
    func getOptimizedDelay() -> TimeInterval {
        return isLowPowerModeActive ? 2.0 : 0.5
    }
    
    /// Verifica se dovrebbe limitare le operazioni in background
    func shouldLimitBackgroundOperations() -> Bool {
        return isLowPowerModeActive
    }
    
    /// Ottiene informazioni sullo stato energetico
    func getPowerStatus() -> String {
        let batteryPercentage = Int(batteryLevel * 100)
        let stateDescription: String
        
        switch batteryState {
        case .charging:
            stateDescription = "charging".localized
        case .full:
            stateDescription = "full".localized
        case .unplugged:
            stateDescription = "unplugged".localized
        default:
            stateDescription = "unknown".localized
        }
        
        return "\(batteryPercentage)% - \(stateDescription)"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}