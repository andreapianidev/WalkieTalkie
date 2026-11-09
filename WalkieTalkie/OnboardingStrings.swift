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

    // MARK: - Page 2 — Two Talky (the walkie needs Talky on the other phone too)
    static let twoTalkyTitle = NSLocalizedString("onboarding_two_talky_title", comment: "Page 2 title: the walkie needs two Talky")
    static let twoTalkyBody = NSLocalizedString("onboarding_two_talky_body", comment: "Page 2 body: install Talky on the other phone too")
    static let twoTalkyRange = NSLocalizedString("onboarding_two_talky_range", comment: "Page 2: range 10-30 m, Wi-Fi and Bluetooth on")
    static let p2RangeCaveat = NSLocalizedString("onboarding_p2_range_caveat", comment: "Page 2 range note")
    static let p2SameWiFi = NSLocalizedString("onboarding_p2_same_wifi", comment: "Page 2: Mac/Android need the same Wi-Fi network")

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
    static let radioModeStreamingNote = NSLocalizedString("onboarding.radio_mode.streaming_note", comment: "Streaming note (clarifies it's internet, not antenna FM)")

    // MARK: - Page 6 — Live radio
    static let liveTitle = NSLocalizedString("onboarding.live.title", comment: "Live radio page title")
    static let liveSubtitle = NSLocalizedString("onboarding.live.subtitle", comment: "Live radio page subtitle")
    static let liveHF = NSLocalizedString("onboarding.live.hf", comment: "What HF offers")
    static let liveCB = NSLocalizedString("onboarding.live.cb", comment: "What CB offers")
    static let livePOC = NSLocalizedString("onboarding.live.poc", comment: "What POC offers")
    static let liveNote = NSLocalizedString("onboarding.live.note", comment: "Listen only, free minutes per day (%d)")

    // MARK: - Widgets
    static let widgetsTitle = NSLocalizedString("onboarding.widgets.title", comment: "Widgets page title")
    static let widgetsSubtitle = NSLocalizedString("onboarding.widgets.subtitle", comment: "Widgets page subtitle")
    static let widgetsChannel = NSLocalizedString("onboarding.widgets.channel", comment: "Channel widget, free")
    static let widgetsPropagation = NSLocalizedString("onboarding.widgets.propagation", comment: "Propagation widget, Pro")
    static let widgetsSun = NSLocalizedString("onboarding.widgets.sun", comment: "Sun and bands widget, Pro")

    // MARK: - Page 7 — Next steps
    static let p5Title = NSLocalizedString("onboarding_p5_steps_title", comment: "Page 5 title")
    static let p5Step1 = NSLocalizedString("onboarding_p5_step1", comment: "Page 5 step 1")
    static let p5Step2 = NSLocalizedString("onboarding_p5_step2", comment: "Page 5 step 2")
    static let p5Step3 = NSLocalizedString("onboarding_p5_step3", comment: "Page 5 step 3")
    static let p5PermissionNote = NSLocalizedString("onboarding_p5_permission_note", comment: "Page 5: neutral explanation of the Local Network permission")

    // MARK: - Permissions sheet
    static let micTitle = NSLocalizedString("onboarding_mic_title", comment: "Permissions sheet title, microphone only")
    static let permissionsDescription = NSLocalizedString("onboarding_mic_description", comment: "Why the microphone: the walkie; live CB and radio work without it")
    static let microphonePermission = NSLocalizedString("onboarding_microphone_permission", comment: "Microphone permission label")
    static let microphonePermissionWhy = NSLocalizedString("onboarding_permission_mic_why", comment: "Why microphone is needed")
    static let openSettingsLink = NSLocalizedString("onboarding_permission_open_settings", comment: "Open iOS Settings link")

    // MARK: - Start choice (after the system prompt, never before it)
    static let startTitle = NSLocalizedString("onboarding_start_title", comment: "Where do you start?")
    static let startFriend = NSLocalizedString("onboarding_start_friend", comment: "I have a friend nearby")
    static let startFriendDetail = NSLocalizedString("onboarding_start_friend_detail", comment: "Goes to the walkie")
    static let startSolo = NSLocalizedString("onboarding_start_solo", comment: "I'm on my own")
    static let startSoloDetail = NSLocalizedString("onboarding_start_solo_detail", comment: "Goes to live CB listening")

    // MARK: - Actions
    static let continueButton = NSLocalizedString("onboarding_continue", comment: "Continue button")
    static let getStartedButton = NSLocalizedString("onboarding_get_started", comment: "Get started button")
    // `allowPermissionsButton` e' stato eliminato di proposito: era l'etichetta
    // direttiva ("Consenti") davanti al prompt microfono che ha fatto rifiutare
    // la 2.44 per 5.1.1(iv). Il foglio permessi usa `continueButton`. Non
    // reintrodurre una stringa direttiva qui.
    static let skipButton = NSLocalizedString("onboarding_skip", comment: "Skip button (onboarding carousel only — never on the permissions sheet)")
    static let backButton = NSLocalizedString("onboarding_back", comment: "Back button")

    // MARK: - First Run Coach (post-onboarding)
    static let coachNoPeersTitle = NSLocalizedString("coach_no_peers_title", comment: "Coach: no peers title")
    static let coachNoPeersBody = NSLocalizedString("coach_no_peers_body", comment: "Coach: no peers body")
    static let coachPressPTTTitle = NSLocalizedString("coach_press_ptt_title", comment: "Coach: press PTT title")
    static let coachPressPTTBody = NSLocalizedString("coach_press_ptt_body", comment: "Coach: press PTT body")
    static let coachDismiss = NSLocalizedString("coach_dismiss", comment: "Coach dismiss button")
}
