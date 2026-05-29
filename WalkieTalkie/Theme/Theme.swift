//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - Theme.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import SwiftUI

/// Identificatore dei temi disponibili. I metadati (colore, icona, nome, lock Pro)
/// sono registrati nei pack file (`ThemeColorPack`, `ThemeIdentityPack`) per evitare
/// che questo enum diventi monolitico ad ogni nuovo tema.
enum Theme: String, CaseIterable, Codable, Identifiable {
    /// Identificatore stabile usato da SwiftUI per `sheet(item:)` e simili.
    var id: String { rawValue }

    // Core (free)
    case defaultTheme = "default"

    // Color Pack (Pro V1)
    case ocean        = "ocean"
    case forest       = "forest"
    case sunset       = "sunset"
    case midnight     = "midnight"

    // Identity Pack (Pro V1.1) — Black Hole & Galaxy seguiranno
    // come pack dedicato con particle effects (Phase 2).
    case military     = "military"
    case retro80s     = "retro80s"
    case vintageRadio = "vintageRadio"
    case cyberpunk    = "cyberpunk"
    case stealth      = "stealth"
    case aurora       = "aurora"
    case submarine    = "submarine"
    case hamRadio     = "hamRadio"
    case festival     = "festival"

    // Animated Pack (Pro V2) — particle effects, prezzo 1.99 € singolo
    case blackHole    = "blackHole"
    case galaxy       = "galaxy"

    // Pro V3 — nuovi temi con palette completa
    case hacker       = "hacker"
    case wildfire     = "wildfire"
    case arctic       = "arctic"

    // MARK: - Facade verso ThemeMetadata

    var metadata: ThemeMetadata { ThemeRegistry.metadata(for: self) }

    var accentColor: Color       { metadata.accentColor }
    var displayName: String      { metadata.displayNameKey.localized }
    var isProLocked: Bool        { metadata.isProLocked }
    var iconName: String         { metadata.iconName }
    var customFontName: String?  { metadata.customFontName }
    var soundPackID: String?     { metadata.soundPackID }

    var backgroundPrimary: Color { metadata.backgroundPrimary }
    var surfaceColor: Color      { metadata.surfaceColor }
    var textPrimary: Color       { metadata.textPrimary }
    var textSecondary: Color     { metadata.textSecondary }
    var backgroundStyle: ThemeBackgroundStyle { metadata.backgroundStyle }
    var cardStyle: ThemeCardStyle             { metadata.cardStyle }
    var gradientTop: Color?      { metadata.gradientTop }
    var gradientBottom: Color?   { metadata.gradientBottom }
    var accentGlow: Color?       { metadata.accentGlow }
}
