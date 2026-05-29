//  ThemeIdentityPack.swift
//  WalkieTalkie

import SwiftUI

/// Pack di temi "Identity": 9 varianti con forte personalità visiva.
/// Ogni tema ora ha palette completa: sfondo, superficie, testo, stile card, glow.
enum ThemeIdentityPack {

    static func register(into dict: inout [Theme: ThemeMetadata]) {

        // MARK: - Military

        dict[.military] = ThemeMetadata(
            accentColor: Color(red: 0.42, green: 0.50, blue: 0.20),
            displayNameKey: "theme.name.military",
            iconName: "shield.lefthalf.filled",
            isProLocked: true,
            customFontName: "Courier New",
            soundPackID: "morse",
            backgroundPrimary: Color(red: 0.06, green: 0.08, blue: 0.05),
            surfaceColor: Color(red: 0.10, green: 0.13, blue: 0.08),
            textPrimary: Color(red: 0.88, green: 0.92, blue: 0.84),
            textSecondary: Color(red: 0.55, green: 0.62, blue: 0.48),
            backgroundStyle: .solid,
            cardStyle: .flat,
            accentGlow: Color(red: 0.42, green: 0.50, blue: 0.20).opacity(0.14)
        )

        // MARK: - Retro 80s

        dict[.retro80s] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.08, blue: 0.58),
            displayNameKey: "theme.name.retro80s",
            iconName: "sparkles",
            isProLocked: true,
            customFontName: "Courier",
            soundPackID: "synth",
            backgroundPrimary: Color(red: 0.10, green: 0.02, blue: 0.12),
            surfaceColor: Color(red: 0.16, green: 0.04, blue: 0.18),
            textPrimary: Color(red: 0.98, green: 0.85, blue: 1.0),
            textSecondary: Color(red: 0.75, green: 0.40, blue: 0.85),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.08, green: 0.01, blue: 0.10),
            gradientBottom: Color(red: 0.14, green: 0.03, blue: 0.16),
            cardStyle: .cyber,
            accentGlow: Color(red: 1.0, green: 0.08, blue: 0.58).opacity(0.24)
        )

        // MARK: - Vintage Radio

        dict[.vintageRadio] = ThemeMetadata(
            accentColor: Color(red: 0.65, green: 0.42, blue: 0.20),
            displayNameKey: "theme.name.vintageRadio",
            iconName: "dial.high.fill",
            isProLocked: true,
            customFontName: "Georgia",
            backgroundPrimary: Color(red: 0.10, green: 0.07, blue: 0.04),
            surfaceColor: Color(red: 0.15, green: 0.10, blue: 0.06),
            textPrimary: Color(red: 0.94, green: 0.88, blue: 0.78),
            textSecondary: Color(red: 0.60, green: 0.48, blue: 0.35),
            backgroundStyle: .solid,
            cardStyle: .elevated,
            accentGlow: Color(red: 0.65, green: 0.42, blue: 0.20).opacity(0.16)
        )

        // MARK: - Cyberpunk

        dict[.cyberpunk] = ThemeMetadata(
            accentColor: Color(red: 0.85, green: 0.10, blue: 0.85),
            displayNameKey: "theme.name.cyberpunk",
            iconName: "bolt.fill",
            isProLocked: true,
            customFontName: "Menlo",
            soundPackID: "glitch",
            backgroundPrimary: Color(red: 0.05, green: 0.02, blue: 0.10),
            surfaceColor: Color(red: 0.10, green: 0.04, blue: 0.16),
            textPrimary: Color(red: 0.90, green: 0.95, blue: 1.0),
            textSecondary: Color(red: 0.60, green: 0.40, blue: 0.85),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.04, green: 0.01, blue: 0.08),
            gradientBottom: Color(red: 0.08, green: 0.03, blue: 0.14),
            cardStyle: .cyber,
            accentGlow: Color(red: 0.85, green: 0.10, blue: 0.85).opacity(0.25)
        )

        // MARK: - Stealth

        dict[.stealth] = ThemeMetadata(
            accentColor: Color(red: 0.20, green: 0.20, blue: 0.22),
            displayNameKey: "theme.name.stealth",
            iconName: "eye.slash.fill",
            isProLocked: true,
            customFontName: "Courier New",
            backgroundPrimary: Color(red: 0.03, green: 0.03, blue: 0.04),
            surfaceColor: Color(red: 0.08, green: 0.08, blue: 0.09),
            textPrimary: Color(red: 0.75, green: 0.75, blue: 0.78),
            textSecondary: Color(red: 0.40, green: 0.40, blue: 0.42),
            backgroundStyle: .solid,
            cardStyle: .flat,
            accentGlow: nil
        )

        // MARK: - Aurora

        dict[.aurora] = ThemeMetadata(
            accentColor: Color(red: 0.50, green: 0.86, blue: 1.0),
            displayNameKey: "theme.name.aurora",
            iconName: "cloud.sun.fill",
            isProLocked: true,
            customFontName: "Georgia",
            backgroundPrimary: Color(red: 0.04, green: 0.08, blue: 0.14),
            surfaceColor: Color(red: 0.08, green: 0.14, blue: 0.22),
            textPrimary: Color(red: 0.88, green: 0.96, blue: 1.0),
            textSecondary: Color(red: 0.55, green: 0.72, blue: 0.88),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.02, green: 0.06, blue: 0.12),
            gradientBottom: Color(red: 0.06, green: 0.12, blue: 0.20),
            cardStyle: .elevated,
            accentGlow: Color(red: 0.50, green: 0.86, blue: 1.0).opacity(0.18)
        )

        // MARK: - Submarine

        dict[.submarine] = ThemeMetadata(
            accentColor: Color(red: 0.0, green: 0.78, blue: 0.42),
            displayNameKey: "theme.name.submarine",
            iconName: "dot.radiowaves.left.and.right",
            isProLocked: true,
            soundPackID: "sonar",
            backgroundPrimary: Color(red: 0.02, green: 0.08, blue: 0.06),
            surfaceColor: Color(red: 0.04, green: 0.14, blue: 0.10),
            textPrimary: Color(red: 0.82, green: 0.98, blue: 0.90),
            textSecondary: Color(red: 0.45, green: 0.72, blue: 0.58),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.01, green: 0.06, blue: 0.04),
            gradientBottom: Color(red: 0.03, green: 0.12, blue: 0.08),
            cardStyle: .cyber,
            accentGlow: Color(red: 0.0, green: 0.78, blue: 0.42).opacity(0.20)
        )

        // MARK: - Ham Radio

        dict[.hamRadio] = ThemeMetadata(
            accentColor: Color(red: 0.82, green: 0.41, blue: 0.12),
            displayNameKey: "theme.name.hamRadio",
            iconName: "antenna.radiowaves.left.and.right",
            isProLocked: true,
            customFontName: "Courier New",
            soundPackID: "radio",
            backgroundPrimary: Color(red: 0.08, green: 0.06, blue: 0.04),
            surfaceColor: Color(red: 0.14, green: 0.10, blue: 0.06),
            textPrimary: Color(red: 0.94, green: 0.88, blue: 0.78),
            textSecondary: Color(red: 0.60, green: 0.46, blue: 0.32),
            backgroundStyle: .solid,
            cardStyle: .elevated,
            accentGlow: Color(red: 0.82, green: 0.41, blue: 0.12).opacity(0.16)
        )

        // MARK: - Festival

        dict[.festival] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.41, blue: 0.71),
            displayNameKey: "theme.name.festival",
            iconName: "party.popper.fill",
            isProLocked: true,
            customFontName: "Menlo",
            backgroundPrimary: Color(red: 0.12, green: 0.04, blue: 0.10),
            surfaceColor: Color(red: 0.18, green: 0.07, blue: 0.15),
            textPrimary: Color(red: 1.0, green: 0.90, blue: 0.97),
            textSecondary: Color(red: 0.80, green: 0.50, blue: 0.72),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.10, green: 0.03, blue: 0.08),
            gradientBottom: Color(red: 0.16, green: 0.05, blue: 0.13),
            cardStyle: .cyber,
            accentGlow: Color(red: 1.0, green: 0.41, blue: 0.71).opacity(0.22)
        )
    }
}
