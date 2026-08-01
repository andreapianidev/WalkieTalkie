//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - SettingsManager.swift
//  macTalky
//
//  Persistenza impostazioni macOS via UserDefaults. Versione snella del
//  SettingsManager iOS: niente rumore bianco / haptics / Live Activities.

import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let deviceName = "mac_device_display_name"
        static let autoStartNetwork = "mac_auto_start_network"
        static let radioVolume = "mac_radio_volume"
        static let spacebarPTT = "mac_spacebar_ptt"
        static let receiveChime = "mac_receive_chime"
        static let backdrop = "mac_console_backdrop"
    }

    /// Tema di sfondo della console (raw value di `ConsoleBackdrop`).
    @Published var backdropRaw: String {
        didSet { defaults.set(backdropRaw, forKey: Keys.backdrop) }
    }

    /// Nome mostrato agli altri peer TALKY1 (default: nome del Mac).
    @Published var deviceName: String {
        didSet { defaults.set(deviceName, forKey: Keys.deviceName) }
    }

    /// Avvia automaticamente discovery + listener all'apertura dell'app.
    @Published var autoStartNetwork: Bool {
        didSet { defaults.set(autoStartNetwork, forKey: Keys.autoStartNetwork) }
    }

    /// Volume radio persistito tra le sessioni.
    @Published var radioVolume: Float {
        didSet {
            defaults.set(radioVolume, forKey: Keys.radioVolume)
            RadioManager.shared.setVolume(radioVolume)
        }
    }

    /// Tieni premuta la barra spaziatrice per trasmettere (nella vista Walkie).
    @Published var spacebarPTT: Bool {
        didSet { defaults.set(spacebarPTT, forKey: Keys.spacebarPTT) }
    }

    private init() {
        let hostName = Host.current().localizedName ?? "Mac"
        self.deviceName = defaults.string(forKey: Keys.deviceName) ?? hostName
        self.autoStartNetwork = defaults.object(forKey: Keys.autoStartNetwork) as? Bool ?? true
        self.radioVolume = defaults.object(forKey: Keys.radioVolume) as? Float ?? 0.5
        self.spacebarPTT = defaults.object(forKey: Keys.spacebarPTT) as? Bool ?? true
        self.backdropRaw = defaults.string(forKey: Keys.backdrop) ?? "carbon"
    }

    /// Nome effettivo pubblicato sulla rete (mai vuoto).
    var deviceDisplayName: String {
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (Host.current().localizedName ?? "Mac") : trimmed
    }

    func resetToDefaults() {
        deviceName = Host.current().localizedName ?? "Mac"
        autoStartNetwork = true
        radioVolume = 0.5
        spacebarPTT = true
    }
}
