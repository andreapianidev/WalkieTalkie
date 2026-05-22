//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemeColorPack.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Pack di temi "Color": default gratuito + 4 varianti cromatiche Pro V1.
/// Si limita a registrare le proprie voci nel registry.
enum ThemeColorPack {

    static func register(into dict: inout [Theme: ThemeMetadata]) {

        // Free
        dict[.defaultTheme] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.8, blue: 0.0),   // #FFCC00 giallo classico
            displayNameKey: "theme.name.default",
            iconName: "circle.fill",
            isProLocked: false
        )

        // Pro – V1
        dict[.ocean] = ThemeMetadata(
            accentColor: Color(red: 0.0, green: 0.6, blue: 0.9),   // #0099E6
            displayNameKey: "theme.name.ocean",
            iconName: "water.waves",
            isProLocked: true
        )

        dict[.forest] = ThemeMetadata(
            accentColor: Color(red: 0.2, green: 0.7, blue: 0.3),   // #33B34D
            displayNameKey: "theme.name.forest",
            iconName: "leaf.fill",
            isProLocked: true
        )

        dict[.sunset] = ThemeMetadata(
            accentColor: Color(red: 1.0, green: 0.4, blue: 0.2),   // #FF6633
            displayNameKey: "theme.name.sunset",
            iconName: "sun.horizon.fill",
            isProLocked: true
        )

        dict[.midnight] = ThemeMetadata(
            accentColor: Color(red: 0.5, green: 0.3, blue: 0.9),   // #804DE6
            displayNameKey: "theme.name.midnight",
            iconName: "moon.stars.fill",
            isProLocked: true
        )
    }
}
