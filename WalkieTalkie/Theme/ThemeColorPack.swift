//  ThemeColorPack.swift
//  WalkieTalkie

import SwiftUI

/// Pack di temi "Color": default gratuito + 4 varianti cromatiche Pro V1.
/// Ogni tema ora definisce palette completa: background, superficie, testo, stile card.
enum ThemeColorPack {

    static func register(into dict: inout [Theme: ThemeMetadata]) {

        // MARK: - Default (Free)

        dict[.defaultTheme] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.8, blue: 0.0),
            displayNameKey: "theme.name.default",
            iconName: "circle.fill",
            isProLocked: false,
            backgroundPrimary: Color(red: 0.08, green: 0.08, blue: 0.10),
            surfaceColor: Color(red: 0.14, green: 0.14, blue: 0.17),
            textPrimary: .white,
            textSecondary: Color.white.opacity(0.65),
            backgroundStyle: .solid,
            cardStyle: .elevated,
            accentGlow: Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.22)
        )

        // MARK: - Ocean (Pro)

        dict[.ocean] = ThemeMetadata(
            accentColor: Color(red: 0.0, green: 0.6, blue: 0.9),
            displayNameKey: "theme.name.ocean",
            iconName: "water.waves",
            isProLocked: true,
            backgroundPrimary: Color(red: 0.03, green: 0.08, blue: 0.16),
            surfaceColor: Color(red: 0.06, green: 0.14, blue: 0.26),
            textPrimary: Color(red: 0.90, green: 0.95, blue: 1.0),
            textSecondary: Color(red: 0.65, green: 0.78, blue: 0.92),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.02, green: 0.06, blue: 0.14),
            gradientBottom: Color(red: 0.05, green: 0.12, blue: 0.22),
            cardStyle: .cyber,
            accentGlow: Color(red: 0.0, green: 0.6, blue: 0.9).opacity(0.20)
        )

        // MARK: - Forest (Pro)

        dict[.forest] = ThemeMetadata(
            accentColor: Color(red: 0.2, green: 0.7, blue: 0.3),
            displayNameKey: "theme.name.forest",
            iconName: "leaf.fill",
            isProLocked: true,
            backgroundPrimary: Color(red: 0.04, green: 0.10, blue: 0.06),
            surfaceColor: Color(red: 0.08, green: 0.16, blue: 0.10),
            textPrimary: Color(red: 0.90, green: 0.97, blue: 0.92),
            textSecondary: Color(red: 0.60, green: 0.78, blue: 0.65),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.03, green: 0.08, blue: 0.05),
            gradientBottom: Color(red: 0.06, green: 0.14, blue: 0.08),
            cardStyle: .elevated,
            accentGlow: Color(red: 0.2, green: 0.7, blue: 0.3).opacity(0.18)
        )

        // MARK: - Sunset (Pro)

        dict[.sunset] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.4, blue: 0.2),
            displayNameKey: "theme.name.sunset",
            iconName: "sun.horizon.fill",
            isProLocked: true,
            backgroundPrimary: Color(red: 0.14, green: 0.06, blue: 0.04),
            surfaceColor: Color(red: 0.20, green: 0.10, blue: 0.06),
            textPrimary: Color(red: 1.0, green: 0.94, blue: 0.90),
            textSecondary: Color(red: 0.85, green: 0.65, blue: 0.55),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.12, green: 0.05, blue: 0.03),
            gradientBottom: Color(red: 0.18, green: 0.08, blue: 0.05),
            cardStyle: .elevated,
            accentGlow: Color(red: 1.0, green: 0.4, blue: 0.2).opacity(0.20)
        )

        // MARK: - Midnight (Pro)

        dict[.midnight] = ThemeMetadata(
            accentColor: Color(red: 0.5, green: 0.3, blue: 0.9),
            displayNameKey: "theme.name.midnight",
            iconName: "moon.stars.fill",
            isProLocked: true,
            backgroundPrimary: Color(red: 0.06, green: 0.04, blue: 0.14),
            surfaceColor: Color(red: 0.10, green: 0.07, blue: 0.22),
            textPrimary: Color(red: 0.92, green: 0.90, blue: 1.0),
            textSecondary: Color(red: 0.62, green: 0.58, blue: 0.82),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.04, green: 0.03, blue: 0.12),
            gradientBottom: Color(red: 0.08, green: 0.05, blue: 0.18),
            cardStyle: .cyber,
            accentGlow: Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.22)
        )
    }
}
