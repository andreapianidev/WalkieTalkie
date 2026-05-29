# Theme Creation Workflow

Checklist completa per aggiungere un nuovo tema. Usa agenti paralleli per i task indipendenti.

## PREREQUISITO: ThemeRegistry

Prima di qualsiasi altra cosa, verifica che `ThemeRegistry` esista. Se manca, crealo (vedi SKILL.md).

## Step 1: Enum Theme.swift

Aggiungi il case nell'enum `Theme`:

```swift
// Nella sezione appropriata (es. Pro V3)
case lava = "lava"
```

Scegli un rawValue stabile (camelCase). Non cambiare rawValue dopo il rilascio.

## Step 2: Pack File

Scegli il pack appropriato:

| Tipo tema | Pack | Esempi |
|-----------|------|--------|
| Solo palette colori | `ThemeAnimatedPack.swift` (dove sono hacker/wildfire/arctic) | Tema statico o gradiente |
| Con personalità (font + sound) | `ThemeIdentityPack.swift` | military, cyberpunk |
| Animato (GPU shader) | `ThemeAnimatedPack.swift` | blackHole, galaxy |

Pattern di registrazione:

```swift
dict[.lava] = ThemeMetadata(
    accentColor: Color(red: 1.0, green: 0.25, blue: 0.05),
    displayNameKey: "theme.name.lava",
    iconName: "flame.fill",
    isProLocked: true,
    customFontName: nil,
    soundPackID: nil,
    backgroundPrimary: Color(red: 0.14, green: 0.04, blue: 0.02),
    surfaceColor: Color(red: 0.20, green: 0.07, blue: 0.04),
    textPrimary: Color(red: 1.0, green: 0.90, blue: 0.82),
    textSecondary: Color(red: 0.82, green: 0.45, blue: 0.30),
    backgroundStyle: .gradient,
    gradientTop: Color(red: 0.12, green: 0.03, blue: 0.01),
    gradientBottom: Color(red: 0.18, green: 0.06, blue: 0.03),
    cardStyle: .elevated,
    accentGlow: Color(red: 1.0, green: 0.25, blue: 0.05).opacity(0.22)
)
```

## Step 3: Localizzazione (5 lingue)

Aggiungi la riga in TUTTI e 5 i file `.lproj/Localizable.strings`:

```swift
"theme.name.lava" = "Lava";   // en
"theme.name.lava" = "Lava";   // it
"theme.name.lava" = "Lava";   // es
"theme.name.lava" = "Lava";   // ms
"theme.name.lava" = "熔岩";   // zh-Hant
```

### Lingue attuali
- `en.lproj/Localizable.strings` (linea ~298-313 per temi esistenti)
- `it.lproj/Localizable.strings` (stessa struttura)
- `es.lproj/Localizable.strings`
- `ms.lproj/Localizable.strings`
- `zh-Hant.lproj/Localizable.strings`

**Attenzione**: hacker, wildfire, arctic non hanno ancora chiavi. Se stai fixando questo, aggiungile anche per loro.

## Step 4: Font (se custom)

Se il tema ha `customFontName`, devi solo usare uno dei font già supportati:
- `"Courier New"`, `"Courier"`, `"Georgia"`, `"Menlo"`
- `nil` = system font

Per font nuovi: registra il file `.ttf` nel bundle e implementa `FontManager.registerCustomFonts()` (V1.1: solo system fonts — se il font non è registrato cade in fallback automatico a system font).

## Step 5: Sound Pack (se ha suoni)

Se il tema ha `soundPackID`, usa uno degli ID esistenti:
- `"morse"`, `"synth"`, `"glitch"`, `"sonar"`, `"radio"`

Se serve un nuovo sound pack:
1. Aggiungi le righe nello switch di `ThemeSoundManager.systemSound(for:event:)`
2. Usa system sound ID di AudioToolbox (codici pubblici: 1003-1521)

## Step 6: Shader Animato (se .animated)

Se `backgroundStyle == .animated`:
1. Leggi `references/gpu-shader-templates.md`
2. Aggiungi caso in `AnimatedBackgroundView.body`
3. Implementa `drawLava(context:size:time:)`
4. Aggiungi caso in `AnimatedThemePreview.body`
5. Implementa `renderLV(ctx:size:t:)`
6. Pre-calcola particelle nell'`init()` di `AnimatedBackgroundView`

### Pattern shader (da gpu-shader-templates.md)
```swift
// In body:
case .lava: lavaView

// Nuova var:
@ViewBuilder
private var lavaView: some View {
    ZStack {
        // Sfondo radiale/gradiente
        RadialGradient(...)

        if reduceMotion {
            lavaStaticOverlay
        } else {
            TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    drawLava(context: context, size: size, time: t)
                }
            }
        }
    }
}
```

## Step 7: AnimatedThemePreview (se animato)

Aggiungi caso in `AnimatedThemePreview`:

```swift
// In body:
case .lava: renderLV(ctx:ctx, size:size, t:t)

// Nuovo metodo:
private func renderLV(ctx: GraphicsContext, size: CGSize, t: Double) {
    // Implementazione light (25 particelle, 30fps)
}
```

Usa seed diverso: `srand48(0x42D0)` per il preview.

## Step 8: Verifica Build

```bash
xcodebuild -project "WalkieTalkie.xcodeproj" -scheme WalkieTalkie -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

## Checklist Finale

- [ ] Enum `Theme.swift`: case aggiunto
- [ ] Pack file: blocco `dict[.nuovoTema] = ThemeMetadata(...)` scritto
- [ ] `isProLocked` impostato correttamente
- [ ] Localizzazioni in 5 lingue
- [ ] Font custom (se necessario) — registrato o già esistente
- [ ] Sound pack (se necessario) — ID esistente o nuovo mapping
- [ ] Shader (se animato): draw function + body case + preview
- [ ] `AnimatedThemePreview` case (se animato)
- [ ] Build: `xcodebuild` non dà errori
