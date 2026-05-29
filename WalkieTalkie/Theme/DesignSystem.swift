//  DesignSystem.swift
//  WalkieTalkie
//
//  Token design Avo cross-tema. I temi consumano questi token; ogni tema
//  ridefinisce la propria palette, non si hard-codano valori inline.

import SwiftUI

// MARK: - Spacing Scale

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat  = 8
    static let sm: CGFloat  = 12
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 20
    static let xl: CGFloat  = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Radius Scale

enum AppRadius {
    static let chip: CGFloat  = 8
    static let card: CGFloat  = 14
    static let sheet: CGFloat = 20
    static let pill: CGFloat  = 28
}

// MARK: - Motion Presets

enum AppMotion {
    static let snappy = Animation.spring(response: 0.30, dampingFraction: 0.75)
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let bouncy = Animation.spring(response: 0.55, dampingFraction: 0.65)

    static func defaultReduceMotion(_ reduce: Bool) -> Animation {
        reduce ? .easeInOut(duration: 0.2) : smooth
    }
}

// MARK: - Typography Tokens

enum AppFont {
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func heading(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func mono(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

// MARK: - Cyber Palette (per temi dark)

enum CyberPalette {
    static let surfaceTop    = Color(red: 0.12, green: 0.16, blue: 0.21)
    static let surfaceBottom = Color(red: 0.07, green: 0.10, blue: 0.14)
    static let border        = Color.white.opacity(0.10)
    static let divider       = Color.white.opacity(0.06)
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textTertiary  = Color.white.opacity(0.45)
}

// MARK: - Shadow Tokens

enum AppShadow {
    static let card     = (color: Color.black.opacity(0.08), radius: CGFloat(10), y: CGFloat(2))
    static let elevated = (color: Color.black.opacity(0.12), radius: CGFloat(16), y: CGFloat(4))
    static let cyber    = (color: Color.black.opacity(0.50), radius: CGFloat(18), y: CGFloat(6))
}
