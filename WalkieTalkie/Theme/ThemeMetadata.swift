//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemeMetadata.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import SwiftUI

/// Dati immutabili che descrivono un tema: colore accent, chiave di localizzazione
/// del nome, SF Symbol per la card di anteprima, flag Pro, asset opzionali.
///
/// Mantenuto separato dall'enum `Theme` per consentire l'aggiunta di pack di temi
/// in file dedicati (vedi `ThemeColorPack`, `ThemeIdentityPack`, `ThemeAnimatedPack`).
struct ThemeMetadata {
    let accentColor: Color
    /// Chiave Localizable.strings (es. "theme.name.ocean"), risolta da `.localized` a runtime.
    let displayNameKey: String
    /// Nome SF Symbol mostrato dentro la card del selettore.
    let iconName: String
    let isProLocked: Bool

    // MARK: - Optional foundations (V1.1+)

    /// Nome PostScript del font custom da usare nel tema (es. "PressStart2P-Regular").
    /// `nil` = usa il font di sistema. Il font deve essere registrato in Info.plist (UIAppFonts)
    /// e caricato da `FontManager` prima dell'uso.
    let customFontName: String?

    /// Identificatore del pack sonoro tema (es. "morse", "sonar", "glitch").
    /// `nil` = nessun suono tematico. Gestito da `ThemeSoundManager`.
    let soundPackID: String?

    init(
        accentColor: Color,
        displayNameKey: String,
        iconName: String,
        isProLocked: Bool,
        customFontName: String? = nil,
        soundPackID: String? = nil
    ) {
        self.accentColor = accentColor
        self.displayNameKey = displayNameKey
        self.iconName = iconName
        self.isProLocked = isProLocked
        self.customFontName = customFontName
        self.soundPackID = soundPackID
    }
}

/// Registry centrale lookup-by-enum.
/// L'inizializzazione è lazy: la prima lettura concatena i contributi dei singoli pack.
enum ThemeRegistry {

    /// Dizionario popolato lazy alla prima richiesta.
    /// Ogni pack file registra le proprie voci in modo isolato.
    private static let entries: [Theme: ThemeMetadata] = {
        var dict: [Theme: ThemeMetadata] = [:]
        ThemeColorPack.register(into: &dict)
        ThemeIdentityPack.register(into: &dict)
        ThemeAnimatedPack.register(into: &dict)
        return dict
    }()

    /// Restituisce i metadati per un tema. Fallback safe al tema default
    /// nel caso in cui un pack non avesse registrato la propria entry (defensive).
    static func metadata(for theme: Theme) -> ThemeMetadata {
        if let m = entries[theme] { return m }
        return ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.8, blue: 0.0),
            displayNameKey: theme.rawValue,
            iconName: "questionmark.circle",
            isProLocked: theme != .defaultTheme
        )
    }
}
