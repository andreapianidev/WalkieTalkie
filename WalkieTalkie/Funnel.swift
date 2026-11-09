//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - Funnel.swift
//  Talky
//
//  Il percorso del nuovo utente in Firebase, dall'installazione alla prima
//  trasmissione riuscita: dove cade di piu' decide le modifiche successive.
//  Gli eventi "first_" partono una volta per installazione (FirstTimeEventTracker),
//  gli altri ogni volta. Mai nomi di dispositivi o di persone nei parametri.

import FirebaseAnalytics
import Foundation

enum Funnel {
    // Una volta per installazione.
    static let onboardingCompleted = "first_onboarding_completed"
    static let localNetworkDenied = "first_local_network_denied"
    static let localNetworkGranted = "first_local_network_granted"
    static let peerFound = "first_peer_found"
    static let connectionEstablished = "first_connection_established"
    static let transmissionSuccess = "first_transmission_success"
    static let radioPlay = "first_radio_play"
    static let liveListen = "first_live_listen"

    // Ripetibili.
    static let pairingHelpShown = "pairing_help_shown"
    static let inviteOpened = "invite_opened"
    static let inviteShared = "invite_shared"
    static let connectionFailed = "connection_failed"
    static let pairingListenCB = "pairing_help_listen_cb"
    /// Ultima pagina dell'onboarding: "friend" o "solo".
    static let onboardingPath = "onboarding_path"
    static let whatsNewShown = "whats_new_shown"
    static let whatsNewTried = "whats_new_tried"

    static func once(_ name: String, _ parameters: [String: Any]? = nil) {
        FirstTimeEventTracker.shared.fireOnce(name, parameters: parameters)
    }

    static func log(_ name: String, _ parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
}
