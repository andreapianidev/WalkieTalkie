//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - FontManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class FontManager: ObservableObject {
    static let shared = FontManager()

    /// Publisher manuale richiesto perché la classe è @MainActor-isolated
    /// e non ha @Published properties da cui sintetizzare il default.
    nonisolated let objectWillChange = ObservableObjectPublisher()

    private let logger = Logger.shared

    private init() {
        // Future: registerCustomFonts() — registers .ttf files from bundle
        // For V1.1 we use system fonts only (set via Theme.customFontName).
        logger.logInfo("FontManager inizializzato (V1.1: system fonts only)")
    }

    /// Restituisce il Font corrispondente al nome registrato, con size + weight specifici.
    /// Se `name` è nil o il font non è registrato, fallback al system font.
    func font(named name: String?, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard let name, !name.isEmpty else {
            return .system(size: size, weight: weight)
        }
        // SwiftUI Font.custom non valida l'esistenza del font: cade su system se mancante.
        return .custom(name, size: size)
    }

    /// Helper: restituisce il font del tema attualmente attivo.
    func currentThemeFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = ThemeManager.shared.currentTheme.customFontName
        return font(named: name, size: size, weight: weight)
    }
}

/// Modifier convenience: applica il font del tema corrente al testo.
struct ThemedFont: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(FontManager.shared.font(
            named: themeManager.currentTheme.customFontName,
            size: size,
            weight: weight
        ))
    }
}

extension View {
    /// Applica il font del tema attualmente attivo. Si aggiorna automaticamente al cambio tema.
    /// Esempio: `Text("Hello").themedFont(size: 18, weight: .bold)`
    func themedFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ThemedFont(size: size, weight: weight))
    }
}
