//  ThemeRegistry.swift
//  WalkieTalkie

import SwiftUI

/// Punto di accesso centralizzato ai metadati di tutti i temi.
/// Aggrega i registrations di `ThemeColorPack`, `ThemeIdentityPack` e
/// `ThemeAnimatedPack` in un unico dizionario lazy, poi esposto via
/// `ThemeRegistry.metadata(for:)`.
///
/// Progettato per tenere Theme.swift snello: l'enum chiama
/// `ThemeRegistry.metadata(for: self)` e delega il lookup al registry.
enum ThemeRegistry {

    private static var cache: [Theme: ThemeMetadata] = {
        var dict = [Theme: ThemeMetadata]()
        ThemeColorPack.register(into: &dict)
        ThemeIdentityPack.register(into: &dict)
        ThemeAnimatedPack.register(into: &dict)
        return dict
    }()

    /// Restituisce i metadati completi per un tema.
    /// Fallback safe: se un tema non fosse registrato (non dovrebbe mai
    /// accadere) genera un placeholder visibile per debug.
    static func metadata(for theme: Theme) -> ThemeMetadata {
        guard let meta = cache[theme] else {
            return ThemeMetadata(
                accentColor: .gray,
                displayNameKey: "theme.name.\(theme.rawValue)",
                iconName: "questionmark.circle",
                isProLocked: false
            )
        }
        return meta
    }
}
