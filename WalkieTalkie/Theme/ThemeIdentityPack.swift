//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemeIdentityPack.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Pack di temi "Identity": 9 varianti con forte personalità visiva.
/// Tutti Pro-locked, ma sbloccabili anche come acquisto singolo IAP a 0,99 €
/// (non-consumable) — alternativa alla subscription Talky Pro.
/// Black Hole e Galaxy seguiranno in un pack separato con particle effects dedicati.
enum ThemeIdentityPack {

    static func register(into dict: inout [Theme: ThemeMetadata]) {

        dict[.military] = ThemeMetadata(
            accentColor: Color(red: 0.42, green: 0.50, blue: 0.20),   // #6C8033 verde oliva
            displayNameKey: "theme.name.military",
            iconName: "shield.lefthalf.filled",
            isProLocked: true,
            customFontName: "Courier New",  // placeholder army stencil feel
            soundPackID: "morse",
            productID: "app.immaginet.talky.theme.military",
            priceTier: .iap099
        )

        dict[.retro80s] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.08, blue: 0.58),    // #FF1493 magenta neon
            displayNameKey: "theme.name.retro80s",
            iconName: "sparkles",
            isProLocked: true,
            customFontName: "Courier",  // placeholder pixel-ish feel
            soundPackID: "synth",
            productID: "app.immaginet.talky.theme.retro80s",
            priceTier: .iap099
        )

        dict[.vintageRadio] = ThemeMetadata(
            accentColor: Color(red: 0.65, green: 0.42, blue: 0.20),   // #A66B33 marrone caldo
            displayNameKey: "theme.name.vintageRadio",
            iconName: "dial.high.fill",
            isProLocked: true,
            customFontName: "Georgia",  // placeholder serif vintage feel
            productID: "app.immaginet.talky.theme.vintageRadio",
            priceTier: .iap099
        )

        dict[.cyberpunk] = ThemeMetadata(
            accentColor: Color(red: 0.85, green: 0.10, blue: 0.85),   // #D91AD9 magenta cyber
            displayNameKey: "theme.name.cyberpunk",
            iconName: "bolt.fill",
            isProLocked: true,
            customFontName: "Menlo",  // placeholder tech monospace
            soundPackID: "glitch",
            productID: "app.immaginet.talky.theme.cyberpunk",
            priceTier: .iap099
        )

        dict[.stealth] = ThemeMetadata(
            accentColor: Color(red: 0.20, green: 0.20, blue: 0.22),   // #333338 nero opaco
            displayNameKey: "theme.name.stealth",
            iconName: "eye.slash.fill",
            isProLocked: true,
            productID: "app.immaginet.talky.theme.stealth",
            priceTier: .iap099
        )

        dict[.aurora] = ThemeMetadata(
            accentColor: Color(red: 0.50, green: 0.86, blue: 1.0),    // #80DBFF celeste artico
            displayNameKey: "theme.name.aurora",
            iconName: "cloud.sun.fill",
            isProLocked: true,
            productID: "app.immaginet.talky.theme.aurora",
            priceTier: .iap099
        )

        dict[.submarine] = ThemeMetadata(
            accentColor: Color(red: 0.0, green: 0.78, blue: 0.42),    // #00C76A verde sonar
            displayNameKey: "theme.name.submarine",
            iconName: "dot.radiowaves.left.and.right",
            isProLocked: true,
            soundPackID: "sonar",
            productID: "app.immaginet.talky.theme.submarine",
            priceTier: .iap099
        )

        dict[.hamRadio] = ThemeMetadata(
            accentColor: Color(red: 0.82, green: 0.41, blue: 0.12),   // #D2691E rame vintage
            displayNameKey: "theme.name.hamRadio",
            iconName: "antenna.radiowaves.left.and.right",
            isProLocked: true,
            customFontName: "Courier New",  // placeholder radio operator feel
            soundPackID: "radio",
            productID: "app.immaginet.talky.theme.hamRadio",
            priceTier: .iap099
        )

        dict[.festival] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.41, blue: 0.71),    // #FF69B4 fucsia vibrante
            displayNameKey: "theme.name.festival",
            iconName: "party.popper.fill",
            isProLocked: true,
            productID: "app.immaginet.talky.theme.festival",
            priceTier: .iap099
        )
    }
}
