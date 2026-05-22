//  RewardedAdCoordinator.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

import Foundation
import Combine
import UIKit
import GoogleMobileAds

@MainActor
final class RewardedAdCoordinator: NSObject, ObservableObject {
    @Published private(set) var isAdReady = false

    private var rewardedAd: RewardedAd?
    private let adUnitID = AdConfig.rewardedAdUnitID

    func loadAd() async {
        guard rewardedAd == nil else { return }
        do {
            rewardedAd = try await RewardedAd.load(
                with: adUnitID,
                request: Request()
            )
            rewardedAd?.fullScreenContentDelegate = self
            isAdReady = true
        } catch {
            print("[Rewarded] load failed: \(error.localizedDescription)")
            isAdReady = false
        }
    }

    /// Shows the rewarded ad. The completion is called only if the user earned the reward.
    func showAd(onReward: @escaping () -> Void) {
        guard let rewardedAd, let root = AdRootViewController.current() else {
            Task { await loadAd() }
            return
        }
        rewardedAd.present(from: root) {
            onReward()
        }
    }
}

extension RewardedAdCoordinator: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.rewardedAd = nil
            self.isAdReady = false
            await loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[Rewarded] present failed: \(error.localizedDescription)")
            self.rewardedAd = nil
            self.isAdReady = false
            await loadAd()
        }
    }
}
