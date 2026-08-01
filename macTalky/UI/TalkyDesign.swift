//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - TalkyDesign.swift
//  macTalky
//
//  Design system "field radio console": pannello grafite, fosforo ambra,
//  tipografia VFD monospace, glass e shader Metal per l'atmosfera.

import SwiftUI

// MARK: - Palette

enum Talky {
    /// Carbone di fondo (dietro lo shader aurora).
    static let coal = Color(red: 0.043, green: 0.051, blue: 0.059)
    /// Pannello grafite.
    static let panel = Color(red: 0.086, green: 0.098, blue: 0.110)
    /// Pannello rialzato.
    static let panelRaised = Color(red: 0.125, green: 0.141, blue: 0.157)
    /// Fosforo ambra — accent primario (radio, display).
    static let amber = Color(red: 1.0, green: 0.68, blue: 0.25)
    /// Ambra profonda per glow.
    static let amberDeep = Color(red: 0.85, green: 0.48, blue: 0.10)
    /// Verde segnale — TX / connessioni attive.
    static let signal = Color(red: 0.38, green: 0.91, blue: 0.55)
    /// Rosso allarme — RX / errori.
    static let alarm = Color(red: 1.0, green: 0.36, blue: 0.29)
    /// Teal fantasma — accent secondario.
    static let teal = Color(red: 0.25, green: 0.72, blue: 0.68)
    /// Testo primario.
    static let text = Color(red: 0.93, green: 0.94, blue: 0.95)
    /// Testo attenuato.
    static let dim = Color(red: 0.54, green: 0.58, blue: 0.62)
    /// Bordo pannelli.
    static let stroke = Color.white.opacity(0.08)
}

// MARK: - Typography

extension Font {
    /// Display VFD: valori, frequenze, readout hardware.
    static func vfd(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Titoli e controlli, tondi e caldi.
    static func talkyTitle(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Metal background

/// Sfondo animato con lo shader `talkyAurora`. Un solo TimelineView per finestra.
struct AuroraBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 100_000)
            GeometryReader { geo in
                Rectangle()
                    .fill(Talky.coal)
                    .colorEffect(ShaderLibrary.talkyAurora(
                        .float2(Float(geo.size.width), Float(geo.size.height)),
                        .float(Float(t))
                    ))
            }
        }
        .ignoresSafeArea()
    }
}

/// Visualizer a onda fosforo (shader `talkyVU`).
struct VUWave: View {
    var level: Float
    var playing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 10_000)
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.white)
                    .colorEffect(ShaderLibrary.talkyVU(
                        .float2(Float(geo.size.width), Float(geo.size.height)),
                        .float(Float(t)),
                        .float(level),
                        .float(playing ? 1 : 0)
                    ))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Components

/// Pannello glass scuro con bordo sottile — il contenitore standard dell'app.
struct ConsolePanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Talky.panel.opacity(0.72))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Talky.stroke, lineWidth: 1)
            )
    }
}

/// Spia di stato tonda con glow.
struct StatusLamp: View {
    var color: Color
    var on: Bool

    var body: some View {
        Circle()
            .fill(on ? color : Talky.dim.opacity(0.25))
            .frame(width: 9, height: 9)
            .shadow(color: on ? color.opacity(0.9) : .clear, radius: on ? 6 : 0)
            .animation(.easeInOut(duration: 0.2), value: on)
    }
}

/// Etichetta di sezione stile serigrafia su pannello hardware.
struct PanelLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.vfd(10, weight: .bold))
            .kerning(2.2)
            .foregroundStyle(Talky.dim)
    }
}

/// Badge PRO ambra.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.vfd(9, weight: .heavy))
            .kerning(1)
            .foregroundStyle(Talky.coal)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Talky.amber, in: Capsule())
    }
}

/// Bottone "chip hardware": pillola scura con testo mono.
struct ChipButtonStyle: ButtonStyle {
    var accent: Color = Talky.amber
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.vfd(11, weight: .semibold))
            .foregroundStyle(filled ? Talky.coal : accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(filled ? accent : accent.opacity(configuration.isPressed ? 0.22 : 0.10))
            )
            .overlay(Capsule().strokeBorder(accent.opacity(filled ? 0 : 0.45), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Barra livello segmentata stile VU hardware.
struct SegmentedMeter: View {
    var level: Float // 0...1
    var segments: Int = 18

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { i in
                let threshold = Float(i) / Float(segments)
                let lit = level > threshold
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color(for: threshold).opacity(lit ? 1 : 0.14))
                    .frame(height: 12)
                    .shadow(color: lit ? color(for: threshold).opacity(0.7) : .clear, radius: 3)
            }
        }
        .animation(.linear(duration: 0.08), value: level)
    }

    private func color(for t: Float) -> Color {
        if t > 0.82 { return Talky.alarm }
        if t > 0.6 { return Talky.amber }
        return Talky.signal
    }
}
