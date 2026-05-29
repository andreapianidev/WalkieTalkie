---
name: walkietalkie-themes
description: >
  Specialized skill for the Talky/WalkieTalkie theme system (19 themes, GPU
  shaders, custom fonts, sound packs, Pro gating). Use this when the user asks
  to add/create/new/modify/design a theme, fix theme colors, change palette,
  add animated particle backgrounds, register fonts, wire ThemeSoundManager,
  fix ThemeRegistry (which is MISSING in the codebase), add localization keys
  for themes, adjust Pro-locking logic, modify ThemeSelectorView or
  ThemePurchaseSheet, or debug theme-related build failures. Also trigger on
  phrases like "lava theme", "new animated theme", "the palette doesn't look
  right", "ThemeRegistry not found", "theme.name.hacker missing". This skill
  understands all 19 Theme enum cases, the 3 pack files (ColorPack,
  IdentityPack, AnimatedPack), the ThemeMetadata struct, the Canvas-based GPU
  particle engine in AnimatedBackgroundView, and the bridge-key Pro gating
  system. It can generate complete theme code from a natural-language
  description, dispatch parallel agents for independent tasks, and call
  frontend-design-open for design review. Use this INSTEAD of the generic
  walkietalkie-ios skill when the task is theme-specific, even partially.
---

# Talky Theme System — Skill Specializzata

Progetta, crea, modifica e debugga il sistema temi di Talky (19 temi, GPU shader, font custom, sound pack, Pro gating).

## Integrazione con Superpowers

Questa skill sfrutta le superpowers:
- **`dispatching-parallel-agents`** — per creare pack file + localizzazioni + shader in parallelo
- **`subagent-driven-development`** — per piani strutturati multi-file
- **`frontend-design-open`** — per revisione estetica delle palette generate

Non caricare tutte le reference insieme. Leggi solo quella che serve al task corrente.

---

## Reference Files

| File | Quando leggerlo |
|------|----------------|
| `references/theme-architecture.md` | Capire come funziona il sistema, risolvere bug, fare refactoring |
| `references/theme-creation-workflow.md` | Aggiungere un nuovo tema (step-by-step) |
| `references/gpu-shader-templates.md` | Creare/modificare temi animati (Canvas particle engine) |
| `references/design-guidelines.md` | Generare palette, scegliere icone, font, sound pack |

---

## Workflow: Creare un Nuovo Tema

1. **Leggi** `references/design-guidelines.md` per progettare la palette
2. **Leggi** `references/theme-creation-workflow.md` per la checklist completa
3. **Se animato** → leggi anche `references/gpu-shader-templates.md`
4. **Usa agenti paralleli** per task indipendenti:
   - Un agente scrive il pack file + enum case
   - Un agente aggiunge le localizzazioni in 5 lingue
   - Un agente scrive lo shader (se animato)
5. **Verifica** con `xcodebuild` (comando in fondo)

### PRIMA di tutto: Controlla ThemeRegistry

Il progetto ha **ThemeRegistry mancante**. È referenziato in 3 file (`Theme.swift:49`, `ThemePurchaseSheet.swift:45`, `ThemeSoundManager.swift:33,41`) ma non esiste. Se non è già stato creato, la build fallisce. Prima di fare qualunque altra cosa:

1. Crea `ThemeRegistry` (un enum con `static var registry: [Theme: ThemeMetadata]`)
2. Chiama i 3 pack `register(into:)` in un blocco `static func bootstrap()`
3. Usa `static func metadata(for theme: Theme) -> ThemeMetadata` come accessor

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

---

## Pattern di Progettazione Palette

Quando generi un tema da descrizione naturale (es. "un tema lava"), segui queste regole:

### Colori
- **Sfondo**: sempre scuro (RGB < 0.20). Se .gradient, gradientTop 10-20% più scuro di gradientBottom
- **Testo primario**: bianco o quasi bianco (0.88-1.0)
- **Testo secondario**: ~65% dell'opacità del primario
- **Accent glow**: accentColor con opacità 0.14-0.26
- **Card**: 
  - `.elevated`: surfaceColor ~2x brighter di backgroundPrimary
  - `.cyber`: surfaceColor ~1.5-2x brighter, dà effetto "vetro"
  - `.flat`: surfaceColor ~1.3x brighter, minimale

### Icone (SF Symbols)
Scegli icona tematica. Esempi dai temi esistenti:
- `water.waves`, `leaf.fill`, `sun.horizon.fill`, `moon.stars.fill`
- `shield.lefthalf.filled`, `sparkles`, `dial.high.fill`, `bolt.fill`
- `eye.slash.fill`, `cloud.sun.fill`, `dot.radiowaves.left.and.right`
- `antenna.radiowaves.left.and.right`, `party.popper.fill`
- `circle.dashed`, `terminal.fill`, `flame.fill`, `snowflake`

### Font
- Usa `nil` (system) per la maggior parte dei temi
- `"Courier New"` — militare, tecnico, industriale
- `"Courier"` — retro, vintage tech
- `"Georgia"` — elegante, naturale, classico
- `"Menlo"` — cyber, tech, moderno

### Sound Pack
- `"morse"` — militare, tattico
- `"synth"` — retrowave, synthwave
- `"glitch"` — cyberpunk, hacker
- `"sonar"` — subacqueo, radar
- `"radio"` — radioamatore, vintage radio
- `nil` — per la maggior parte dei temi

---

## Debug

### Tema non si applica
1. Controlla `UserDefaults.standard.string(forKey: "selected_theme")`
2. Controlla bridge keys: `fastboot_isProUser`, `fastboot_hasThemesPack`
3. Verifica che il case enum sia in `Theme.allCases`

### Build error: "ThemeRegistry"
C'è! È il bug noto. Crea `ThemeRegistry` come descritto sopra.

### Animazione non parte
1. `backgroundStyle == .animated` nel metadata?
2. Caso switch in `AnimatedBackgroundView.body`?
3. `reduceMotion` non sta forzando la fallback statico?

### Traduzione mancante
Le chiavi `theme.name.hacker`, `theme.name.wildfire`, `theme.name.arctic` mancano in TUTTE le 5 lingue. Vanno aggiunte.

---

## Verifica Build

```bash
xcodebuild -project "WalkieTalkie.xcodeproj" -scheme WalkieTalkie -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

---

## Riepilogo Temi Esistenti

| ID | Nome | Free/Pro | Stile sfondo | Font | Sound | Shader |
|----|------|----------|-------------|------|-------|--------|
| `default` | Default | **FREE** | `.solid` | — | — | — |
| `ocean` | Ocean | Pro | `.gradient` | — | — | — |
| `forest` | Forest | Pro | `.gradient` | — | — | — |
| `sunset` | Sunset | Pro | `.gradient` | — | — | — |
| `midnight` | Midnight | Pro | `.gradient` | — | — | — |
| `military` | Military | Pro | `.solid` | Courier New | morse | — |
| `retro80s` | Retro 80s | Pro | `.gradient` | Courier | synth | — |
| `vintageRadio` | Vintage Radio | Pro | `.solid` | Georgia | — | — |
| `cyberpunk` | Cyberpunk | Pro | `.gradient` | Menlo | glitch | — |
| `stealth` | Stealth | Pro | `.solid` | Courier New | — | — |
| `aurora` | Aurora | Pro | `.gradient` | Georgia | — | — |
| `submarine` | Submarine | Pro | `.gradient` | — | sonar | — |
| `hamRadio` | HAM Radio | Pro | `.solid` | Courier New | radio | — |
| `festival` | Festival | Pro | `.gradient` | Menlo | — | — |
| `blackHole` | Black Hole | Pro | `.animated` | — | — | 70 particelle spirale |
| `galaxy` | Galaxy | Pro | `.animated` | — | — | 110 stelle + 8 cadenti |
| `hacker` | Hacker | Pro | `.solid` | Menlo | glitch | — |
| `wildfire` | Wildfire | Pro | `.gradient` | Courier New | — | — |
| `arctic` | Arctic | Pro | `.gradient` | Georgia | — | — |
