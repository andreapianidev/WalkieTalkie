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

    /// Riprende l'ultima stazione radio all'avvio dell'app.
    @Published var autoResumeRadio: Bool {
        didSet { defaults.set(autoResumeRadio, forKey: "mac_auto_resume_radio") }
    }

    /// True dopo che l'utente ha visto l'onboarding di benvenuto.
    @Published var hasSeenOnboarding: Bool {
        didSet { defaults.set(hasSeenOnboarding, forKey: "mac_has_seen_onboarding") }
    }

    /// Mostra la mini-console nella menu bar.
    @Published var showMenuBarExtra: Bool {
        didSet { defaults.set(showMenuBarExtra, forKey: "mac_show_menubar_extra") }
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
        // Night Ops di default: è il tema dove la resa Metal (griglia tattica,
        // sweep radar) è subito visibile. Carbon resta selezionabile per chi
        // preferisce il minimal.
        self.backdropRaw = defaults.string(forKey: Keys.backdrop) ?? "nightOps"
        self.autoResumeRadio = defaults.object(forKey: "mac_auto_resume_radio") as? Bool ?? false
        self.hasSeenOnboarding = defaults.object(forKey: "mac_has_seen_onboarding") as? Bool ?? false
        self.showMenuBarExtra = defaults.object(forKey: "mac_show_menubar_extra") as? Bool ?? true
    }

    /// Nome effettivo pubblicato sulla rete (mai vuoto).
    var deviceDisplayName: String {
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (Host.current().localizedName ?? "Mac") : trimmed
    }

    /// Riporta TUTTE le preferenze persistite ai valori di fabbrica, incluse
    /// quelle non esposte nel tab General (menu bar, onboarding).
    func resetToDefaults() {
        deviceName = Host.current().localizedName ?? "Mac"
        autoStartNetwork = true
        radioVolume = 0.5
        spacebarPTT = true
        backdropRaw = "nightOps"
        autoResumeRadio = false
        showMenuBarExtra = true
        hasSeenOnboarding = false
    }
}
