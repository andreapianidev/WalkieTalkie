//creato da Andrea Piani - 12/07/25 - https://www.andreapiani.com - WalkieTalkieApp.swift
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
    @StateObject private var adManager = AdManager.shared
    @StateObject private var iapManager = IAPManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    /// Vero dopo un passaggio in `.background`, consumato al `.active` successivo.
    ///
    /// `.active` da solo arriva anche quando si chiude un alert di sistema
    /// (microfono, rete locale, ATT), il Centro di Controllo o il foglio di
    /// acquisto StoreKit, che passano solo da `.inactive`: l'app-open partiva
    /// a meta' sessione. Si mostra solo al rientro vero da background.
    @State private var returningFromBackground = false

    #if DEBUG
    // Build Debug (simulatore e iPhone di Andrea): all'avvio si sceglie se
    // provare Talky gratis o Pro. La Release di Xcode Cloud non lo vede.
    @State private var showDebugTierAlert = !UserDefaults.standard.bool(forKey: "screenshotMode")
    /// La scelta fatta, da riapplicare se il bootstrap degli acquisti arriva dopo.
    @State private var debugTierIsPro: Bool?
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                if isOnboardingComplete {
                    ContentView()
                } else {
                    OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                }
            }
            // I temi Pro hanno tutti lo sfondo scuro: in chiaro i testi
            // dell'app sarebbero neri su nero.
            .preferredColorScheme(settingsManager.isDarkModeEnabled || themeManager.currentTheme != .defaultTheme ? .dark : .light)
            .tint(themeManager.currentTheme.accentColor)
            .environmentObject(adManager)
            .environmentObject(iapManager)
            .environmentObject(themeManager)
            #if DEBUG
            .alert("DEBUG · Simula tier", isPresented: $showDebugTierAlert) {
                Button("Free") {
                    debugTierIsPro = false
                    iapManager.applyDebugSimulatedTier(isPro: false)
                }
                Button("Pro") {
                    debugTierIsPro = true
                    iapManager.applyDebugSimulatedTier(isPro: true)
                }
            } message: {
                Text("Solo build Debug: scegli se provare Talky gratis o Pro in questa sessione.")
            }
            #endif
            .task {
                // Ascolto dal vivo: 5 minuti gratis al giorno; senza limite, con
                // SCAN e schermo spento, con Pro o con il pass di 24 ore.
                // Pro, segnalazioni e Push to Talk delle stanze partono in
                // AppDelegate: questa .task non gira se iOS lancia Talky in
                // background per una notifica pushtotalk.
                // IAP bootstrap deve precedere AdManager: i guard !isProUser dipendono dallo stato Pro.
                await iapManager.bootstrap()
                #if DEBUG
                // Se la scelta Free/Pro e' arrivata prima che gli acquisti
                // fossero letti, la si rimette: il bootstrap non deve annullarla.
                if let isPro = debugTierIsPro { iapManager.applyDebugSimulatedTier(isPro: isPro) }
                #endif
                #if DEBUG && targetEnvironment(simulator)
                // `-screenshotMode YES`: schermate per lo Store e il README,
                // con Talky Pro attivo, senza pubblicita' di prova e senza il
                // prompt ATT. Esiste solo nelle build Debug sul simulatore.
                if UserDefaults.standard.bool(forKey: "screenshotMode") {
                    iapManager.applyDebugSimulatedTier(isPro: true)
                    // `screenshotOpen`: un collegamento talky:// da aprire
                    // all'avvio, come se arrivasse da un widget.
                    if let link = UserDefaults.standard.string(forKey: "screenshotOpen"), let url = URL(string: link) {
                        LiveActivityDeepLink.handle(url)
                    }
                    // `screenshotStation`: la stazione da far suonare in modalita' radio.
                    let id = UserDefaults.standard.integer(forKey: "screenshotStation")
                    if id > 0, let station = RadioManager.shared.radioStations.first(where: { $0.id == id }) {
                        RadioManager.shared.playStation(station)
                    }
                    return
                }
                #endif
                // Dopo il bootstrap IAP e non prima: `registerSession` deve poter
                // leggere lo stato Pro aggiornato, altrimenti alla seconda
                // sessione un abbonato si vedrebbe proporre l'abbonamento.
                // Solo a onboarding concluso: il paywall non va messo davanti a
                // chi non ha ancora finito di configurare l'app.
                // Prima del bootstrap annunci e non dopo: se in questa sessione
                // tocca al paywall, l'app-open va spento prima che possa partire.
                // Il paywall stesso aspetta che consenso e ATT siano chiusi.
                if isOnboardingComplete {
                    PaywallTriggerManager.shared.registerSession()
                }
                await adManager.bootstrap()
                // Cold start app-open ad after consent + first UI frame.
                // Delayed: the user may already be interacting with the UI, so
                // we add the same idle guard as the resume path to avoid
                // accidental taps inflating the CTR.
                if isOnboardingComplete {
                    adManager.showAppOpenIfAllowed(afterDelay: true)
                }
            }
            .onOpenURL { url in
                // Live Activity (iOS 16.x fallback) deep links: talky://radio/<action>.
                LiveActivityDeepLink.handle(url)
            }
            .onReceive(iapManager.$isProUser) { _ in
                // Comprato Pro (o scaduto): l'ascolto fermo per i minuti finiti riparte.
                if #available(iOS 16.0, *) { LiveRadio.shared.entitlementsChanged() }
                // E sulle stazioni dei widget cambiano i lucchetti.
                RadioManager.shared.publishToWidgets()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background {
                    returningFromBackground = true
                    // Senza Pro l'ascolto HF/POC non continua a schermo spento.
                    if #available(iOS 16.0, *) { LiveRadio.shared.suspendForBackground() }
                }
                if newPhase == .active {
                    // Rilegge gli entitlement a ogni rientro in primo piano.
                    // `Transaction.updates` copre acquisti e rimborsi, ma non la
                    // scadenza naturale di un abbonamento: se scade mentre l'app
                    // è in background, senza questo controllo l'utente resterebbe
                    // Pro fino al riavvio — e chi ha disdetto continuerebbe a non
                    // vedere pubblicità.
                    Task { await iapManager.updateEntitlements() }
                    // Un giorno nuovo rimette a disposizione i minuti gratis.
                    if #available(iOS 16.0, *) { LiveRadio.shared.entitlementsChanged() }
                }
                if newPhase == .active {
                    // Riprova il bootstrap se al lancio non e' andato a buon fine.
                    //
                    // `AdManager.bootstrap()` esce con `guard consent.canRequestAds`:
                    // se UMP fallisce — rete assente o ballerina all'avvio, che su
                    // un walkie-talkie usato all'aperto non e' un caso di scuola —
                    // l'SDK non parte mai, `isInitialized` resta false e la sessione
                    // intera non mostra nessun annuncio, banner compreso. Non c'era
                    // nessun ritentativo: bastava un avvio sfortunato per perdere
                    // tutto il resto della sessione.
                    // Mai sopra un paywall aperto: il modulo di consenso gli
                    // finirebbe davanti. Un bootstrap gia' in corso non riparte,
                    // lo gestisce `AdManager.bootstrap()`.
                    if adManager.canRetryBootstrap && !adManager.isPaywallVisible {
                        Task { await adManager.bootstrap() }
                    }
                    // Un annuncio tenuto in cache scade dopo 55 minuti: al
                    // rientro lo si rimpiazza, cosi' il prossimo trigger lo
                    // trova pronto.
                    adManager.preloadFullScreenAds()
                    // Only re-show when truly coming back from background.
                    if returningFromBackground {
                        returningFromBackground = false
                        if #available(iOS 16.0, *) { LiveRadio.shared.resumeFromBackground() }
                        if isOnboardingComplete {
                            adManager.showAppOpenIfAllowed(afterDelay: true)
                        }
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

        if #available(iOS 16.0, *) {
            LiveRadio.shared.proGate = { LivePassManager.shared.hasLiveExtras }
            // Segnalazioni dei canali POC: server e motivo, mai nomi di persone.
            LiveRadio.shared.onReport = { server, reason in
                Analytics.logEvent("mumble_report", parameters: ["server": server, "reason": reason])
            }
            // Push to Talk delle stanze: al lancio e non in una vista, anche
            // quando iOS rilancia Talky in background per una notifica, perche'
            // il sistema consegni la voce solo a un gestore gia' creato.
            RoomPushToTalk.shared.start()
        }

        // Anche qui e non in una vista: il PTT dal Watch puo' svegliare
        // Talky in background, prima che esista una scena.
        WristLink.shared.start()

        return true
    }

    // Gestisce le notifiche quando l'app è in primo piano
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Mostra la notifica anche quando l'app è in primo piano
        completionHandler([.banner, .list, .sound, .badge])
    }

    // Gestisce il tap sulle notifiche
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Gestisci l'azione quando l'utente tocca la notifica
        completionHandler()
    }
}
