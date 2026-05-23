//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemeAnimatedPack.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Pack di temi "Animated": particle effects e sfondi dinamici.
/// Tutti Pro-locked: sbloccati dalla subscription Talky Pro o dal themes pack
/// non-consumable (acquisto unico).
///
/// L'animazione effettiva è gestita da `AnimatedBackgroundView`, che si attiva
/// quando `themeManager.currentTheme` è uno dei tipi animati.
enum ThemeAnimatedPack {

    static func register(into dict: inout [Theme: ThemeMetadata]) {

        dict[.blackHole] = ThemeMetadata(
            accentColor: Color(red: 0.55, green: 0.20, blue: 0.85),     // #8C33D9 violetto cosmic
            displayNameKey: "theme.name.blackHole",
            iconName: "circle.dashed",
            isProLocked: true
        )

        dict[.galaxy] = ThemeMetadata(
            accentColor: Color(red: 0.25, green: 0.45, blue: 0.95),     // #4073F2 blu profondo
            displayNameKey: "theme.name.galaxy",
            iconName: "sparkles",
            isProLocked: true
        )
    }
}
