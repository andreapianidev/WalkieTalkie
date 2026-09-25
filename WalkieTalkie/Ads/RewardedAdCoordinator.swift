//  RewardedAdCoordinator.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani

import Foundation
import Combine
import UIKit
import GoogleMobileAds

/// Rewarded caricato solo a richiesta, quando l'utente tocca un CTA: niente
/// precaricamento alla comparsa del bottone e niente ricaricamento dopo la
/// chiusura. AdMob misurava uno show rate del 5,5% sul rewarded precaricato,
/// perche' la maggior parte di chi vede il bottone non lo tocca.
@MainActor
final class RewardedAdCoordinator: NSObject, ObservableObject {
    @Published private(set) var isAdReady = false
    /// Vero mentre si carica l'annuncio dopo il tocco sul CTA: i bottoni
    /// mostrano lo spinner e ignorano altri tocchi.
    @Published private(set) var isLoading = false

    private var rewardedAd: RewardedAd?
    private var loadedAt: Date?
    private let adUnitID = AdConfig.rewardedAdUnitID

    /// Un rewarded scade dopo un'ora: lo si butta un po' prima.
    private let maxAge: TimeInterval = 55 * 60

    private func loadAd() async {
        guard rewardedAd == nil else { return }
        do {
            let ad = try await RewardedAd.load(
                with: adUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            loadedAt = Date()
            isAdReady = true
        } catch {
            print("[Rewarded] load failed: \(error.localizedDescription)")
            isAdReady = false
        }
    }

    /// Shows the rewarded ad. The completion is called only if the user earned the reward.
    ///
    /// Se l'annuncio non e' ancora caricato lo si chiede adesso (spinner via
    /// `isLoading`) e lo si presenta appena arriva. `onUnavailable` scatta solo
    /// se dopo il caricamento non c'e' comunque niente da mostrare.
    func showAd(onReward: @escaping () -> Void,
                onUnavailable: (() -> Void)? = nil) {
        if presentNow(onReward: onReward) { return }
        guard !isLoading else { return }
        isLoading = true
        Task { @MainActor in
            await self.loadAd()
            self.isLoading = false
            if !self.presentNow(onReward: onReward) {
                onUnavailable?()
            }
        }
    }

    /// Presenta l'annuncio se e' pronto. False se manca l'annuncio o la vista
    /// da cui presentarlo.
    private func presentNow(onReward: @escaping () -> Void) -> Bool {
        discardIfExpired()
        guard let rewardedAd, let root = AdRootViewController.current() else {
            return false
        }
        rewardedAd.present(from: root) {
            onReward()
        }
        return true
    }

    private func discardIfExpired() {
        guard let loadedAt, Date().timeIntervalSince(loadedAt) > maxAge else { return }
        rewardedAd = nil
        self.loadedAt = nil
        isAdReady = false
    }
}

extension RewardedAdCoordinator: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.rewardedAd = nil
            self.loadedAt = nil
            self.isAdReady = false
            // Nessun ricaricamento automatico: il prossimo si chiede al
            // prossimo tocco su un CTA.
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[Rewarded] present failed: \(error.localizedDescription)")
            // Nessun ricaricamento: il prossimo tocco ne chiede uno nuovo.
            self.rewardedAd = nil
            self.loadedAt = nil
            self.isAdReady = false
        }
    }
}
