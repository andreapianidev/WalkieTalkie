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
        static let hasSeenFirstRunCoach = "hasSeenFirstRunCoach"
        static let isLiveActivitiesEnabled = "isLiveActivitiesEnabled"
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

    @Published var hasSeenFirstRunCoach: Bool {
        didSet {
            userDefaults.set(hasSeenFirstRunCoach, forKey: Keys.hasSeenFirstRunCoach)
        }
    }

    @Published var isLiveActivitiesEnabled: Bool {
        didSet {
            userDefaults.set(isLiveActivitiesEnabled, forKey: Keys.isLiveActivitiesEnabled)
            firebaseManager.trackSettingsChange(setting: "liveActivities", value: "\(isLiveActivitiesEnabled)")
            if !isLiveActivitiesEnabled, #available(iOS 16.2, *) {
                Task { @MainActor in
                    LiveActivityManager.shared.endAll()
                }
            }
        }
    }

    // MARK: - Initialization
    private init() {
        // Carica le impostazioni salvate o usa i valori di default
        // Audio simulato (rumore bianco + effetti frequenza) OFF di default: è un effetto
        // ambientale decorativo, non comunicazione reale. Acceso di serie faceva percepire
        // l'app come "fake" (recensioni App Store). Chi lo vuole lo attiva dalle Impostazioni.
        self.isBackgroundAudioEnabled = userDefaults.object(forKey: Keys.isBackgroundAudioEnabled) as? Bool ?? false
        self.backgroundVolume = userDefaults.object(forKey: Keys.backgroundVolume) as? Float ?? 0.15
        self.isHapticFeedbackEnabled = userDefaults.object(forKey: Keys.isHapticFeedbackEnabled) as? Bool ?? true
        self.isAutoConnectEnabled = userDefaults.object(forKey: Keys.isAutoConnectEnabled) as? Bool ?? false
        self.selectedFrequency = userDefaults.object(forKey: Keys.selectedFrequency) as? String ?? "146.520"
        self.isVoiceActivationEnabled = userDefaults.object(forKey: Keys.isVoiceActivationEnabled) as? Bool ?? false
        self.voiceActivationThreshold = userDefaults.object(forKey: Keys.voiceActivationThreshold) as? Float ?? 0.3
        self.isLowPowerModeEnabled = userDefaults.object(forKey: Keys.isLowPowerModeEnabled) as? Bool ?? false
        self.isDarkModeEnabled = userDefaults.object(forKey: Keys.isDarkModeEnabled) as? Bool ?? false
        self.hasSeenFirstRunCoach = userDefaults.object(forKey: Keys.hasSeenFirstRunCoach) as? Bool ?? false
        self.isLiveActivitiesEnabled = userDefaults.object(forKey: Keys.isLiveActivitiesEnabled) as? Bool ?? true

        // Debug print dopo l'inizializzazione completa
        print("⚙️ SettingsManager: isHapticFeedbackEnabled inizializzato a \(isHapticFeedbackEnabled)")
    }
    
    // MARK: - Methods
    
    /// Resetta tutte le impostazioni ai valori di default
    func resetToDefaults() {
        isBackgroundAudioEnabled = false
        backgroundVolume = 0.15
        isHapticFeedbackEnabled = true
        isAutoConnectEnabled = false
        selectedFrequency = "146.520"
        isVoiceActivationEnabled = false
        voiceActivationThreshold = 0.3
        isLowPowerModeEnabled = false
        isDarkModeEnabled = false
        isLiveActivitiesEnabled = true
    }
    
    /// Sincronizza le impostazioni con UserDefaults
    func synchronize() {
        userDefaults.synchronize()
    }
}