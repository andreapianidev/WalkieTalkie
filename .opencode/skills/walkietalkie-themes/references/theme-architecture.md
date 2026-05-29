# Theme System Architecture

## Panoramica

Il sistema temi usa un'architettura a **pack registrati** con **facade pattern**. L'enum `Theme` è solo un identificatore — non contiene dati. I dati sono registrati in pack separati e aggregati da `ThemeRegistry`.

```
Theme (enum: 19 cases)
  │
  ├── facade metadata → ThemeRegistry.metadata(for:)
  │     └── lazy static [Theme: ThemeMetadata]
  │           ├── ThemeColorPack.register(into:)   (5 temi: default, ocean, forest, sunset, midnight)
  │           ├── ThemeIdentityPack.register(into:)  (9 temi: military..festival)
  │           └── ThemeAnimatedPack.register(into:)  (5 temi: blackHole, galaxy, hacker, wildfire, arctic)
  │
  └── consumato da:
        ├── ThemeManager.shared (persistenza + Pro gating)
        ├── ThemeSelectorView (grid UI)
        ├── ThemePurchaseSheet (paywall pack)
        ├── FontManager (font custom)
        ├── ThemeSoundManager (sound pack)
        └── AnimatedBackgroundView (GPU shader)
```

## ThemeRegistry (MANCANTE — va creato)

Referenziato in 3 file ma non esiste. Schema necessario:

```swift
enum ThemeRegistry {
    private static var registry: [Theme: ThemeMetadata] = {
        var dict: [Theme: ThemeMetadata] = [:]
        ThemeColorPack.register(into: &dict)
        ThemeIdentityPack.register(into: &dict)
        ThemeAnimatedPack.register(into: &dict)
        return dict
    }()

    static func metadata(for theme: Theme) -> ThemeMetadata {
        guard let meta = registry[theme] else {
            fatalError("ThemeRegistry: missing metadata for \(theme.rawValue)")
        }
        return meta
    }
}
```

## File del Sistema Temi

| File | Ruolo | Dipende da |
|------|-------|-----------|
| `Theme/Theme.swift` | Enum 19 casi + facade properties | ThemeRegistry |
| `Theme/ThemeMetadata.swift` | Struct dati tema + enum style | — |
| `Theme/ThemeColorPack.swift` | Registra 5 temi (1 free + 4 Pro V1) | ThemeMetadata |
| `Theme/ThemeIdentityPack.swift` | Registra 9 temi (Pro V1.1) | ThemeMetadata |
| `Theme/ThemeAnimatedPack.swift` | Registra 5 temi (Pro V2 + V3) | ThemeMetadata |
| `Theme/ThemeManager.swift` | Singleton, persistenza, Pro gate | Bridge keys UserDefaults |
| `Theme/ThemeSelectorView.swift` | Grid 2-col con card, badge PRO, tap | ThemeManager |
| `Theme/ThemePurchaseSheet.swift` | Paywall one-shot themes pack | IAPManager, Firebase |
| `Theme/FontManager.swift` | Font registry + ThemedFont modifier | ThemeManager |
| `Theme/ThemeSoundManager.swift` | Suoni tematici per evento | ThemeManager, ThemeRegistry |
| `Theme/AnimatedBackgroundView.swift` | Canvas particle engine (60fps) | ThemeManager |
| `Theme/DesignSystem.swift` | Token: AppSpacing, AppRadius, AppMotion, AppFont, CyberPalette, AppShadow | — |

## ThemeMetadata

```swift
struct ThemeMetadata {
    // Required
    let accentColor: Color
    let displayNameKey: String      // "theme.name.<case>"
    let iconName: String            // SF Symbol name
    let isProLocked: Bool

    // Optional (with defaults)
    var customFontName: String?     // nil = system font
    var soundPackID: String?        // nil = no sounds

    // Palette (with dark defaults)
    var backgroundPrimary: Color    // default: rgb(0.07, 0.07, 0.09)
    var surfaceColor: Color         // default: rgb(0.12, 0.12, 0.15)
    var textPrimary: Color          // default: .white
    var textSecondary: Color        // default: white 65%

    // Style
    var backgroundStyle: ThemeBackgroundStyle  // .solid / .gradient / .animated
    var cardStyle: ThemeCardStyle              // .flat / .elevated / .cyber

    // Gradient (se .gradient)
    var gradientTop: Color?
    var gradientBottom: Color?

    // Glow
    var accentGlow: Color?
}
```

## Pro Gating

Due meccanismi indipendenti (uno basta per sbloccare):

1. **Subscription Pro** → bridge key `fastboot_isProUser` (scritta da IAPManager)
2. **Themes Pack** → bridge key `fastboot_hasThemesPack` (non-consumable one-shot)

`ThemeManager.canAccess(theme:)`:
```swift
guard theme.isProLocked else { return true }
return isProUser || hasThemesPack
```

## Persistenza

- `UserDefaults.standard.string(forKey: "selected_theme")` — rawValue del tema attivo
- `ThemeManager.shared.currentTheme` — `@Published` osservato da tutte le view

## Flow tipico: Utente seleziona tema

1. Tap in `ThemeSelectorView.handleTap(on:)`
2. `ThemeManager.setTheme(theme)` → controlla `canAccess()`
3. Se bloccato → callback `onLockedTap` → apre `ThemePurchaseSheet`
4. Se OK → salva in UserDefaults, aggiorna `@Published currentTheme`
5. SwiftUI reagisce: tutte le view osservano `currentTheme` cambiano palette
