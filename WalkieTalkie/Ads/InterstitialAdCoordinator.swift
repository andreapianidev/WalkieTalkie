//  InterstitialAdCoordinator.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani

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

    /// Vero se il tetto giornaliero lascia ancora spazio a una presentazione.
    ///
    /// Serve a decidere se vale la pena CARICARE, non se si puo' mostrare
    /// adesso: percio' guarda solo il tetto del giorno e non la cadenza minima
    /// di 180 s, che fra il momento del precaricamento (accensione della radio)
    /// e quello della presentazione (uscita dalla radio) sara' quasi sempre
    /// passata. La verifica vera resta in `showAdIfAllowed`.
    var canShowSoon: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let countToday = (today == shownTodayStart) ? shownTodayCount : 0
        return countToday < AdConfig.FrequencyCap.interstitialDailyMax
    }

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
            // Nessun ricaricamento immediato: l'interstitial si mostra solo
            // all'uscita dalla radio, e l'utente ne e' appena uscito. Il
            // prossimo lo prepara `AdManager.prepareInterstitialForRadioSession`
            // quando la radio riparte. Ricaricare qui voleva dire una richiesta
            // riempita e mai mostrata per ogni annuncio mostrato.
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
