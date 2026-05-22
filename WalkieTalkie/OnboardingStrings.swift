//
//  OnboardingStrings.swift
//  WalkieTalkie
//
//  Created by Assistant on 12/07/25.
//

import Foundation

struct OnboardingStrings {
    // MARK: - Page 1 — Hook
    static let p1Title = NSLocalizedString("onboarding_p1_title", comment: "Page 1 title")
    static let p1Subtitle = NSLocalizedString("onboarding_p1_subtitle", comment: "Page 1 subtitle")

    // MARK: - Page 2 — No internet
    static let p2Title = NSLocalizedString("onboarding_p2_no_internet_title", comment: "Page 2 title")
    static let p2Body = NSLocalizedString("onboarding_p2_no_internet_body", comment: "Page 2 body")
    static let p2RangeCaveat = NSLocalizedString("onboarding_p2_range_caveat", comment: "Page 2 range note")

    // MARK: - Page 3 — Push to talk
    static let p3Title = NSLocalizedString("onboarding_p3_ptt_title", comment: "Page 3 title")
    static let p3Body = NSLocalizedString("onboarding_p3_ptt_body", comment: "Page 3 body")
    static let p3Rule = NSLocalizedString("onboarding_p3_ptt_rule", comment: "Page 3 rule")

    // MARK: - Page 4 — Frequencies
    static let p4Title = NSLocalizedString("onboarding_p4_frequency_title", comment: "Page 4 title")
    static let p4Analogy = NSLocalizedString("onboarding_p4_frequency_analogy", comment: "Page 4 analogy")
    static let p4ChangeFreqHint = NSLocalizedString("onboarding_p4_change_freq_hint", comment: "Page 4 change freq hint")
    static let p4PrivateChannelsTeaser = NSLocalizedString("onboarding_p4_private_channels_teaser", comment: "Page 4 private channels teaser")

    // MARK: - Page 5 — Radio mode (WT <-> FM toggle)
    static let radioModeTitle = NSLocalizedString("onboarding.radio_mode.title", comment: "Radio mode title")
    static let radioModeSubtitle = NSLocalizedString("onboarding.radio_mode.subtitle", comment: "Radio mode subtitle")
    static let radioModeBody = NSLocalizedString("onboarding.radio_mode.body", comment: "Radio mode body")

    // MARK: - Page 6 — Next steps
    static let p5Title = NSLocalizedString("onboarding_p5_steps_title", comment: "Page 5 title")
    static let p5Step1 = NSLocalizedString("onboarding_p5_step1", comment: "Page 5 step 1")
    static let p5Step2 = NSLocalizedString("onboarding_p5_step2", comment: "Page 5 step 2")
    static let p5Step3 = NSLocalizedString("onboarding_p5_step3", comment: "Page 5 step 3")

    // MARK: - Permissions sheet
    static let permissionsTitle = NSLocalizedString("onboarding_permissions_title", comment: "Permissions title")
    static let permissionsDescription = NSLocalizedString("onboarding_permissions_description", comment: "Permissions description")
    static let microphonePermission = NSLocalizedString("onboarding_microphone_permission", comment: "Microphone permission label")
    static let microphonePermissionWhy = NSLocalizedString("onboarding_permission_mic_why", comment: "Why microphone is needed")
    static let notificationPermission = NSLocalizedString("onboarding_notification_permission", comment: "Notification permission label")
    static let notificationPermissionWhy = NSLocalizedString("onboarding_permission_notif_why", comment: "Why notifications are needed")
    static let openSettingsLink = NSLocalizedString("onboarding_permission_open_settings", comment: "Open iOS Settings link")

    // MARK: - Actions
    static let continueButton = NSLocalizedString("onboarding_continue", comment: "Continue button")
    static let getStartedButton = NSLocalizedString("onboarding_get_started", comment: "Get started button")
    static let allowPermissionsButton = NSLocalizedString("onboarding_allow_permissions", comment: "Allow permissions button")
    static let skipButton = NSLocalizedString("onboarding_skip", comment: "Skip button")
    static let backButton = NSLocalizedString("onboarding_back", comment: "Back button")

    // MARK: - First Run Coach (post-onboarding)
    static let coachNoPeersTitle = NSLocalizedString("coach_no_peers_title", comment: "Coach: no peers title")
    static let coachNoPeersBody = NSLocalizedString("coach_no_peers_body", comment: "Coach: no peers body")
    static let coachPressPTTTitle = NSLocalizedString("coach_press_ptt_title", comment: "Coach: press PTT title")
    static let coachPressPTTBody = NSLocalizedString("coach_press_ptt_body", comment: "Coach: press PTT body")
    static let coachDismiss = NSLocalizedString("coach_dismiss", comment: "Coach dismiss button")
}
