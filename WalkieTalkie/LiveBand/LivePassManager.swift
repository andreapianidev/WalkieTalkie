//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - LivePassManager.swift
//  WalkieTalkie
//
//  Pass "Live 24 ore": SCAN automatico e ascolto HF/POC a schermo spento
//  senza Talky Pro, guadagnati guardando un video premio. Stessa idea di
//  StationPassManager: il premio e' la funzione che l'utente ha appena
//  chiesto, e dura abbastanza da valere il video.

import Foundation

final class LivePassManager {
    static let shared = LivePassManager()

    static let passDuration: TimeInterval = 24 * 3600
    private static let storageKey = "fastboot_livePassExpiry"

    private let defaults = UserDefaults.standard

    private init() {}

    var isActive: Bool {
        guard let expiry else { return false }
        return expiry > Date()
    }

    var expiry: Date? {
        let raw = defaults.double(forKey: Self.storageKey)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    func grantPass() {
        defaults.set(Date().addingTimeInterval(Self.passDuration).timeIntervalSince1970, forKey: Self.storageKey)
    }

    /// Pro, a vita o pass attivo. Si leggono i bridge fast-boot come fa
    /// PaywallTriggerManager: valgono anche prima che StoreKit risponda.
    var hasLiveExtras: Bool {
        defaults.bool(forKey: "fastboot_isProUser") || defaults.bool(forKey: "fastboot_hasLifetime") || isActive
    }
}
