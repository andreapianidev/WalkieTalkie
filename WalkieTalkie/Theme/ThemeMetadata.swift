//  ThemeMetadata.swift
//  WalkieTalkie

import SwiftUI

/// Identità visiva completa di un tema. Ogni tema definisce non solo il colore
/// d'accento ma l'intera palette: background, superficie, testo, chrome card.
struct ThemeMetadata {
    let accentColor: Color
    let displayNameKey: String
    let iconName: String
    let isProLocked: Bool

    var customFontName: String? = nil
    var soundPackID: String? = nil

    // MARK: - Palette Completa

    /// Sfondo principale dell'app (schermata intera, sotto le card)
    var backgroundPrimary: Color = Color(red: 0.07, green: 0.07, blue: 0.09)

    /// Superficie delle card / container elevati
    var surfaceColor: Color = Color(red: 0.12, green: 0.12, blue: 0.15)

    /// Colore testo primario
    var textPrimary: Color = .white

    /// Colore testo secondario
    var textSecondary: Color = Color.white.opacity(0.65)

    /// Stile di sfondo: statico (.solid), gradiente (.gradient), o animato (.animated)
    var backgroundStyle: ThemeBackgroundStyle = .solid

    /// Per .gradient: colore top del gradiente
    var gradientTop: Color? = nil

    /// Per .gradient: colore bottom del gradiente
    var gradientBottom: Color? = nil

    /// Stile delle card: piatte (.flat), elevate con ombra (.elevated), cyber (.cyber)
    var cardStyle: ThemeCardStyle = .elevated

    /// Glow / alone attorno agli elementi accent (per temi dark/cyber)
    var accentGlow: Color? = nil
}

// MARK: - Background Style

enum ThemeBackgroundStyle: String, Codable {
    case solid
    case gradient
    case animated
}

// MARK: - Card Style

enum ThemeCardStyle: String, Codable {
    /// Sfondo piatto senza ombra
    case flat
    /// Sfondo con ombra elevata standard
    case elevated
    /// Sfondo cyber con gradiente verticale + stroke bianco 10% + ombra nera 50%
    case cyber
}
