//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - FirebaseManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import Foundation
import Combine
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import os.log

/// Gestisce l'integrazione con Firebase Analytics e Crashlytics
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private let logger = Logger.shared
    
    private init() {
        logger.logInfo("FirebaseManager inizializzato")
    }
    
    // MARK: - Analytics Events
    
    /// Traccia l'avvio dell'app
    func trackAppLaunch() {
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
        logger.logInfo("Analytics: App launch tracciato")
    }
    
    /// Traccia quando un utente si connette a un dispositivo
    func trackDeviceConnection(deviceName: String) {
        Analytics.logEvent("device_connection", parameters: [
            "device_name": deviceName,
            "timestamp": Date().timeIntervalSince1970
        ])
        logger.logInfo("Analytics: Connessione dispositivo tracciata - \(deviceName)")
    }
    
    /// Traccia quando un utente si disconnette da un dispositivo
    func trackDeviceDisconnection(deviceName: String) {
        Analytics.logEvent("device_disconnection", parameters: [
            "device_name": deviceName,
            "timestamp": Date().timeIntervalSince1970
        ])
        logger.logInfo("Analytics: Disconnessione dispositivo tracciata - \(deviceName)")
    }
    
    /// Traccia l'uso del walkie talkie
    func trackWalkieTalkieUsage(duration: TimeInterval) {
        Analytics.logEvent("walkie_talkie_usage", parameters: [
            "duration_seconds": duration,
            "timestamp": Date().timeIntervalSince1970
        ])
        logger.logInfo("Analytics: Uso walkie talkie tracciato - \(duration)s")
    }
    
    /// Traccia il cambio di frequenza
    func trackFrequencyChange(frequency: String) {
        Analytics.logEvent("frequency_change", parameters: [
            "frequency": frequency,
            "timestamp": Date().timeIntervalSince1970
        ])
        logger.logInfo("Analytics: Cambio frequenza tracciato - \(frequency)")
    }
    
    /// Traccia l'uso della modalità radio FM
    func trackRadioUsage(station: String) {
        Analytics.logEvent("radio_usage", parameters: [
            "station": station,
            "timestamp": Date().timeIntervalSince1970
        ])
        logger.logInfo("Analytics: Uso radio tracciato - \(station)")
    }
    
    /// Traccia le modifiche alle impostazioni
    func trackSettingsChange(setting: String, value: Any) {
        Analytics.logEvent("settings_change", parameters: [
            "setting_name": setting,
            "setting_value": "\(value)",
            "timestamp": Date().timeIntervalSince1970
        ])
        logger.logInfo("Analytics: Modifica impostazioni tracciata - \(setting): \(value)")
    }
    
    /// Traccia errori dell'app
    func trackAppError(error: Error, context: String) {
        Analytics.logEvent("app_error", parameters: [
            "error_description": error.localizedDescription,
            "error_context": context,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Registra anche in Crashlytics come errore non fatale
        recordNonFatalError(error, context: context)
        
        logger.logInfo("Analytics: Errore app tracciato - \(context): \(error.localizedDescription)")
    }
    
    // MARK: - Crashlytics
    
    /// Registra un errore non fatale in Crashlytics
    func recordNonFatalError(_ error: Error, context: String) {
        Crashlytics.crashlytics().record(error: error)
        Crashlytics.crashlytics().setCustomValue(context, forKey: "error_context")
        Crashlytics.crashlytics().setCustomValue(Date().timeIntervalSince1970, forKey: "timestamp")
        logger.logError(error, context: "Crashlytics - \(context)")
    }
    
    /// Imposta informazioni utente per Crashlytics
    func setUserInfo(userId: String, deviceName: String) {
        Crashlytics.crashlytics().setUserID(userId)
        Crashlytics.crashlytics().setCustomValue(deviceName, forKey: "device_name")
        Crashlytics.crashlytics().setCustomValue("WalkieTalkie", forKey: "app_name")
        logger.logInfo("Crashlytics: Informazioni utente impostate - \(userId)")
    }
    
    /// Registra un log personalizzato in Crashlytics
    func logCustomMessage(_ message: String) {
        Crashlytics.crashlytics().log(message)
        logger.logInfo("Crashlytics: Log personalizzato - \(message)")
    }
    
    /// Imposta una chiave personalizzata per il debug
    func setCustomKey(_ key: String, value: Any) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        logger.logInfo("Crashlytics: Chiave personalizzata impostata - \(key): \(value)")
    }
    
    // MARK: - User Properties
    
    /// Imposta proprietà utente per Analytics
    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
        logger.logInfo("Analytics: Proprietà utente impostata - \(name): \(value ?? "nil")")
    }
    
    /// Imposta l'ID utente per Analytics
    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
        logger.logInfo("Analytics: ID utente impostato - \(userId ?? "nil")")
    }
}

// MARK: - Analytics Event Names
extension FirebaseManager {
    struct AnalyticsEvents {
        static let deviceConnection = "device_connection"
        static let deviceDisconnection = "device_disconnection"
        static let walkieTalkieUsage = "walkie_talkie_usage"
        static let frequencyChange = "frequency_change"
        static let radioUsage = "radio_usage"
        static let settingsChange = "settings_change"
        static let appError = "app_error"
    }
    
    struct UserProperties {
        static let deviceType = "device_type"
        static let appVersion = "app_version"
        static let preferredLanguage = "preferred_language"
        static let backgroundAudioEnabled = "background_audio_enabled"
        static let hapticFeedbackEnabled = "haptic_feedback_enabled"
    }
}