//  ConsentManager.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

import Foundation
import Combine
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    @Published var canRequestAds: Bool = false
    @Published var isPrivacyOptionsRequired: Bool = false

    private init() {}

    /// Runs the UMP consent flow. Does NOT request ATT or initialize the SDK —
    /// the caller (AdManager.bootstrap) chains those in the correct order:
    ///   1. UMP (this method)
    ///   2. ATT (requestATTIfNeeded)
    ///   3. GoogleMobileAds.start
    func gatherConsent() async {
        let params = UserMessagingPlatform.RequestParameters()
        params.isTaggedForUnderAgeOfConsent = false

        #if DEBUG
        let debug = UserMessagingPlatform.DebugSettings()
        // Register known internal test devices so UMP returns deterministic
        // debug-geography responses. The IDs are surfaced by UMP at runtime as
        // "<UMP SDK> To enable debug mode for this device, set: ...". Add new
        // ones here when onboarding additional test phones.
        debug.testDeviceIdentifiers = [
            "B07ED5E0-8565-45F8-95AD-3F0C990972F2" // iPhone Andrea
        ]
        // Uncomment to force EEA flow in development:
        // debug.geography = .EEA
        params.debugSettings = debug
        #endif

        var didFail = false
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: params)
            if let root = AdRootViewController.current() {
                try await ConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            didFail = true
            print("[ConsentManager] error: \(error.localizedDescription)")
        }

        refreshState()

        #if DEBUG
        // In DEBUG, if UMP failed (e.g. publisher has not yet configured a
        // consent form in the AdMob dashboard for the current app ID) we still
        // want the test ad pipeline to work end-to-end. AdMob's own test ads
        // are policy-compliant without explicit user consent, so we flip the
        // gate manually to unblock local dev. Never compiled in Release.
        if didFail && !canRequestAds {
            canRequestAds = true
            print("[ConsentManager] DEBUG override: canRequestAds=true (form non configurato lato AdMob)")
        }
        #endif
    }

    /// Requests ATT only after UMP has resolved and the app is foreground-active.
    /// Apple (iOS 17.4+) is strict about ATT timing: must not fire during a scene
    /// transition or before the main UI is visible.
    func requestATTIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        // Wait until the app is foreground-active (max ~2s).
        for _ in 0..<20 {
            if UIApplication.shared.applicationState == .active { break }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        // Extra safety buffer so we are not racing a scene transition.
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s

        guard UIApplication.shared.applicationState == .active else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    func presentPrivacyOptions() async {
        guard let root = AdRootViewController.current() else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: root)
        } catch {
            print("[ConsentManager] privacy options error: \(error.localizedDescription)")
        }
        refreshState()
    }

    private func refreshState() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        isPrivacyOptionsRequired = ConsentInformation.shared
            .privacyOptionsRequirementStatus == .required
    }
}
