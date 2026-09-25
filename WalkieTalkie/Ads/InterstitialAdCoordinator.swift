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
/// Caricamento in anticipo con riuso: un annuncio si chiede a fine bootstrap,
/// resta in cache finche' non si mostra (fino a 55 minuti) e si richiede dopo
/// ogni presentazione, cosi' il prossimo trigger lo trova pronto. Una sola
/// richiesta alla volta, backoff crescente dopo un no-fill, nessun timer.
///
/// Il caricamento just-in-time (2.46) perdeva l'impression ogni volta che il
/// trigger arrivava prima dell'annuncio. Una richiesta riempita e non mostrata
/// non costa niente; un trigger senza annuncio pronto e' un'impression persa.
@MainActor
final class InterstitialAdCoordinator: NSObject, ObservableObject {
    @Published private(set) var isAdReady = false

    var onDismiss: (() -> Void)?
    /// Vero se vale la pena tenere un annuncio pronto (utente free, annunci non
    /// rimossi dal rewarded). Lo imposta `AdManager`.
    var shouldPreload: () -> Bool = { false }

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
    /// Dopo un no-fill si aspetta prima di richiedere, invece di martellare
    /// AdMob: 60 s, poi il doppio a ogni no-fill di fila, fino a 15 minuti.
    private let baseFailureBackoff: TimeInterval = 60
    private let maxFailureBackoff: TimeInterval = 15 * 60
    private var consecutiveFailures = 0
    private var failureBackoff: TimeInterval {
        min(maxFailureBackoff, baseFailureBackoff * pow(2, Double(max(0, consecutiveFailures - 1))))
    }

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
            consecutiveFailures = 0
            isAdReady = true
        } catch {
            print("[Interstitial] load failed: \(error.localizedDescription)")
            lastFailureAt = Date()
            consecutiveFailures += 1
            isAdReady = false
        }
    }

    /// Tiene un annuncio pronto se serve. Se ce n'e' gia' uno valido, o una
    /// richiesta in volo, o il backoff non e' passato, non fa niente.
    func preloadIfUseful() {
        guard shouldPreload(), canShowSoon else { return }
        Task { await loadAd() }
    }

    /// Tries to present the interstitial. Returns true if the ad was shown.
    ///
    /// Se l'annuncio non c'e' (scaduto o non ancora arrivato) si chiede adesso
    /// per il prossimo trigger.
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
            preloadIfUseful()
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
            // Riuso: si richiede subito il prossimo, resta valido 55 minuti e
            // il trigger successivo lo trova pronto.
            self.preloadIfUseful()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[Interstitial] present failed: \(error.localizedDescription)")
            self.interstitial = nil
            self.loadedAt = nil
            self.isAdReady = false
            self.preloadIfUseful()
        }
    }
}
