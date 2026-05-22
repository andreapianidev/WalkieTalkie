//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - PrivateChannelManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import Combine
import CryptoKit

/// Gestore dei canali walkie privati protetti da password.
/// Un canale è identificato da un hash SHA256 della password (primi 16 caratteri esadecimali).
/// Lo stato di default è "public" (nessuna password, comportamento storico dell'app).
@MainActor
final class PrivateChannelManager: ObservableObject {
    static let shared = PrivateChannelManager()

    // MARK: - Constants

    /// Identificatore del canale pubblico (default, nessuna password).
    static let publicChannelID = "public"

    /// Lunghezza minima della password per creare un canale privato.
    static let minPasswordLength = 4

    // MARK: - Persistence Keys

    private enum Keys {
        static let channelID = "private_channel_id"
        static let channelName = "private_channel_name"
        static let proBridge = "fastboot_isProUser"
    }

    // MARK: - Published State

    /// ID del canale corrente: "public" oppure hash a 16 caratteri esadecimali.
    @Published private(set) var currentChannelID: String = PrivateChannelManager.publicChannelID

    /// Nome user-facing del canale corrente (nil se in modalità pubblica).
    @Published private(set) var currentChannelName: String? = nil

    // MARK: - Dependencies

    private let defaults = UserDefaults.standard
    private let logger = Logger.shared

    // MARK: - Init

    private init() {
        // Ripristina lo stato persistito (canale + nome) all'avvio
        let savedID = defaults.string(forKey: Keys.channelID) ?? PrivateChannelManager.publicChannelID
        let savedName = defaults.string(forKey: Keys.channelName)

        self.currentChannelID = savedID
        self.currentChannelName = (savedID == PrivateChannelManager.publicChannelID) ? nil : savedName

        logger.logNetworkInfo("PrivateChannelManager init - canale: \(savedID) (\(savedName ?? "pubblico"))")
    }

    // MARK: - Pro Gating

    /// Stato Pro letto via UserDefaults (bridge con IAPManager, non importiamo direttamente IAP).
    var isProUser: Bool {
        defaults.bool(forKey: Keys.proBridge)
    }

    // MARK: - Public API

    /// Entra in un canale privato protetto da password.
    /// - Returns: `true` se l'utente ha permessi Pro e i parametri sono validi; altrimenti `false`.
    @discardableResult
    func joinChannel(name: String, password: String) -> Bool {
        // Gate Pro: gli utenti free restano in modalità pubblica
        guard isProUser else {
            logger.logNetworkWarning("Tentativo di entrare in canale privato senza permessi Pro")
            return false
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password // la password non viene normalizzata su whitespace

        guard !trimmedName.isEmpty else {
            logger.logNetworkWarning("Nome canale vuoto")
            return false
        }

        guard trimmedPassword.count >= PrivateChannelManager.minPasswordLength else {
            logger.logNetworkWarning("Password troppo corta (<\(PrivateChannelManager.minPasswordLength))")
            return false
        }

        // Calcolo del channel ID = primi 16 char dell'hash SHA256(password)
        let channelID = String(sha256(trimmedPassword).prefix(16))

        // Persistenza
        defaults.set(channelID, forKey: Keys.channelID)
        defaults.set(trimmedName, forKey: Keys.channelName)

        // Aggiornamento stato pubblicato
        currentChannelID = channelID
        currentChannelName = trimmedName

        logger.logNetworkInfo("Entrato nel canale privato '\(trimmedName)' (id: \(channelID))")

        // Riavvio Multipeer con il nuovo discoveryInfo
        MultipeerManager.shared?.restartWithCurrentChannel()

        return true
    }

    /// Torna alla modalità pubblica (default app).
    func leaveChannel() {
        defaults.set(PrivateChannelManager.publicChannelID, forKey: Keys.channelID)
        defaults.removeObject(forKey: Keys.channelName)

        currentChannelID = PrivateChannelManager.publicChannelID
        currentChannelName = nil

        logger.logNetworkInfo("Uscito dal canale privato, ritorno a modalità pubblica")

        MultipeerManager.shared?.restartWithCurrentChannel()
    }

    // MARK: - Helpers

    /// SHA256 della stringa in input, ritornato come stringa esadecimale lowercase.
    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
