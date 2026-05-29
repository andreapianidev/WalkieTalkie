# GPU Shader Templates — Canvas Particle Engine

Il sistema di animazione usa `TimelineView` + `Canvas` (CoreGraphics path-based) per il rendering a 60fps. Nessuna SwiftUI View per particella — tutto è disegnato con path.

## Architettura

```
AnimatedBackgroundView
  ├── init() — pre-alloca particelle (deterministico tramite srand48)
  ├── body — switch su themeManager.currentTheme
  │     ├── .blackHole → blackHoleView
  │     ├── .galaxy → galaxyView
  │     └── default → gradient o solid
  │
  └── drawBlackHole / drawGalaxy — funzioni Canvas rendering

AnimatedThemePreview (card nel selector)
  ├── init(theme:) — 25 particelle, 30fps, seed separato
  ├── body — switch su theme
  └── renderBH / renderGX — light renderer
```

## Particle Models

```swift
struct ParticleSeed {
    let baseAngle: Double      // angolo iniziale (rad)
    let baseRadius: Double     // raggio normalizzato 0..1
    let speed: Double          // moltiplicatore velocità
    let size: Double           // dimensione pixel
    let brightness: Double     // 0..1
    let phase: Double          // offset fase per twinkle/drift
}

struct ShootingStar {
    let startX, startY: Double     // posizione normalizzata
    let angle: Double              // direzione (rad)
    let length: Double             // lunghezza coda
    let speed, activationTime, duration: Double
}
```

## Pattern 1: Orbita Spirale (Black Hole)

Particelle che orbitano verso il centro con fade-out all'event horizon.

```swift
private func drawBlackHole(context: GraphicsContext, size: CGSize, time: Double) {
    let cx = size.width / 2
    let cy = size.height / 2
    let maxR = min(size.width, size.height) * 0.48
    let eventHorizon = maxR * 0.12

    for p in blackHoleParticles {
        let cycle = (time * p.speed * 0.12 + p.phase / (.pi * 2))
            .truncatingRemainder(dividingBy: 1.0)
        let lifeOutToIn = 1.0 - cycle
        let r = lifeOutToIn * maxR * p.baseRadius + eventHorizon * 0.4

        let angularSpeed = 0.6 + (maxR / max(r, eventHorizon * 0.5)) * 0.05
        let angle = p.baseAngle + time * angularSpeed * p.speed

        let x = cx + CGFloat(cos(angle) * r)
        let y = cy + CGFloat(sin(angle) * r)

        let normR = (r - eventHorizon) / max(maxR - eventHorizon, 1)
        let alpha = max(0.0, min(1.0, normR)) * p.brightness

        let particleSize = CGFloat(p.size * (0.6 + normR * 0.6))
        let rect = CGRect(x: x - particleSize/2, y: y - particleSize/2,
                          width: particleSize, height: particleSize)
        let color = Color(red: 0.75 + 0.2 * p.brightness,
                          green: 0.55 + 0.2 * p.brightness,
                          blue: 0.95).opacity(alpha)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    // Glow + event horizon disk
    drawEventHorizonGlow(context: context, center: CGPoint(x: cx, y: cy),
                         eventHorizon: eventHorizon)
}
```

### Quando usarlo
- Tema "cosmico" o "energetico" con movimento centripeto
- Black Hole, Vortex, Singularity, Nebula

## Pattern 2: Stelle Twinkle + Drift (Galaxy)

Stelle con scintillio sinusoidale, micro-drift orizzontale, e stelle cadenti.

```swift
private func drawGalaxy(context: GraphicsContext, size: CGSize, time: Double) {
    for star in galaxyStars {
        let baseX = star.baseAngle / (.pi * 2)
        let drift = sin(time * star.speed + star.phase) * 0.01
        let x = ((baseX + drift).truncatingRemainder(dividingBy: 1.0) + 1.0)
            .truncatingRemainder(dividingBy: 1.0) * size.width
        let y = CGFloat(star.baseRadius) * size.height

        let twinkle = 0.65 + 0.35 * sin(time * (1.2 + star.speed * 4) + star.phase)
        let alpha = star.brightness * twinkle
        let s = CGFloat(star.size)
        let rect = CGRect(x: x - s/2, y: y - s/2, width: s, height: s)

        let color: Color = star.size > 1.8
            ? Color(red: 1.0, green: 0.95, blue: 0.85).opacity(alpha)
            : Color.white.opacity(alpha)

        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    // Shooting stars (ciclo di ~32s)
    drawShootingStars(context: context, size: size, time: time)
}
```

### Shooting Stars
```swift
private func drawShootingStars(context: GraphicsContext, size: CGSize, time: Double) {
    let cycleLength: Double = 32.0
    let localTime = time.truncatingRemainder(dividingBy: cycleLength)

    for shoot in shootingStars {
        let elapsed = localTime - shoot.activationTime
        guard elapsed >= 0, elapsed <= shoot.duration else { continue }

        let progress = elapsed / shoot.duration
        let travel = progress * shoot.speed
        let cx = (shoot.startX + cos(shoot.angle) * travel) * size.width
        let cy = (shoot.startY + sin(shoot.angle) * travel) * size.height
        let tailLen = shoot.length * Double(size.width)
        let tx = cx - CGFloat(cos(shoot.angle) * tailLen)
        let ty = cy - CGFloat(sin(shoot.angle) * tailLen)

        let alpha: Double = {
            if progress < 0.2 { return progress / 0.2 }
            if progress > 0.8 { return (1.0 - progress) / 0.2 }
            return 1.0
        }()

        var path = Path()
        path.move(to: CGPoint(x: tx, y: ty))
        path.addLine(to: CGPoint(x: cx, y: cy))
        context.stroke(path, with: .linearGradient(
            Gradient(colors: [.white.opacity(0), .white.opacity(alpha)]),
            startPoint: CGPoint(x: tx, y: ty),
            endPoint: CGPoint(x: cx, y: cy)
        ), lineWidth: 1.6)

        let headRect = CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4)
        context.fill(Path(ellipseIn: headRect), with: .color(.white.opacity(alpha)))
    }
}
```

### Quando usarlo
- Tema "spaziale" o "cielo stellato"
- Galaxy, Starlight, Cosmos, Night Sky

## Pattern 3: Onda Fluida — NUOVO

Per temi con movimento ondulatorio (acqua, lava, plasma).

```swift
// Pre-calcola in init():
// amplitude, frequency, speed, phase per ogni onda
private struct WaveParticle {
    let x: Double           // posizione X normalizzata
    let baseY: Double       // posizione Y base
    let amplitude: Double   // ampiezza oscillazione
    let frequency: Double   // frequenza
    let speed: Double       // velocità
    let phase: Double       // fase
    let size: Double
    let color: Color
}

private func drawWaves(context: GraphicsContext, size: CGSize, time: Double) {
    for wave in waveParticles {
        let y = wave.baseY + sin(time * wave.speed + wave.x * wave.frequency + wave.phase) * wave.amplitude
        let xPos = wave.x * size.width
        let yPos = y * size.height

        let rect = CGRect(x: xPos - wave.size/2, y: yPos - wave.size/2,
                          width: wave.size, height: wave.size)
        context.fill(Path(ellipseIn: rect), with: .color(wave.color))
    }
}
```

### Quando usarlo
- Lava, Ocean (animated), Aurora (animated), Plasma, Neon River

## Pattern 4: Nebbia / Particelle Float — NUOVO

Particelle che fluttuano lentamente con drift browniano.

```swift
private struct FogParticle {
    let x: Double
    let y: Double
    let driftX: Double
    let driftY: Double
    let speed: Double
    let size: Double
    let opacity: Double
}

private func drawFog(context: GraphicsContext, size: CGSize, time: Double) {
    for p in fogParticles {
        let x = (p.x + sin(time * p.speed + p.driftX) * 0.05) * size.width
        let y = (p.y + cos(time * p.speed * 0.7 + p.driftY) * 0.03) * size.height
        let breath = 0.7 + 0.3 * sin(time * 0.5 + p.speed)
        let alpha = p.opacity * breath
        let s = CGFloat(p.size * (0.8 + 0.4 * sin(time + p.driftX)))

        let rect = CGRect(x: x - s/2, y: y - s/2, width: s, height: s)
        context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(alpha)))
    }
}
```

### Quando usarlo
- Mist, Fog, Smoke, Aurora, Dreamscape

## Regole Performance

| View | Particle Count | FPS | Seed |
|------|---------------|-----|------|
| `AnimatedBackgroundView` (full) | ~70-110 | 60 | `0x7A1B7` |
| `AnimatedThemePreview` (card) | 25 | 30 | `0x42B0` / `0x42C1` + nuovo per ogni tema |

- **MAI** riallocare particelle dentro la Canvas closure
- Usa array `let` pre-allocati in `init()`
- `srand48()` per seed deterministico → pattern stabile tra avvii
- Rispetta `@Environment(\.accessibilityReduceMotion)`: fallback a overlay statico
- `truncatingRemainder(dividingBy:)` per wrapping temporale continuo

## Aggiungere Nuovo Pattern Animato

### Full view (AnimatedBackgroundView)

1. Pre-alloca particelle in `init()` (con `srand48(<seed_unico>)`)
2. Aggiungi `@ViewBuilder private var nuovaView` come computed property
3. Aggiungi `case .nuovoTema: nuovaView` nello switch di `body`
4. Implementa `private func drawNuovo(context:size:time:)`

### Preview (AnimatedThemePreview)

1. In `init(theme:)`, aggiungi seed con `srand48(<seed_unico_preview>)`
2. Aggiungi `case .nuovoTema: renderNV(ctx:size:t:)` nello switch di `body`
3. Implementa `private func renderNV(ctx:size:t:)` (25 particelle, 30fps)

### Static fallback (reduceMotion)

Aggiungi overlay statico nello `ZStack` della view:

```swift
if reduceMotion {
    nuovoStaticOverlay
}
```
