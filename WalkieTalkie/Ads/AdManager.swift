//  AdManager.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

import Foundation
import Combine
import SwiftUI
import GoogleMobileAds

@MainActor
final class AdManager: ObservableObject {
    static let shared = AdManager()

    @Published var isInitialized = false
    @Published var removeAdsUntil: Date?

    let consent = ConsentManager.shared
    let appOpen = AppOpenAdManager()
    let interstitial = InterstitialAdCoordinator()
    let rewarded = RewardedAdCoordinator()

    private init() {}

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

    // MARK: - Convenience

    func showInterstitialIfAllowed() {
        guard !IAPManager.shared.isProUser else { return }
        guard !adsRemoved else { return }
        interstitial.showAdIfAllowed()
    }

    func showAppOpenIfAllowed() {
        guard !IAPManager.shared.isProUser else { return }
        guard !adsRemoved else { return }
        appOpen.showAdIfAvailable()
    }

    func grantRemoveAdsReward() {
        let duration = AdConfig.FrequencyCap.removeAdsRewardDuration
        removeAdsUntil = Date().addingTimeInterval(duration)
    }
}
