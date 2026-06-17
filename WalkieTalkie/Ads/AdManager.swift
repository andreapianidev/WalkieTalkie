//  AdManager.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

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
    let nativeStation = NativeAdCoordinator()

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
    func bootstrap() async {
        // 1. UMP
        await consent.gatherConsent()
        guard consent.canRequestAds else { return }

        // 2. ATT
        await consent.requestATTIfNeeded()

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
        // Native ad is NOT preloaded here on purpose: it is only ever displayed
        // inside the station browser sheet, which most sessions never open. Eager
        // bootstrap preloading produced ~1 request per launch against ~2% display,
        // tanking its show rate. It now loads lazily the first time the sheet
        // appears, via refreshStationNativeAdIfNeeded() (shouldReload returns true
        // when no ad is cached). Same impressions, far fewer wasted requests.
    }

    /// Re-request a native station ad. Call when the station browser opens so the user sees fresh creatives.
    /// Throttled: skips reload if the cached ad is younger than 60s (avoids hammering AdMob on rapid open/close).
    func refreshStationNativeAdIfNeeded() {
        guard !IAPManager.shared.isProUser else { return }
        guard !adsRemoved else { return }
        if nativeStation.shouldReload(minAge: 60) {
            nativeStation.loadAd()
        }
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

    func showAppOpenIfAllowed(afterDelay: Bool = false) {
        guard !IAPManager.shared.isProUser else { return }
        guard !adsRemoved else { return }
        // Idem per l'app-open al rientro in foreground: se la radio sta suonando
        // (anche da background) non sovrapporre un annuncio a schermo intero.
        guard !RadioManager.shared.isPlaying else { return }
        appOpen.showAdIfAvailable(afterDelay: afterDelay)
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
