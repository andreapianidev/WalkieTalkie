//  AdManager.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani

import Foundation
import Combine
import SwiftUI
import GoogleMobileAds
import FirebaseAnalytics

@MainActor
final class AdManager: ObservableObject {
    static let shared = AdManager()

    @Published var isInitialized = false
    @Published var removeAdsUntil: Date?
    @Published var showRewardedPill = false

    let consent = ConsentManager.shared
    let appOpen = AppOpenAdManager()
    let interstitial = InterstitialAdCoordinator()
    let rewarded = RewardedAdCoordinator()
    // Native station ad RIMOSSO: in 14 giorni ha reso $0.00 con 9 impression
    // (show rate 25%) sprecando ~230 richieste/settimana che abbassavano il
    // match rate dell'account. Meno superficie pubblicitaria = meno recensioni
    // "troppa pubblicità". I file NativeAdCoordinator/NativeAdCardView restano
    // per un eventuale placement futuro.

    /// Bridge key for the rewarded "remove ads for 1h" grant. Persisted so the
    /// reward survives an app relaunch within its validity window.
    private static let removeAdsUntilKey = "fastboot_removeAdsUntil"

    private init() {
        interstitial.onDismiss = { [weak self] in
            guard let self else { return }
            guard !IAPManager.shared.isProUser, !self.adsRemoved else { return }
            self.showRewardedPill = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                self.showRewardedPill = false
            }
        }
        appOpen.shouldPresent = { [weak self] in self?.appOpenAllowedNow ?? false }
        // Restore a previously granted remove-ads window. Drop it if already expired.
        let ts = UserDefaults.standard.double(forKey: Self.removeAdsUntilKey)
        if ts > 0 {
            let stored = Date(timeIntervalSince1970: ts)
            if stored > Date() {
                removeAdsUntil = stored
            } else {
                UserDefaults.standard.removeObject(forKey: Self.removeAdsUntilKey)
            }
        }
    }

    var adsRemoved: Bool {
        if let removeAdsUntil, removeAdsUntil > Date() { return true }
        return false
    }

    var removeAdsRemaining: TimeInterval? {
        guard let removeAdsUntil, removeAdsUntil > Date() else { return nil }
        return removeAdsUntil.timeIntervalSinceNow
    }

    /// Full bootstrap. Order is mandatory for Apple review + AdMob eCPM:
    ///   1. UMP consent flow (GDPR / EEA users see the consent form)
    ///   2. ATT prompt (only after UMP has resolved and UI is active)
    ///   3. GoogleMobileAds SDK start (so Google sees the consent + IDFA signal)
    ///   4. Preload of all ad formats
    /// Tentativi di bootstrap gia' spesi. `WalkieTalkieApp` ritenta a ogni
    /// rientro in foreground finche' `isInitialized` e' false; il tetto evita
    /// che un utente che ha legittimamente negato il consenso si porti dietro
    /// una chiamata di rete a ogni foreground per tutta la sessione.
    private var bootstrapAttempts = 0
    private static let maxBootstrapAttempts = 3

    var canRetryBootstrap: Bool {
        !isInitialized && bootstrapAttempts < Self.maxBootstrapAttempts
    }

    /// Il bootstrap in corso, se ce n'e' uno.
    ///
    /// Senza, due chiamate sovrapposte facevano due giri completi di consenso.
    /// Succedeva a ogni avvio in cui compariva il prompt ATT: chiudere l'alert
    /// rimette la scena in `.active`, `WalkieTalkieApp` vede `isInitialized`
    /// ancora false (lo diventa solo dopo l'ATT) e rilancia il bootstrap, cioe'
    /// una seconda richiesta UMP e un secondo `loadAndPresentIfRequired` mentre
    /// il primo giro non era ancora finito.
    private var bootstrapTask: Task<Void, Never>?

    /// Vero quando consenso UMP e ATT sono entrambi chiusi per questa esecuzione,
    /// qualunque sia stato l'esito (accettato, negato, errore di rete).
    ///
    /// Il paywall aspetta questo segnale: presentato mentre il modulo UMP o
    /// l'alert ATT sono a schermo, fallisce senza lasciare traccia.
    private(set) var isPrivacyFlowClosed = false
    private var privacyFlowWaiters: [CheckedContinuation<Void, Never>] = []

    /// Spento per l'intera sessione quando in questa sessione deve comparire il
    /// paywall. Due schermate modali all'avvio non si aprono insieme: vince chi
    /// arriva prima, e l'altra si perde. Fra un annuncio da pochi centesimi e il
    /// paywall si sceglie il paywall.
    var appOpenBlockedThisSession = false

    func bootstrap() async {
        if let bootstrapTask {
            PaywallFlowLog.log("bootstrap annunci gia' in corso: non si richiede di nuovo il consenso")
            await bootstrapTask.value
            return
        }
        guard !isInitialized else { return }
        bootstrapAttempts += 1

        let task = Task { @MainActor in await self.runBootstrap() }
        bootstrapTask = task
        await task.value
        bootstrapTask = nil
    }

    private func runBootstrap() async {
        // 1. UMP
        await consent.gatherConsent()
        PaywallFlowLog.log("consenso chiuso (canRequestAds=\(consent.canRequestAds))")
        guard consent.canRequestAds else {
            // Senza consenso l'ATT non si chiede: il flusso privacy e' chiuso qui.
            PaywallFlowLog.log("ATT chiusa (non richiesta: consenso assente)")
            markPrivacyFlowClosed()
            return
        }

        // 2. ATT
        await consent.requestATTIfNeeded()
        PaywallFlowLog.log("ATT chiusa (stato=\(consent.trackingStatusDescription))")
        markPrivacyFlowClosed()

        #if DEBUG
        // Register test devices BEFORE starting the SDK so every request is
        // returned as a test ad (no risk of accidental real-ad clicks during
        // development). Simulators are auto-detected by Google but physical
        // test devices must be listed explicitly.
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "B07ED5E0-8565-45F8-95AD-3F0C990972F2" // iPhone Andrea
        ]
        #endif

        // 3. SDK init
        MobileAds.shared.start { _ in }
        isInitialized = true

        // 4. Preload
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.appOpen.loadAd() }
            group.addTask { await self.interstitial.loadAd() }
            group.addTask { await self.rewarded.loadAd() }
        }
    }

    /// Ritorna quando consenso e ATT sono chiusi. Subito, se lo sono gia'.
    func waitUntilPrivacyFlowClosed() async {
        if isPrivacyFlowClosed { return }
        await withCheckedContinuation { privacyFlowWaiters.append($0) }
    }

    private func markPrivacyFlowClosed() {
        guard !isPrivacyFlowClosed else { return }
        isPrivacyFlowClosed = true
        let waiters = privacyFlowWaiters
        privacyFlowWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    // MARK: - Convenience

    func showInterstitialIfAllowed() {
        guard !IAPManager.shared.isProUser else { return }
        guard !adsRemoved else { return }
        // Mai interrompere l'audio della radio con un interstitial: gli utenti
        // percepivano la pubblicità come "invadente" perché spezzava l'ascolto
        // (recensione App Store "penetrantester Werbung"). Gate centrale così
        // copre ogni call site (cambio stazione/canale, idle, ecc.).
        guard !RadioManager.shared.isPlaying else { return }
        interstitial.showAdIfAllowed()
    }

    /// Vero mentre il paywall è a schermo o sta per aprirsi.
    ///
    /// Un app-open che atterra sopra il paywall — o un attimo prima — non solo
    /// copre la schermata che deve vendere, ma mette un annuncio a tutto schermo
    /// esattamente nel momento in cui si sta chiedendo all'utente di pagare per
    /// non vederne più. Costa la vendita e la stella.
    var isPaywallVisible: Bool = false

    func showAppOpenIfAllowed(afterDelay: Bool = false) {
        guard appOpenAllowedNow else { return }
        appOpen.showAdIfAvailable(afterDelay: afterDelay)
    }

    /// Tutte le condizioni per un app-open, valutate ADESSO.
    ///
    /// Ricontrollate anche allo scadere del ritardo di presentazione: nel
    /// frattempo il paywall puo' essersi aperto, e prima nessuno lo verificava.
    var appOpenAllowedNow: Bool {
        // Niente richieste prima che consenso, ATT e SDK siano pronti.
        guard isInitialized else { return false }
        guard !IAPManager.shared.isProUser else { return false }
        guard !adsRemoved else { return false }
        // Idem per l'app-open al rientro in foreground: se la radio sta suonando
        // (anche da background) non sovrapporre un annuncio a schermo intero.
        guard !RadioManager.shared.isPlaying else { return false }
        guard !isPaywallVisible else { return false }
        if appOpenBlockedThisSession {
            PaywallFlowLog.log("app-open saltato: in questa sessione tocca al paywall")
            return false
        }
        return true
    }

    func grantRemoveAdsReward() {
        let duration = AdConfig.FrequencyCap.removeAdsRewardDuration
        let until = Date().addingTimeInterval(duration)
        removeAdsUntil = until
        UserDefaults.standard.set(until.timeIntervalSince1970, forKey: Self.removeAdsUntilKey)
    }

    /// Single entry point used by every rewarded CTA in the app (paywall, settings,
    /// explore, …). Centralises the present → grant → haptic flow and emits a
    /// measurable funnel on Firebase: `rewarded_cta_tapped` on tap and
    /// `rewarded_reward_earned` only when the user actually completes the video.
    /// `source` is the surface that drove the tap, so we can see which placement
    /// converts on AdMob/Firebase instead of a single anonymous number.
    func presentRewardedRemoveAds(source: String) {
        Analytics.logEvent("rewarded_cta_tapped", parameters: ["source": source])
        rewarded.showAd { [weak self] in
            guard let self else { return }
            self.grantRemoveAdsReward()
            HapticManager.shared.success()
            Analytics.logEvent("rewarded_reward_earned", parameters: ["source": source])
        }
    }
}
