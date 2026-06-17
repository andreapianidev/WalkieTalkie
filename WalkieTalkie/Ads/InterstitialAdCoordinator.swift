//  InterstitialAdCoordinator.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

import Foundation
import Combine
import UIKit
import GoogleMobileAds

@MainActor
final class InterstitialAdCoordinator: NSObject, ObservableObject {
    @Published private(set) var isAdReady = false

    var onDismiss: (() -> Void)?

    private var interstitial: InterstitialAd?
    private var lastShownAt: Date?
    private var shownTodayCount: Int = 0
    private var shownTodayStart: Date = Calendar.current.startOfDay(for: Date())
    private let adUnitID = AdConfig.interstitialAdUnitID

    func loadAd() async {
        guard interstitial == nil else { return }
        do {
            interstitial = try await InterstitialAd.load(
                with: adUnitID,
                request: Request()
            )
            interstitial?.fullScreenContentDelegate = self
            isAdReady = true
        } catch {
            print("[Interstitial] load failed: \(error.localizedDescription)")
            isAdReady = false
        }
    }

    /// Tries to present the interstitial. Returns true if the ad was shown.
    @discardableResult
    func showAdIfAllowed() -> Bool {
        resetDailyCounterIfNeeded()
        guard shownTodayCount < AdConfig.FrequencyCap.interstitialDailyMax else { return false }
        if let lastShownAt,
           Date().timeIntervalSince(lastShownAt) < AdConfig.FrequencyCap.interstitialMinInterval {
            return false
        }
        guard let interstitial, let root = AdRootViewController.current() else {
            Task { await loadAd() }
            return false
        }
        interstitial.present(from: root)
        lastShownAt = Date()
        shownTodayCount += 1
        return true
    }

    private func resetDailyCounterIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if today != shownTodayStart {
            shownTodayStart = today
            shownTodayCount = 0
        }
    }
}

extension InterstitialAdCoordinator: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.interstitial = nil
            self.isAdReady = false
            self.onDismiss?()
            await loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[Interstitial] present failed: \(error.localizedDescription)")
            self.interstitial = nil
            self.isAdReady = false
            await loadAd()
        }
    }
}
