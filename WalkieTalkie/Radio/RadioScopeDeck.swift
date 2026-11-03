//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - RadioScopeDeck.swift
//  WalkieTalkie
//
//  La radio non trasmette: al posto del tasto per parlare, lo schermo con la
//  forma d'onda della stazione che suona e le letture dello stream.

import SwiftUI

struct RadioScopeDeck: View {
    @ObservedObject var radio: RadioManager
    @ObservedObject private var sleep = SleepTimerManager.shared
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            RadioScopeScreen(radio: radio)
                .frame(height: compact ? 132 : 185)
                .padding(.horizontal, 12)
            TimelineView(.periodic(from: .now, by: 2)) { _ in
                DialReadings(cells: cells, compact: compact)
            }
        }
    }

    private var cells: [DialReading] {
        let none = "--"
        let station = radio.currentStation
        let state: String
        if radio.isBuffering {
            state = "radio_state_buffering".localized
        } else {
            state = (radio.isPlaying ? "radio_state_on_air" : "radio_state_paused").localized
        }
        let sleepText = sleep.isActive
            ? String(format: "%d:%02d", Int(sleep.remainingSeconds) / 60, Int(sleep.remainingSeconds) % 60)
            : "OFF"
        return [
            DialReading(label: "radio_info_country".localized, value: station?.country ?? none),
            DialReading(label: "radio_info_genre".localized, value: station?.genre ?? none),
            DialReading(label: "radio_info_bitrate".localized, value: radio.streamKbps.map { "\($0) kbps" } ?? none),
            DialReading(label: "radio_info_state".localized, value: state, lit: radio.isPlaying && !radio.isBuffering),
            DialReading(label: "radio_info_volume".localized, value: "\(Int((radio.volume * 100).rounded()))%"),
            DialReading(label: "radio_info_sleep".localized, value: sleepText, lit: sleep.isActive)
        ]
    }
}

/// Oscilloscopio sopra (la forma d'onda dell'ultimo istante), storia del
/// livello sotto (gli ultimi sei secondi, il piu' recente a destra).
struct RadioScopeScreen: View {
    @ObservedObject var radio: RadioManager

    private let amber = Color(red: 1.0, green: 0.8, blue: 0.0)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !radio.isPlaying)) { _ in
            let picture = RadioScope.shared.picture()
            ZStack {
                Color.black
                Canvas { ctx, size in
                    let split = size.height * 0.58
                    drawWave(ctx, picture.wave, in: CGRect(x: 0, y: 0, width: size.width, height: split))
                    drawHistory(ctx, picture.history, in: CGRect(x: 0, y: split, width: size.width, height: size.height - split))
                }
                .opacity(picture.flowing ? 1 : 0.35)
                if !picture.flowing {
                    Text(caption(picture.source))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(amber.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                if picture.flowing {
                    HStack(spacing: 5) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("ON AIR")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private func caption(_ source: RadioScope.Source) -> String {
        if radio.isBuffering { return "radio_scope_buffering".localized }
        if radio.currentStation == nil { return "radio_scope_pick".localized }
        if !radio.isPlaying { return "radio_scope_paused".localized }
        if source == .unsupported { return "radio_scope_unsupported".localized }
        return "radio_scope_buffering".localized
    }

    private func drawWave(_ ctx: GraphicsContext, _ wave: [Float], in rect: CGRect) {
        let mid = rect.midY
        var axis = Path()
        axis.move(to: CGPoint(x: 0, y: mid))
        axis.addLine(to: CGPoint(x: rect.width, y: mid))
        ctx.stroke(axis, with: .color(.white.opacity(0.12)), lineWidth: 1)
        guard wave.count > 1 else { return }
        let step = rect.width / CGFloat(wave.count - 1)
        var line = Path()
        for (i, v) in wave.enumerated() {
            let p = CGPoint(x: CGFloat(i) * step, y: mid - CGFloat(max(-1, min(1, v))) * rect.height * 0.46)
            i == 0 ? line.move(to: p) : line.addLine(to: p)
        }
        ctx.stroke(line, with: .color(amber.opacity(0.25)), lineWidth: 5)
        ctx.stroke(line, with: .color(amber), lineWidth: 1.6)
    }

    private func drawHistory(_ ctx: GraphicsContext, _ history: [Float], in rect: CGRect) {
        guard !history.isEmpty else { return }
        let width = rect.width / CGFloat(history.count)
        let mid = rect.midY
        for (i, level) in history.enumerated() {
            let h = max(1, CGFloat(level) * rect.height * 0.92)
            let bar = CGRect(x: rect.minX + CGFloat(i) * width + 0.5, y: mid - h / 2, width: max(1, width - 1), height: h)
            let age = Double(i) / Double(history.count)
            ctx.fill(Path(bar), with: .color(amber.opacity(0.25 + 0.75 * age)))
        }
    }
}
