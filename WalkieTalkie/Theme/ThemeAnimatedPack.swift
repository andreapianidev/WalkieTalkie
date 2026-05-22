//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemeAnimatedPack.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Pack di temi "Animated": particle effects e sfondi dinamici.
/// Prezzo singolo IAP 1,99 € (non-consumable) — alternativa alla subscription Talky Pro.
///
/// L'animazione effettiva è gestita da `AnimatedBackgroundView`, che si attiva
/// quando `themeManager.currentTheme` è uno dei tipi animati.
enum ThemeAnimatedPack {

    static func register(into dict: inout [Theme: ThemeMetadata]) {

        dict[.blackHole] = ThemeMetadata(
            accentColor: Color(red: 0.55, green: 0.20, blue: 0.85),     // #8C33D9 violetto cosmic
            displayNameKey: "theme.name.blackHole",
            iconName: "circle.dashed",
            isProLocked: true,
            productID: "app.immaginet.talky.theme.blackHole",
            priceTier: .iap199
        )

        dict[.galaxy] = ThemeMetadata(
            accentColor: Color(red: 0.25, green: 0.45, blue: 0.95),     // #4073F2 blu profondo
            displayNameKey: "theme.name.galaxy",
            iconName: "sparkles",
            isProLocked: true,
            productID: "app.immaginet.talky.theme.galaxy",
            priceTier: .iap199
        )
    }
}
