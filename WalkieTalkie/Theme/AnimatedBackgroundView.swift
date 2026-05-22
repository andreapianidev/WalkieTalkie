//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - AnimatedBackgroundView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

// MARK: - Particle Models

/// Particella di base usata per Black Hole (orbita) e Galaxy (drift stellare).
/// Pre-computata una sola volta a init: i campi sono "seed" stabili,
/// la posizione effettiva viene calcolata frame-by-frame nella Canvas.
private struct ParticleSeed {
    let baseAngle: Double      // angolo iniziale (rad)
    let baseRadius: Double     // raggio normalizzato 0..1
    let speed: Double          // moltiplicatore velocità
    let size: Double           // dimensione pixel
    let brightness: Double     // 0..1
    let phase: Double          // offset di fase per twinkle/drift
}

/// Streak di "stella cadente" attivo o pendente.
private struct ShootingStar {
    let startX: Double
    let startY: Double
    let angle: Double
    let length: Double
    let speed: Double
    let activationTime: Double  // tempo (s) a cui parte
    let duration: Double        // durata totale (s)
}

// MARK: - AnimatedBackgroundView

/// Sfondo animato a particelle, attivo per i temi `.blackHole` e `.galaxy`.
/// Per gli altri temi rende un semplice `Color("BackgroundColor")` (no-op).
///
/// Performance:
/// - Render via `Canvas` (CoreGraphics path-based), no SwiftUI View per particella.
/// - `TimelineView(.animation(minimumInterval: 1/60))` come driver a 60fps.
/// - Particelle pre-allocate in `let` array, mai re-alloca dentro la closure.
/// - Rispetta `accessibilityReduceMotion`: fallback a gradiente statico.
struct AnimatedBackgroundView: View {

    // MARK: - Dependencies

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Pre-computed Particle Arrays
    //
    // Generati una volta sola con `srand48` per posizioni stabili tra i frame.
    // Re-genera implicito ad ogni instance: la View è long-lived in ContentView
    // (vive dentro lo ZStack root) quindi viene creata una sola volta per sessione.

    private let blackHoleParticles: [ParticleSeed]
    private let galaxyStars: [ParticleSeed]
    private let shootingStars: [ShootingStar]

    // MARK: - Tuning Constants

    private static let blackHoleParticleCount = 70
    private static let galaxyStarCount = 110
    private static let shootingStarCount = 8       // pool ciclico

    // MARK: - Init

    init() {
        // Seed deterministico → pattern stabile tra avvii (estetica più coerente).
        srand48(0x7A1B7)

        var bh: [ParticleSeed] = []
        bh.reserveCapacity(Self.blackHoleParticleCount)
        for _ in 0..<Self.blackHoleParticleCount {
            bh.append(ParticleSeed(
                baseAngle: drand48() * .pi * 2,
                baseRadius: 0.15 + drand48() * 0.85,
                speed: 0.15 + drand48() * 0.55,
                size: 1.2 + drand48() * 2.4,
                brightness: 0.35 + drand48() * 0.65,
                phase: drand48() * .pi * 2
            ))
        }

        var stars: [ParticleSeed] = []
        stars.reserveCapacity(Self.galaxyStarCount)
        for _ in 0..<Self.galaxyStarCount {
            stars.append(ParticleSeed(
                baseAngle: drand48() * .pi * 2,         // posizione X normalizzata interpretabile
                baseRadius: drand48(),                  // posizione Y normalizzata
                speed: 0.02 + drand48() * 0.08,
                size: 0.6 + drand48() * 2.0,
                brightness: 0.25 + drand48() * 0.75,
                phase: drand48() * .pi * 2
            ))
        }

        var shoots: [ShootingStar] = []
        shoots.reserveCapacity(Self.shootingStarCount)
        for i in 0..<Self.shootingStarCount {
            // Distribuiamo le attivazioni nei primi ~32s, poi modulo nel time delta.
            let activation = Double(i) * 4.0 + drand48() * 2.0
            shoots.append(ShootingStar(
                startX: drand48(),
                startY: drand48() * 0.5,                // partono dalla metà superiore
                angle: .pi * 0.15 + drand48() * .pi * 0.15,   // diagonale
                length: 0.18 + drand48() * 0.12,
                speed: 0.4 + drand48() * 0.3,
                activationTime: activation,
                duration: 1.0 + drand48() * 0.8
            ))
        }

        self.blackHoleParticles = bh
        self.galaxyStars = stars
        self.shootingStars = shoots
    }

    // MARK: - Body

    var body: some View {
        switch themeManager.currentTheme {
        case .blackHole:
            blackHoleView
        case .galaxy:
            galaxyView
        default:
            Color("BackgroundColor")
        }
    }

    // MARK: - Black Hole

    @ViewBuilder
    private var blackHoleView: some View {
        ZStack {
            // Sfondo radiale: viola scuro → nero
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.18, green: 0.05, blue: 0.30),
                    Color(red: 0.06, green: 0.02, blue: 0.12),
                    Color.black
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 600
            )

            if reduceMotion {
                // Disco statico al centro
                blackHoleStaticOverlay
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        drawBlackHole(context: context, size: size, time: t)
                    }
                }
            }
        }
    }

    private var blackHoleStaticOverlay: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.25))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
            Circle()
                .fill(Color.black)
                .frame(width: 120, height: 120)
        }
    }

    /// Renderer Canvas per il black hole.
    /// Le particelle orbitano in spirale verso il centro; fade-out vicino all'event horizon.
    private func drawBlackHole(context: GraphicsContext, size: CGSize, time: Double) {
        let cx = size.width / 2
        let cy = size.height / 2
        let maxR = min(size.width, size.height) * 0.48
        let eventHorizon = maxR * 0.12

        // Particelle: spirale verso l'interno con velocità angolare maggiore vicino al centro.
        for p in blackHoleParticles {
            // Raggio oscillante che lentamente si riduce e poi rinasce all'esterno.
            // Usiamo (time * speed + phase) mod 1 per ciclo continuo.
            let cycle = (time * p.speed * 0.12 + p.phase / (.pi * 2)).truncatingRemainder(dividingBy: 1.0)
            // 1 → fuori, 0 → centro
            let lifeOutToIn = 1.0 - cycle
            let r = lifeOutToIn * maxR * p.baseRadius + eventHorizon * 0.4

            // Velocità angolare più alta vicino al centro (~ 1/r), capped.
            let angularSpeed = 0.6 + (maxR / max(r, eventHorizon * 0.5)) * 0.05
            let angle = p.baseAngle + time * angularSpeed * p.speed

            let x = cx + CGFloat(cos(angle) * r)
            let y = cy + CGFloat(sin(angle) * r)

            // Fade-out vicino al centro
            let normR = (r - eventHorizon) / max(maxR - eventHorizon, 1)
            let alpha = max(0.0, min(1.0, normR)) * p.brightness

            let particleSize = CGFloat(p.size * (0.6 + normR * 0.6))
            let rect = CGRect(
                x: x - particleSize / 2,
                y: y - particleSize / 2,
                width: particleSize,
                height: particleSize
            )

            // Tinta viola con un po' di bianco caldo
            let color = Color(
                red: 0.75 + 0.2 * p.brightness,
                green: 0.55 + 0.2 * p.brightness,
                blue: 0.95
            ).opacity(alpha)

            context.fill(Path(ellipseIn: rect), with: .color(color))
        }

        // Glow viola attorno al disco
        let glowRect = CGRect(
            x: cx - eventHorizon * 1.9,
            y: cy - eventHorizon * 1.9,
            width: eventHorizon * 3.8,
            height: eventHorizon * 3.8
        )
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.purple.opacity(0.55),
                    Color.purple.opacity(0.15),
                    Color.purple.opacity(0.0)
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: eventHorizon * 0.9,
                endRadius: eventHorizon * 1.9
            )
        )

        // Disco nero centrale (event horizon)
        let discRect = CGRect(
            x: cx - eventHorizon,
            y: cy - eventHorizon,
            width: eventHorizon * 2,
            height: eventHorizon * 2
        )
        context.fill(Path(ellipseIn: discRect), with: .color(.black))
    }

    // MARK: - Galaxy

    @ViewBuilder
    private var galaxyView: some View {
        ZStack {
            // Sfondo blu profondo
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.10),
                    Color(red: 0.04, green: 0.06, blue: 0.18),
                    Color(red: 0.01, green: 0.02, blue: 0.06)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            if reduceMotion {
                galaxyStaticOverlay
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        drawGalaxy(context: context, size: size, time: t)
                    }
                }
            }
        }
    }

    private var galaxyStaticOverlay: some View {
        // Versione "fotografica": disegna gli stessi punti senza twinkle.
        Canvas { context, size in
            for star in galaxyStars {
                let x = CGFloat(star.baseAngle / (.pi * 2)) * size.width
                let y = CGFloat(star.baseRadius) * size.height
                let s = CGFloat(star.size)
                let rect = CGRect(x: x - s/2, y: y - s/2, width: s, height: s)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(star.brightness))
                )
            }
        }
    }

    /// Renderer Canvas per la galassia.
    /// Stelle con twinkle (sin) + drift orizzontale lentissimo + shooting stars cicliche.
    private func drawGalaxy(context: GraphicsContext, size: CGSize, time: Double) {
        // Stelle
        for star in galaxyStars {
            // Posizione base: angle interpretato come X normalizzato 0..1
            let baseX = star.baseAngle / (.pi * 2)
            let drift = sin(time * star.speed + star.phase) * 0.01   // micro-drift
            let x = ((baseX + drift).truncatingRemainder(dividingBy: 1.0) + 1.0)
                .truncatingRemainder(dividingBy: 1.0) * size.width
            let y = CGFloat(star.baseRadius) * size.height

            // Twinkle: brightness modulato
            let twinkle = 0.65 + 0.35 * sin(time * (1.2 + star.speed * 4) + star.phase)
            let alpha = star.brightness * twinkle

            let s = CGFloat(star.size)
            let rect = CGRect(x: x - s/2, y: y - s/2, width: s, height: s)

            // Tinta leggermente più calda per le stelle grandi
            let color: Color = star.size > 1.8
                ? Color(red: 1.0, green: 0.95, blue: 0.85).opacity(alpha)
                : Color.white.opacity(alpha)

            context.fill(Path(ellipseIn: rect), with: .color(color))
        }

        // Shooting stars: ciclo di ~32s
        let cycleLength: Double = 32.0
        let localTime = time.truncatingRemainder(dividingBy: cycleLength)

        for shoot in shootingStars {
            let elapsed = localTime - shoot.activationTime
            guard elapsed >= 0, elapsed <= shoot.duration else { continue }

            let progress = elapsed / shoot.duration
            // Posizione corrente lungo la diagonale
            let travel = progress * shoot.speed
            let cx = (shoot.startX + cos(shoot.angle) * travel) * size.width
            let cy = (shoot.startY + sin(shoot.angle) * travel) * size.height

            // Coda
            let tailLen = shoot.length * Double(size.width)
            let tx = cx - CGFloat(cos(shoot.angle) * tailLen)
            let ty = cy - CGFloat(sin(shoot.angle) * tailLen)

            // Fade in/out
            let alpha: Double = {
                if progress < 0.2 { return progress / 0.2 }
                if progress > 0.8 { return (1.0 - progress) / 0.2 }
                return 1.0
            }()

            var path = Path()
            path.move(to: CGPoint(x: tx, y: ty))
            path.addLine(to: CGPoint(x: cx, y: cy))

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(alpha)
                    ]),
                    startPoint: CGPoint(x: tx, y: ty),
                    endPoint: CGPoint(x: cx, y: cy)
                ),
                lineWidth: 1.6
            )

            // Testa
            let headRect = CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: headRect), with: .color(.white.opacity(alpha)))
        }
    }
}

// MARK: - Preview Mini Renderer (per ThemeSelectorView)

/// Mini-renderer usato dentro le card dello `ThemeSelectorView` per dare
/// un'anteprima animata dell'effetto. Particle count ridotto (~25) per performance.
struct AnimatedThemePreview: View {

    let theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particles: [ParticleSeed]

    init(theme: Theme) {
        self.theme = theme
        srand48(theme == .blackHole ? 0x42B0 : 0x42C1)
        var arr: [ParticleSeed] = []
        let count = 25
        arr.reserveCapacity(count)
        for _ in 0..<count {
            arr.append(ParticleSeed(
                baseAngle: drand48() * .pi * 2,
                baseRadius: drand48(),
                speed: 0.1 + drand48() * 0.4,
                size: 0.6 + drand48() * 1.4,
                brightness: 0.4 + drand48() * 0.6,
                phase: drand48() * .pi * 2
            ))
        }
        self.particles = arr
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                if reduceMotion {
                    EmptyView()
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { tl in
                        Canvas { ctx, size in
                            let t = tl.date.timeIntervalSinceReferenceDate
                            switch theme {
                            case .blackHole:
                                renderBH(ctx: ctx, size: size, t: t)
                            case .galaxy:
                                renderGX(ctx: ctx, size: size, t: t)
                            default:
                                break
                            }
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch theme {
        case .blackHole:
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.20, green: 0.06, blue: 0.35),
                    Color.black
                ]),
                center: .center,
                startRadius: 2,
                endRadius: 60
            )
        case .galaxy:
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.18),
                    Color(red: 0.01, green: 0.02, blue: 0.06)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            Color.clear
        }
    }

    private func renderBH(ctx: GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width / 2
        let cy = size.height / 2
        let maxR = min(size.width, size.height) * 0.45
        let eh = maxR * 0.18

        for p in particles {
            let cycle = (t * p.speed * 0.25 + p.phase / (.pi * 2)).truncatingRemainder(dividingBy: 1.0)
            let lifeOutToIn = 1.0 - cycle
            let r = lifeOutToIn * maxR * p.baseRadius + eh * 0.4
            let angularSpeed = 1.2 + (maxR / max(r, eh * 0.5)) * 0.1
            let angle = p.baseAngle + t * angularSpeed * p.speed
            let x = cx + CGFloat(cos(angle) * r)
            let y = cy + CGFloat(sin(angle) * r)
            let normR = (r - eh) / max(maxR - eh, 1)
            let alpha = max(0.0, min(1.0, normR)) * p.brightness
            let s = CGFloat(p.size * 0.8)
            let rect = CGRect(x: x - s/2, y: y - s/2, width: s, height: s)
            let color = Color(red: 0.85, green: 0.6, blue: 1.0).opacity(alpha)
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
        }

        let disc = CGRect(x: cx - eh, y: cy - eh, width: eh * 2, height: eh * 2)
        ctx.fill(Path(ellipseIn: disc), with: .color(.black))
    }

    private func renderGX(ctx: GraphicsContext, size: CGSize, t: Double) {
        for s in particles {
            let x = CGFloat(s.baseAngle / (.pi * 2)) * size.width
            let y = CGFloat(s.baseRadius) * size.height
            let twinkle = 0.6 + 0.4 * sin(t * (1.5 + s.speed * 3) + s.phase)
            let alpha = s.brightness * twinkle
            let sz = CGFloat(s.size * 0.9)
            let rect = CGRect(x: x - sz/2, y: y - sz/2, width: sz, height: sz)
            ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(alpha)))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedBackgroundView()
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
    }
}
#endif
