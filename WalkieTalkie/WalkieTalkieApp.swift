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
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var adManager = AdManager.shared
    @StateObject private var iapManager = IAPManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false

    #if DEBUG && targetEnvironment(simulator)
    @State private var showDebugTierAlert = true
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                if isOnboardingComplete {
                    ContentView()
                } else {
                    OnboardingView(
                        isOnboardingComplete: $isOnboardingComplete,
                        notificationManager: notificationManager
                    )
                }
            }
            .preferredColorScheme(settingsManager.isDarkModeEnabled ? .dark : .light)
            .tint(themeManager.currentTheme.accentColor)
            .environmentObject(adManager)
            .environmentObject(iapManager)
            .environmentObject(themeManager)
            #if DEBUG && targetEnvironment(simulator)
            .alert("DEBUG · Simula tier", isPresented: $showDebugTierAlert) {
                Button("Free") {
                    iapManager.applyDebugSimulatedTier(isPro: false)
                }
                Button("Pro") {
                    iapManager.applyDebugSimulatedTier(isPro: true)
                }
            } message: {
                Text("Solo simulator/DEBUG: scegli quale versione vuoi simulare per questa sessione.")
            }
            #endif
            .task {
                // IAP bootstrap deve precedere AdManager: i guard !isProUser dipendono dallo stato Pro.
                await iapManager.bootstrap()
                await adManager.bootstrap()
                // Cold start app-open ad after consent + first UI frame.
                if isOnboardingComplete {
                    adManager.showAppOpenIfAllowed()
                }
            }
            .onOpenURL { url in
                // Live Activity (iOS 16.x fallback) deep links: talky://radio/<action>.
                LiveActivityDeepLink.handle(url)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    // Only re-show when truly coming back from background.
                    if isOnboardingComplete {
                        adManager.showAppOpenIfAllowed()
                    }
                }
            }
            .onChange(of: isOnboardingComplete) { completed in
                if completed {
                    FirstTimeEventTracker.shared.fireOnce(FirstTimeEventTracker.Events.onboardingComplete)
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Bootstrap Live Activity observers BEFORE any URL or scene processing.
        // Cold-launch from a talky:// Live Activity button (iOS 16.x fallback)
        // delivers the URL to .onOpenURL right after this delegate method; the
        // observers must already be installed when LiveActivityDeepLink posts.
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.bootstrap()
        }

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
