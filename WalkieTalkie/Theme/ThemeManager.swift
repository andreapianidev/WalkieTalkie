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

    private static let storageKey = "selected_theme"

    /// Chiave bridge scritta da IAPManager per indicare lo stato Pro dell'utente.
    /// NON importare IAPManager: leggere solo questa chiave.
    private static let proBridgeKey = "fastboot_isProUser"

    /// Chiave bridge scritta da IAPManager con il flag del themes pack
    /// (non-consumable one-shot). NON importare IAPManager: leggere solo questa
    /// chiave per mantenere il disaccoppiamento tra moduli.
    private static let themesPackBridgeKey = "fastboot_hasThemesPack"

    // MARK: - Published State

    @Published var currentTheme: Theme = .defaultTheme

    // MARK: - Init

    private init() {
        let savedRaw = UserDefaults.standard.string(forKey: Self.storageKey) ?? Theme.defaultTheme.rawValue

        if let saved = Theme(rawValue: savedRaw) {
            if saved.isProLocked && !canAccess(theme: saved) {
                currentTheme = .defaultTheme
                UserDefaults.standard.set(Theme.defaultTheme.rawValue, forKey: Self.storageKey)
                Logger.shared.logInfo("ThemeManager: tema Pro '\(saved.rawValue)' non accessibile, fallback a default")
            } else {
                currentTheme = saved
                Logger.shared.logInfo("ThemeManager: tema caricato '\(saved.rawValue)'")
            }
        } else {
            currentTheme = .defaultTheme
            Logger.shared.logInfo("ThemeManager: raw value non valido, fallback a default")
        }
    }

    // MARK: - Entitlements Bridge

    /// Stato Pro dell'utente letto dalla bridge key di IAPManager.
    var isProUser: Bool {
        UserDefaults.standard.bool(forKey: Self.proBridgeKey)
    }

    /// True se l'utente ha comprato il themes pack non-consumable.
    var hasThemesPack: Bool {
        UserDefaults.standard.bool(forKey: Self.themesPackBridgeKey)
    }

    /// True se l'utente può accedere al tema, tramite subscription Pro O
    /// tramite themes pack. I temi non Pro-locked sono sempre accessibili.
    func canAccess(theme: Theme) -> Bool {
        guard theme.isProLocked else { return true }
        return isProUser || hasThemesPack
    }

    // MARK: - Public API

    /// Imposta il tema scelto dall'utente.
    /// - Returns: `true` se applicato, `false` se bloccato (manca sia subscription
    ///   che themes pack).
    @discardableResult
    func setTheme(_ theme: Theme) -> Bool {
        if !canAccess(theme: theme) {
            Logger.shared.logInfo("ThemeManager: setTheme bloccato per '\(theme.rawValue)' (Pro o themes pack richiesto)")
            return false
        }

        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
        Logger.shared.logInfo("ThemeManager: tema impostato a '\(theme.rawValue)'")
        return true
    }
}
