//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemeIdentityPack.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Pack di temi "Identity": 9 varianti con forte personalità visiva.
/// Tutti Pro-locked: sbloccati dalla subscription Talky Pro o dal themes pack
/// non-consumable (acquisto unico).
enum ThemeIdentityPack {

    static func register(into dict: inout [Theme: ThemeMetadata]) {

        dict[.military] = ThemeMetadata(
            accentColor: Color(red: 0.42, green: 0.50, blue: 0.20),   // #6C8033 verde oliva
            displayNameKey: "theme.name.military",
            iconName: "shield.lefthalf.filled",
            isProLocked: true,
            customFontName: "Courier New",
            soundPackID: "morse"
        )

        dict[.retro80s] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.08, blue: 0.58),    // #FF1493 magenta neon
            displayNameKey: "theme.name.retro80s",
            iconName: "sparkles",
            isProLocked: true,
            customFontName: "Courier",
            soundPackID: "synth"
        )

        dict[.vintageRadio] = ThemeMetadata(
            accentColor: Color(red: 0.65, green: 0.42, blue: 0.20),   // #A66B33 marrone caldo
            displayNameKey: "theme.name.vintageRadio",
            iconName: "dial.high.fill",
            isProLocked: true,
            customFontName: "Georgia"
        )

        dict[.cyberpunk] = ThemeMetadata(
            accentColor: Color(red: 0.85, green: 0.10, blue: 0.85),   // #D91AD9 magenta cyber
            displayNameKey: "theme.name.cyberpunk",
            iconName: "bolt.fill",
            isProLocked: true,
            customFontName: "Menlo",
            soundPackID: "glitch"
        )

        dict[.stealth] = ThemeMetadata(
            accentColor: Color(red: 0.20, green: 0.20, blue: 0.22),   // #333338 nero opaco
            displayNameKey: "theme.name.stealth",
            iconName: "eye.slash.fill",
            isProLocked: true
        )

        dict[.aurora] = ThemeMetadata(
            accentColor: Color(red: 0.50, green: 0.86, blue: 1.0),    // #80DBFF celeste artico
            displayNameKey: "theme.name.aurora",
            iconName: "cloud.sun.fill",
            isProLocked: true
        )

        dict[.submarine] = ThemeMetadata(
            accentColor: Color(red: 0.0, green: 0.78, blue: 0.42),    // #00C76A verde sonar
            displayNameKey: "theme.name.submarine",
            iconName: "dot.radiowaves.left.and.right",
            isProLocked: true,
            soundPackID: "sonar"
        )

        dict[.hamRadio] = ThemeMetadata(
            accentColor: Color(red: 0.82, green: 0.41, blue: 0.12),   // #D2691E rame vintage
            displayNameKey: "theme.name.hamRadio",
            iconName: "antenna.radiowaves.left.and.right",
            isProLocked: true,
            customFontName: "Courier New",
            soundPackID: "radio"
        )

        dict[.festival] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.41, blue: 0.71),    // #FF69B4 fucsia vibrante
            displayNameKey: "theme.name.festival",
            iconName: "party.popper.fill",
            isProLocked: true
        )
    }
}
