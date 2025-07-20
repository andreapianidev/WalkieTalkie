//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - NotificationManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import Foundation
import UserNotifications
import UIKit
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notificationsEnabled = false
    @Published var hasPermission = false
    
    private var isTogglingNotifications = false
    private var lastNotificationTime: [String: Date] = [:]
    private let notificationCooldown: TimeInterval = 2.0 // 2 secondi di cooldown
    
    init() {
        checkNotificationSettings()
        loadNotificationPreference()
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Errore richiesta permessi notifiche: \(error.localizedDescription)")
                }
                
                self.hasPermission = granted
                // Non abilitare automaticamente le notifiche, mantieni lo stato corrente
                // L'utente deve abilitarle manualmente dalle impostazioni
                if !granted {
                    self.notificationsEnabled = false
                    self.saveNotificationPreference()
                }
            }
        }
    }
    
    private func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.hasPermission = settings.authorizationStatus == .authorized
                // Se non abbiamo permessi, disabilita le notifiche
                if !(self?.hasPermission ?? false) {
                    self?.notificationsEnabled = false
                    self?.saveNotificationPreference()
                }
            }
        }
    }
    
    // MARK: - Preference Management
    
    func toggleNotifications() {
        // Evita loop infiniti
        guard !isTogglingNotifications else { return }
        isTogglingNotifications = true
        
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isTogglingNotifications = false
            }
        }
        
        if hasPermission {
            // Fai il toggle della proprietà
            notificationsEnabled.toggle()
            saveNotificationPreference()
            
            if notificationsEnabled {
                // Invia notifica di conferma se le notifiche sono state attivate
                sendNotificationActivatedConfirmation()
            } else {
                // Rimuovi tutte le notifiche pending quando disabilitate
                clearAllPendingNotifications()
            }
        } else {
            // Se non abbiamo permessi, richiedili
            requestNotificationPermission()
            // Dopo aver richiesto i permessi, se vengono concessi, abilita le notifiche
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.hasPermission {
                    self.notificationsEnabled = true
                    self.saveNotificationPreference()
                    self.sendNotificationActivatedConfirmation()
                }
            }
        }
    }
    
    private func saveNotificationPreference() {
        UserDefaults.standard.set(notificationsEnabled, forKey: "notifications_enabled")
    }
    
    private func loadNotificationPreference() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
    }
    
    // MARK: - Helper Methods
    
    private func canSendNotification(type: String) -> Bool {
        let now = Date()
        if let lastTime = lastNotificationTime[type],
           now.timeIntervalSince(lastTime) < notificationCooldown {
            return false
        }
        lastNotificationTime[type] = now
        return true
    }
    
    // MARK: - Notification Sending
    
    func sendDeviceDetectedNotification(deviceName: String) {
        guard notificationsEnabled && hasPermission && canSendNotification(type: "device_detected") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "new_device_detected".localized
        content.body = String(format: "device_detected_message".localized, deviceName)
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "device_detected_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendConnectionEstablishedNotification(deviceName: String) {
        guard notificationsEnabled && hasPermission && canSendNotification(type: "connection_established") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "connection_established".localized
        content.body = String(format: "connected_to_device".localized, deviceName)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "connection_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendConnectionLostNotification(deviceName: String) {
        guard notificationsEnabled && hasPermission && canSendNotification(type: "connection_lost") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "connection_lost".localized
        content.body = String(format: "disconnected_from_device".localized, deviceName)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "disconnection_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendIncomingTransmissionNotification() {
        guard notificationsEnabled && hasPermission && canSendNotification(type: "incoming_transmission") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "incoming_transmission".localized
        content.body = "receiving_audio_message".localized
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "transmission_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendNotificationActivatedConfirmation() {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "notifications_enabled".localized
        content.body = "notifications_activated_message".localized
        content.sound = .default
        
        // Aggiungi un piccolo ritardo per permettere all'utente di vedere la notifica
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "notifications_activated_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Background Notifications
    
    func scheduleBackgroundScanNotification() {
        guard notificationsEnabled && hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "background_scan".localized
        content.body = "scanning_for_devices".localized
        content.sound = nil
        
        // Schedule notification after 30 seconds when app goes to background
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "background_scan",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelBackgroundNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["background_scan"])
    }
    
    private func clearAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        clearBadge()
        // Reset del cooldown quando si disabilitano le notifiche
        lastNotificationTime.removeAll()
    }
    
    // MARK: - Badge Management
    
    func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}