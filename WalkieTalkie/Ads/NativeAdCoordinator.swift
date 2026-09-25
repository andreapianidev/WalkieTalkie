//  NativeAdCoordinator.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani

import Foundation
import Combine
import UIKit
import GoogleMobileAds

@MainActor
final class NativeAdCoordinator: NSObject, ObservableObject {
    @Published private(set) var nativeAd: NativeAd?

    private var adLoader: AdLoader?
    private var lastLoadStartedAt: Date?
    private var isLoading = false
    private var lastFailureAt: Date?
    private let adUnitID = AdConfig.nativeStationAdUnitID

    /// Dopo un no-fill si aspetta prima di richiedere: senza, ogni onAppear
    /// faceva partire una richiesta nuova.
    private let failureBackoff: TimeInterval = 60

    func loadAd() {
        // Defensive Pro gate: never spend bandwidth fetching a creative we will not display.
        guard !IAPManager.shared.isProUser else { return }
        // Mai una richiesta nuova con un annuncio gia' carico o in arrivo.
        // Per rinfrescarlo si passa da `reset()`.
        guard nativeAd == nil, !isLoading else { return }
        if let lastFailureAt, Date().timeIntervalSince(lastFailureAt) < failureBackoff { return }
        isLoading = true
        // Anchor the loader to the topmost VC so click-through presents from the right context.
        let loader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: AdRootViewController.current(),
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        adLoader = loader
        lastLoadStartedAt = Date()
        loader.load(Request())
    }

    /// Returns true if we should kick off a fresh load: no cached ad, or the cached one is older than `minAge`.
    func shouldReload(minAge: TimeInterval) -> Bool {
        if nativeAd == nil { return true }
        guard let lastLoadStartedAt else { return true }
        return Date().timeIntervalSince(lastLoadStartedAt) > minAge
    }

    func reset() {
        nativeAd = nil
    }
}

extension NativeAdCoordinator: NativeAdLoaderDelegate {
    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in
            self.nativeAd = nativeAd
            self.isLoading = false
            self.lastFailureAt = nil
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader,
                              didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            print("[NativeAd] load failed: \(error.localizedDescription)")
            self.nativeAd = nil
            self.isLoading = false
            self.lastFailureAt = Date()
        }
    }
}
