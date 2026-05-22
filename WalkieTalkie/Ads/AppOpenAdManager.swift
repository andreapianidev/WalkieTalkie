//  AppOpenAdManager.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

import Foundation
import Combine
import UIKit
import GoogleMobileAds

@MainActor
final class AppOpenAdManager: NSObject, ObservableObject {
    @Published var isPresenting = false

    private var appOpenAd: AppOpenAd?
    private var loadTime: Date?
    private var isLoading = false
    private let adUnitID = AdConfig.appOpenAdUnitID

    /// Suppress flag set by other components (e.g. while user is transmitting).
    var suppressNextResume: Bool = false

    func loadAd() async {
        guard !isLoading, !isAdAvailable else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            appOpenAd = try await AppOpenAd.load(
                with: adUnitID,
                request: Request()
            )
            appOpenAd?.fullScreenContentDelegate = self
            loadTime = Date()
        } catch {
            print("[AppOpenAd] load failed: \(error.localizedDescription)")
            appOpenAd = nil
        }
    }

    func showAdIfAvailable() {
        guard !isPresenting else { return }
        guard !suppressNextResume else {
            suppressNextResume = false
            return
        }
        guard isAdAvailable, let ad = appOpenAd, let root = AdRootViewController.current() else {
            Task { await loadAd() }
            return
        }
        isPresenting = true
        ad.present(from: root)
    }

    private var isAdAvailable: Bool {
        guard appOpenAd != nil, let loadTime else { return false }
        return Date().timeIntervalSince(loadTime) < AdConfig.FrequencyCap.appOpenMaxAge
    }
}

extension AppOpenAdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.appOpenAd = nil
            self.isPresenting = false
            await loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[AppOpenAd] present failed: \(error.localizedDescription)")
            self.appOpenAd = nil
            self.isPresenting = false
            await loadAd()
        }
    }
}
