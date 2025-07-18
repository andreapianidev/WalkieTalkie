//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - WalkieTalkieApp.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import SwiftUI
import UserNotifications
import BackgroundTasks

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
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
    
    // MARK: - App Lifecycle
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Richiedi tempo extra per completare le operazioni in background
        backgroundTask = application.beginBackgroundTask(withName: "WalkieTalkie Background Task") { [weak self] in
            // Chiamato quando il sistema sta per terminare il task
            self?.endBackgroundTask()
        }
        
        // Notifica ai manager che l'app è in background
        AudioManager.shared.handleAppDidEnterBackground()
        
        // Trova il MultipeerManager dall'ambiente SwiftUI
        if let windowScene = application.connectedScenes.first as? UIWindowScene,
           let contentView = windowScene.windows.first?.rootViewController?.view {
            // Accedi al MultipeerManager tramite la gerarchia delle view
            // Nota: Questo potrebbe richiedere un approccio diverso basato sulla struttura dell'app
            NotificationCenter.default.post(name: NSNotification.Name("AppDidEnterBackground"), object: nil)
        }
        
        
        // Avvia un timer per monitorare il tempo rimanente in background
        DispatchQueue.global(qos: .background).async { [weak self] in
            // Il sistema fornisce circa 30 secondi di tempo extra, ma può variare
            while application.backgroundTimeRemaining > 5 {
                Thread.sleep(forTimeInterval: 1)
            }
            
            // Termina il task quando il tempo sta per scadere
            self?.endBackgroundTask()
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Termina il background task se ancora attivo
        endBackgroundTask()
        
        // Notifica ai manager che l'app sta tornando in foreground
        AudioManager.shared.handleAppWillEnterForeground()
        
        // Notifica il MultipeerManager
        NotificationCenter.default.post(name: NSNotification.Name("AppWillEnterForeground"), object: nil)
        
    }
    
    // MARK: - Background Task Management
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
