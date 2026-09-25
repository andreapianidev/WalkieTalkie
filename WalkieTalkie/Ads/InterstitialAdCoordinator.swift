//  InterstitialAdCoordinator.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani

import Foundation
import Combine
import UIKit
import GoogleMobileAds

/// Unico interstitial dell'app, condiviso da `AdManager.shared.interstitial`.
///
/// Il caricamento e' just-in-time: niente all'avvio, niente alla comparsa di
/// una schermata, niente dopo una chiusura. Lo chiedono solo
/// `AdManager.prepareInterstitialForRadioSession` e
/// `AdManager.prepareInterstitialIfDue`, cioe' quando il prossimo trigger
/// (cambio canale, uscita dalla radio) puo' davvero mostrarlo.
@MainActor
final class InterstitialAdCoordinator: NSObject, ObservableObject {
    @Published private(set) var isAdReady = false

    var onDismiss: (() -> Void)?

    private var interstitial: InterstitialAd?
    private var loadedAt: Date?
    private var isLoading = false
    private var lastFailureAt: Date?
    private var lastShownAt: Date?
    private var shownTodayCount: Int = 0
    private var shownTodayStart: Date = Calendar.current.startOfDay(for: Date())
    private let adUnitID = AdConfig.interstitialAdUnitID

    /// Un interstitial scade dopo un'ora: lo si butta un po' prima.
    private let maxAge: TimeInterval = 55 * 60
    /// Dopo un no-fill si aspetta prima di richiedere, invece di martellare AdMob.
    private let failureBackoff: TimeInterval = 60

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

    /// Come `canShowSoon`, ma rispetta anche la cadenza minima. Per i trigger
    /// ravvicinati (cambio canale), dove la presentazione arriva pochi secondi
    /// dopo il caricamento: se la cadenza la esclude, caricare e' uno spreco.
    var canShowNow: Bool {
        guard canShowSoon else { return false }
        if let lastShownAt,
           Date().timeIntervalSince(lastShownAt) < AdConfig.FrequencyCap.interstitialMinInterval {
            return false
        }
        return true
    }

    /// Vero se l'ultima richiesta e' tornata senza annuncio e il backoff non e'
    /// ancora passato.
    private var recentlyFailedToLoad: Bool {
        guard let lastFailureAt else { return false }
        return Date().timeIntervalSince(lastFailureAt) < failureBackoff
    }

    func loadAd() async {
        discardIfExpired()
        // Una sola richiesta alla volta: `playStation` si chiama a ogni cambio
        // stazione, e prima ogni tocco durante un caricamento ne apriva un altro.
        guard interstitial == nil, !isLoading, !recentlyFailedToLoad else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let ad = try await InterstitialAd.load(
                with: adUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            interstitial = ad
            loadedAt = Date()
            lastFailureAt = nil
            isAdReady = true
        } catch {
            print("[Interstitial] load failed: \(error.localizedDescription)")
            lastFailureAt = Date()
            isAdReady = false
        }
    }

    /// Tries to present the interstitial. Returns true if the ad was shown.
    ///
    /// Se l'annuncio non c'e' non si carica da qui: lo preparano i chiamanti
    /// (`AdManager.prepareInterstitialIfDue`) prima del ritardo di inattivita'.
    @discardableResult
    func showAdIfAllowed() -> Bool {
        resetDailyCounterIfNeeded()
        guard shownTodayCount < AdConfig.FrequencyCap.interstitialDailyMax else { return false }
        if let lastShownAt,
           Date().timeIntervalSince(lastShownAt) < AdConfig.FrequencyCap.interstitialMinInterval {
            return false
        }
        discardIfExpired()
        guard let interstitial, let root = AdRootViewController.current() else {
            return false
        }
        interstitial.present(from: root)
        lastShownAt = Date()
        shownTodayCount += 1
        return true
    }

    private func discardIfExpired() {
        guard let loadedAt, Date().timeIntervalSince(loadedAt) > maxAge else { return }
        interstitial = nil
        self.loadedAt = nil
        isAdReady = false
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
            self.loadedAt = nil
            self.isAdReady = false
            self.onDismiss?()
            // Nessun ricaricamento immediato: la cadenza minima esclude il
            // prossimo trigger per 180 s. Lo preparano
            // `AdManager.prepareInterstitialForRadioSession` e
            // `AdManager.prepareInterstitialIfDue` quando si avvicina.
            // Ricaricare qui voleva dire una richiesta riempita e mai mostrata
            // per ogni annuncio mostrato.
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[Interstitial] present failed: \(error.localizedDescription)")
            // Nessun ricaricamento: lo rifa' il prossimo trigger.
            self.interstitial = nil
            self.loadedAt = nil
            self.isAdReady = false
        }
    }
}
