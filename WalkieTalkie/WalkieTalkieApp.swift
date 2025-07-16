//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - WalkieTalkieApp.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

@main
struct WalkieTalkieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Inizializza Firebase
        FirebaseApp.configure()
        
        // Abilita Analytics
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Configura Crashlytics
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        
        // Configura Firebase Manager e traccia l'avvio dell'app
        let firebaseManager = FirebaseManager.shared
        firebaseManager.trackAppLaunch()
        
        // Imposta proprietà utente di base
        firebaseManager.setUserProperty(UIDevice.current.model, forName: FirebaseManager.UserProperties.deviceType)
        firebaseManager.setUserProperty(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, forName: FirebaseManager.UserProperties.appVersion)
        firebaseManager.setUserProperty(Locale.current.languageCode, forName: FirebaseManager.UserProperties.preferredLanguage)
        
        // Configura il delegate per le notifiche
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Gestisce le notifiche quando l'app è in primo piano
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Mostra la notifica anche quando l'app è in primo piano
        completionHandler([.alert, .sound, .badge])
    }
    
    // Gestisce il tap sulle notifiche
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Gestisci l'azione quando l'utente tocca la notifica
        completionHandler()
    }
}
