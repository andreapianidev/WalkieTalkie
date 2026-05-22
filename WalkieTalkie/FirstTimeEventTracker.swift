//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - FirstTimeEventTracker.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import FirebaseAnalytics

/// Tracks one-shot funnel events that should fire only the first time per install.
/// Used to diagnose D1 retention drop by measuring how many users reach key milestones.
final class FirstTimeEventTracker {
    static let shared = FirstTimeEventTracker()

    private let defaults = UserDefaults.standard
    private let logger = Logger.shared
    private let keyPrefix = "fte_"

    private init() {}

    /// Fires a Firebase event only on the first occurrence per install.
    /// - Parameters:
    ///   - eventName: Firebase event name (also used as the persistence key suffix).
    ///   - parameters: Optional extra parameters. A `timestamp` is always added.
    /// - Returns: `true` if the event was fired now, `false` if it had already fired before.
    @discardableResult
    func fireOnce(_ eventName: String, parameters: [String: Any]? = nil) -> Bool {
        let key = keyPrefix + eventName
        guard !defaults.bool(forKey: key) else { return false }

        defaults.set(true, forKey: key)

        var params = parameters ?? [:]
        params["timestamp"] = Date().timeIntervalSince1970
        Analytics.logEvent(eventName, parameters: params)

        logger.logInfo("Analytics: first-time event - \(eventName)")
        return true
    }
}

// MARK: - Event Names
extension FirstTimeEventTracker {
    struct Events {
        static let onboardingComplete = "first_onboarding_complete"
        static let pttPress = "first_ptt_press"
        static let reception = "first_reception"
        static let channelChange = "first_channel_change"
        static let firstRunCoachDismissed = "first_run_coach_dismissed"
    }
}
