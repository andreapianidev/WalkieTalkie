//  RewardedAdCoordinator.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani

import Foundation
import Combine
import UIKit
import GoogleMobileAds

/// Rewarded caricato in anticipo con riuso: uno a fine bootstrap, tenuto in
/// cache finche' non si mostra (fino a 55 minuti), richiesto di nuovo dopo ogni
/// presentazione. Chi tocca un CTA lo trova pronto invece di aspettare lo
/// spinner, che era il punto in cui molti rinunciavano. Se al tocco non c'e',
/// si carica allora, come prima.
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

    /// Vero se vale la pena tenere un annuncio pronto. Lo imposta `AdManager`.
    var shouldPreload: () -> Bool = { false }

    /// La richiesta in volo, se c'e': un tocco durante il precaricamento la
    /// aspetta invece di aprirne un'altra.
    private var loadTask: Task<Void, Never>?
    private var lastFailureAt: Date?
    private let failureBackoff: TimeInterval = 120

    /// Tiene un annuncio pronto se serve. Non fa niente se ce n'e' gia' uno,
    /// se una richiesta e' in volo o se l'ultimo no-fill e' troppo recente.
    func preloadIfUseful() {
        discardIfExpired()
        guard shouldPreload(), rewardedAd == nil, loadTask == nil else { return }
        if let lastFailureAt, Date().timeIntervalSince(lastFailureAt) < failureBackoff { return }
        Task { await self.loadAd() }
    }

    private func loadAd() async {
        if let loadTask { await loadTask.value; return }
        guard rewardedAd == nil else { return }
        let task = Task { @MainActor in await self.performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
        do {
            let ad = try await RewardedAd.load(
                with: adUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            loadedAt = Date()
            lastFailureAt = nil
            isAdReady = true
        } catch {
            print("[Rewarded] load failed: \(error.localizedDescription)")
            lastFailureAt = Date()
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
            // Riuso: si richiede subito il prossimo per il tocco successivo.
            self.preloadIfUseful()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[Rewarded] present failed: \(error.localizedDescription)")
            self.rewardedAd = nil
            self.loadedAt = nil
            self.isAdReady = false
            self.preloadIfUseful()
        }
    }
}
