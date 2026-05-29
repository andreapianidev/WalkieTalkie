//  ThemeAnimatedPack.swift
//  WalkieTalkie

import SwiftUI

/// Pack di temi "Animated": particle effects e sfondi dinamici.
/// Ora con palette completa per coerenza visiva tra sfondo animato e UI.
enum ThemeAnimatedPack {

    static func register(into dict: inout [Theme: ThemeMetadata]) {

        // MARK: - Black Hole

        dict[.blackHole] = ThemeMetadata(
            accentColor: Color(red: 0.55, green: 0.20, blue: 0.85),
            displayNameKey: "theme.name.blackHole",
            iconName: "circle.dashed",
            isProLocked: true,
            backgroundPrimary: Color(red: 0.06, green: 0.02, blue: 0.12),
            surfaceColor: Color(red: 0.10, green: 0.04, blue: 0.18),
            textPrimary: Color(red: 0.90, green: 0.82, blue: 1.0),
            textSecondary: Color(red: 0.58, green: 0.40, blue: 0.82),
            backgroundStyle: .animated,
            cardStyle: .cyber,
            accentGlow: Color(red: 0.55, green: 0.20, blue: 0.85).opacity(0.26)
        )

        // MARK: - Galaxy

        dict[.galaxy] = ThemeMetadata(
            accentColor: Color(red: 0.25, green: 0.45, blue: 0.95),
            displayNameKey: "theme.name.galaxy",
            iconName: "sparkles",
            isProLocked: true,
            backgroundPrimary: Color(red: 0.02, green: 0.03, blue: 0.10),
            surfaceColor: Color(red: 0.05, green: 0.07, blue: 0.18),
            textPrimary: Color(red: 0.88, green: 0.94, blue: 1.0),
            textSecondary: Color(red: 0.55, green: 0.68, blue: 0.92),
            backgroundStyle: .animated,
            cardStyle: .cyber,
            accentGlow: Color(red: 0.25, green: 0.45, blue: 0.95).opacity(0.22)
        )

        // MARK: - Hacker (NEW Pro V3)

        dict[.hacker] = ThemeMetadata(
            accentColor: Color(red: 0.0, green: 1.0, blue: 0.2),
            displayNameKey: "theme.name.hacker",
            iconName: "terminal.fill",
            isProLocked: true,
            customFontName: "Menlo",
            soundPackID: "glitch",
            backgroundPrimary: Color(red: 0.02, green: 0.06, blue: 0.02),
            surfaceColor: Color(red: 0.04, green: 0.10, blue: 0.04),
            textPrimary: Color(red: 0.75, green: 1.0, blue: 0.78),
            textSecondary: Color(red: 0.35, green: 0.75, blue: 0.40),
            backgroundStyle: .solid,
            cardStyle: .flat,
            accentGlow: Color(red: 0.0, green: 1.0, blue: 0.2).opacity(0.18)
        )

        // MARK: - Wildfire (NEW Pro V3)

        dict[.wildfire] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.35, blue: 0.05),
            displayNameKey: "theme.name.wildfire",
            iconName: "flame.fill",
            isProLocked: true,
            customFontName: "Courier New",
            backgroundPrimary: Color(red: 0.14, green: 0.04, blue: 0.02),
            surfaceColor: Color(red: 0.20, green: 0.07, blue: 0.04),
            textPrimary: Color(red: 1.0, green: 0.92, blue: 0.85),
            textSecondary: Color(red: 0.85, green: 0.50, blue: 0.35),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.12, green: 0.03, blue: 0.01),
            gradientBottom: Color(red: 0.18, green: 0.06, blue: 0.03),
            cardStyle: .elevated,
            accentGlow: Color(red: 1.0, green: 0.35, blue: 0.05).opacity(0.22)
        )

        // MARK: - Arctic (NEW Pro V3)

        dict[.arctic] = ThemeMetadata(
            accentColor: Color(red: 0.55, green: 0.90, blue: 0.98),
            displayNameKey: "theme.name.arctic",
            iconName: "snowflake",
            isProLocked: true,
            customFontName: "Georgia",
            backgroundPrimary: Color(red: 0.06, green: 0.10, blue: 0.16),
            surfaceColor: Color(red: 0.10, green: 0.16, blue: 0.24),
            textPrimary: Color(red: 0.88, green: 0.94, blue: 1.0),
            textSecondary: Color(red: 0.58, green: 0.72, blue: 0.85),
            backgroundStyle: .gradient,
            gradientTop: Color(red: 0.04, green: 0.08, blue: 0.14),
            gradientBottom: Color(red: 0.08, green: 0.14, blue: 0.22),
            cardStyle: .cyber,
            accentGlow: Color(red: 0.55, green: 0.90, blue: 0.98).opacity(0.16)
        )
    }
}
