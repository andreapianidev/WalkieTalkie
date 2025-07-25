//creato da Andrea Piani - Immaginet Srl - 13/01/25 - https://www.andreapiani.com - SettingsManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 13/01/25.
//

import Foundation
import Combine

/// Gestisce la persistenza delle impostazioni dell'app usando UserDefaults
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    private let firebaseManager = FirebaseManager.shared
    
    // MARK: - Settings Keys
    private enum Keys {
        static let isBackgroundAudioEnabled = "isBackgroundAudioEnabled"
        static let backgroundVolume = "backgroundVolume"
        static let isHapticFeedbackEnabled = "isHapticFeedbackEnabled"
        static let isAutoConnectEnabled = "isAutoConnectEnabled"
        static let selectedFrequency = "selectedFrequency"
        static let isVoiceActivationEnabled = "isVoiceActivationEnabled"
        static let voiceActivationThreshold = "voiceActivationThreshold"
        static let isLowPowerModeEnabled = "isLowPowerModeEnabled"
        static let isDarkModeEnabled = "isDarkModeEnabled"
    }
    
    // MARK: - Published Properties
    @Published var isBackgroundAudioEnabled: Bool {
        didSet {
            userDefaults.set(isBackgroundAudioEnabled, forKey: Keys.isBackgroundAudioEnabled)
            firebaseManager.trackSettingsChange(setting: "backgroundAudio", value: "\(isBackgroundAudioEnabled)")
        }
    }
    
    @Published var backgroundVolume: Float {
        didSet {
            userDefaults.set(backgroundVolume, forKey: Keys.backgroundVolume)
            firebaseManager.trackSettingsChange(setting: "backgroundVolume", value: "\(backgroundVolume)")
        }
    }
    
    @Published var isHapticFeedbackEnabled: Bool {
        didSet {
            userDefaults.set(isHapticFeedbackEnabled, forKey: Keys.isHapticFeedbackEnabled)
            firebaseManager.trackSettingsChange(setting: "hapticFeedback", value: "\(isHapticFeedbackEnabled)")
        }
    }
    
    @Published var isAutoConnectEnabled: Bool {
        didSet {
            userDefaults.set(isAutoConnectEnabled, forKey: Keys.isAutoConnectEnabled)
        }
    }
    
    @Published var selectedFrequency: String {
        didSet {
            userDefaults.set(selectedFrequency, forKey: Keys.selectedFrequency)
            firebaseManager.trackFrequencyChange(frequency: selectedFrequency)
        }
    }
    
    @Published var isVoiceActivationEnabled: Bool {
        didSet {
            userDefaults.set(isVoiceActivationEnabled, forKey: Keys.isVoiceActivationEnabled)
        }
    }
    
    @Published var voiceActivationThreshold: Float {
        didSet {
            userDefaults.set(voiceActivationThreshold, forKey: Keys.voiceActivationThreshold)
        }
    }
    
    @Published var isLowPowerModeEnabled: Bool {
        didSet {
            userDefaults.set(isLowPowerModeEnabled, forKey: Keys.isLowPowerModeEnabled)
        }
    }
    
    @Published var isDarkModeEnabled: Bool {
        didSet {
            userDefaults.set(isDarkModeEnabled, forKey: Keys.isDarkModeEnabled)
            firebaseManager.trackSettingsChange(setting: "darkMode", value: "\(isDarkModeEnabled)")
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Carica le impostazioni salvate o usa i valori di default
        self.isBackgroundAudioEnabled = userDefaults.object(forKey: Keys.isBackgroundAudioEnabled) as? Bool ?? true
        self.backgroundVolume = userDefaults.object(forKey: Keys.backgroundVolume) as? Float ?? 0.15
        self.isHapticFeedbackEnabled = userDefaults.object(forKey: Keys.isHapticFeedbackEnabled) as? Bool ?? true
        self.isAutoConnectEnabled = userDefaults.object(forKey: Keys.isAutoConnectEnabled) as? Bool ?? false
        self.selectedFrequency = userDefaults.object(forKey: Keys.selectedFrequency) as? String ?? "146.520"
        self.isVoiceActivationEnabled = userDefaults.object(forKey: Keys.isVoiceActivationEnabled) as? Bool ?? false
        self.voiceActivationThreshold = userDefaults.object(forKey: Keys.voiceActivationThreshold) as? Float ?? 0.3
        self.isLowPowerModeEnabled = userDefaults.object(forKey: Keys.isLowPowerModeEnabled) as? Bool ?? false
        self.isDarkModeEnabled = userDefaults.object(forKey: Keys.isDarkModeEnabled) as? Bool ?? false
        
        // Debug print dopo l'inizializzazione completa
        print("⚙️ SettingsManager: isHapticFeedbackEnabled inizializzato a \(isHapticFeedbackEnabled)")
    }
    
    // MARK: - Methods
    
    /// Resetta tutte le impostazioni ai valori di default
    func resetToDefaults() {
        isBackgroundAudioEnabled = true
        backgroundVolume = 0.15
        isHapticFeedbackEnabled = true
        isAutoConnectEnabled = false
        selectedFrequency = "146.520"
        isVoiceActivationEnabled = false
        voiceActivationThreshold = 0.3
        isLowPowerModeEnabled = false
        isDarkModeEnabled = false
    }
    
    /// Sincronizza le impostazioni con UserDefaults
    func synchronize() {
        userDefaults.synchronize()
    }
}