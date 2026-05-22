//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemeManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import SwiftUI
import Combine

/// Manager singleton che gestisce il tema corrente dell'app.
/// Persiste la scelta tramite UserDefaults e valida lo stato Pro all'avvio.
@MainActor
final class ThemeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ThemeManager()

    // MARK: - Storage Keys

    /// Chiave UserDefaults per la persistenza del tema selezionato.
    private static let storageKey = "selected_theme"

    /// Chiave bridge scritta da IAPManager per indicare lo stato Pro dell'utente.
    /// NON importare IAPManager: leggere solo questa chiave.
    private static let proBridgeKey = "fastboot_isProUser"

    /// Chiave bridge scritta da IAPManager con l'array di product ID dei temi
    /// singoli acquistati (non-consumable). NON importare IAPManager: leggere solo
    /// questa chiave per mantenere il disaccoppiamento tra moduli.
    private static let ownedThemesBridgeKey = "fastboot_ownedThemes"

    // MARK: - Published State

    /// Tema attualmente attivo. Le View possono osservarlo per aggiornare l'UI.
    @Published var currentTheme: Theme = .defaultTheme

    // MARK: - Init

    private init() {
        // Legge il tema salvato e lo valida rispetto allo stato Pro corrente.
        // Se il tema persistito è Pro-locked ma l'utente non è più Pro,
        // fa il fallback al tema predefinito per evitare inconsistenze.
        let savedRaw = UserDefaults.standard.string(forKey: Self.storageKey) ?? Theme.defaultTheme.rawValue

        if let saved = Theme(rawValue: savedRaw) {
            if saved.isProLocked && !canAccess(theme: saved) {
                // Reset di sicurezza: tema Pro non più disponibile né come subscription
                // né come acquisto singolo
                currentTheme = .defaultTheme
                UserDefaults.standard.set(Theme.defaultTheme.rawValue, forKey: Self.storageKey)
                Logger.shared.logInfo("ThemeManager: tema Pro '\(saved.rawValue)' non accessibile, fallback a default")
            } else {
                currentTheme = saved
                Logger.shared.logInfo("ThemeManager: tema caricato '\(saved.rawValue)'")
            }
        } else {
            // Raw string non valida: fallback safe
            currentTheme = .defaultTheme
            Logger.shared.logInfo("ThemeManager: raw value non valido, fallback a default")
        }
    }

    // MARK: - Pro Status Bridge

    /// Stato Pro dell'utente letto dalla bridge key di IAPManager.
    var isProUser: Bool {
        UserDefaults.standard.bool(forKey: Self.proBridgeKey)
    }

    /// Array di product ID dei temi singoli acquistati, letto dalla bridge key.
    /// Vuoto se l'utente non ha comprato alcun tema singolo.
    private var ownedThemeProductIDs: [String] {
        UserDefaults.standard.array(forKey: Self.ownedThemesBridgeKey) as? [String] ?? []
    }

    /// True se l'utente può accedere al tema, tramite subscription Pro O
    /// tramite acquisto singolo non-consumable.
    /// I temi non Pro-locked sono sempre accessibili.
    func canAccess(theme: Theme) -> Bool {
        // Non Pro-locked → sempre OK
        guard theme.isProLocked else { return true }

        // Subscription attiva → sblocca tutto
        if isProUser { return true }

        // Acquisto singolo: controlla il productID del tema vs. il bridge
        let metadata = ThemeRegistry.metadata(for: theme)
        if let pid = metadata.productID, ownedThemeProductIDs.contains(pid) {
            return true
        }

        return false
    }

    // MARK: - Public API

    /// Imposta il tema scelto dall'utente.
    /// - Parameter theme: il tema da applicare.
    /// - Returns: `true` se applicato, `false` se bloccato (né subscription né
    ///   acquisto singolo lo sbloccano).
    @discardableResult
    func setTheme(_ theme: Theme) -> Bool {
        // Blocca il cambio se il tema è Pro-locked e l'utente non ha né
        // subscription né acquisto singolo del tema
        if !canAccess(theme: theme) {
            Logger.shared.logInfo("ThemeManager: setTheme bloccato per '\(theme.rawValue)' (Pro o acquisto singolo richiesto)")
            return false
        }

        // Applica e persiste
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
        Logger.shared.logInfo("ThemeManager: tema impostato a '\(theme.rawValue)'")
        return true
    }
}
