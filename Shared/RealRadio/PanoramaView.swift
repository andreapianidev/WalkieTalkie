//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - PanoramaView.swift
//  Talky
//
//  Lo schermo panoramico sul corpo del walkie: spettro in alto, scala con i
//  canali CB o i kHz, cascata sotto. Al centro la sintonia, in giallo chiaro
//  la banda passante che si sta ascoltando.

import SwiftUI

/// I testi dello schermo li passa chi lo mostra: iPhone tradotto, Mac in inglese.
struct PanoramaWords {
    /// "%d dB sopra il rumore".
    var overNoise: String
    var noiseOnly: String
    var waiting: String
}

@available(iOS 16.0, macOS 13.0, *)
struct PanoramaView: View {
    @ObservedObject var panorama: Panorama
    let tuning: Tuning
    let signalDBm: Double?
    let words: PanoramaWords

    private let scaleHeight: CGFloat = 13
    private let amber = Color(red: 1.0, green: 0.8, blue: 0.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                let traceHeight = (geo.size.height - scaleHeight) * 0.4
                ZStack(alignment: .topLeading) {
                    Color.black
                    if let image = panorama.waterfall {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.medium)
                            .frame(width: geo.size.width, height: geo.size.height - traceHeight - scaleHeight)
                            .offset(y: traceHeight + scaleHeight)
                    }
                    Canvas { ctx, size in
                        drawPassband(ctx, size)
                        drawTrace(ctx, width: size.width, height: traceHeight)
                        drawScale(ctx, width: size.width, top: traceHeight)
                        drawDial(ctx, size)
                    }
                    if !panorama.hasPicture {
                        Text(words.waiting)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(amber.opacity(0.7))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))

            readout
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readoutText)
    }

    // MARK: lettura

    private var readout: some View {
        HStack(spacing: 6) {
            if let dBm = signalDBm {
                Text(SignalScale.label(dBm: dBm))
                    .foregroundColor(amber)
                    .fontWeight(.bold)
            }
            Text(marginText)
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black))
    }

    private var marginText: String {
        guard let margin = panorama.marginDB else { return "" }
        return margin >= 6 ? String(format: words.overNoise, Int(margin.rounded())) : words.noiseOnly
    }

    private var readoutText: String {
        [signalDBm.map { SignalScale.label(dBm: $0) }, marginText].compactMap { $0 }.joined(separator: ", ")
    }

    // MARK: disegno

    private func x(_ hz: Double, _ width: CGFloat) -> CGFloat {
        let span = panorama.highHz - panorama.lowHz
        guard span > 0 else { return width / 2 }
        return CGFloat((hz - panorama.lowHz) / span) * width
    }

    private func drawPassband(_ ctx: GraphicsContext, _ size: CGSize) {
        let pb = KiwiFrame.passband(tuning)
        let a = x(Double(tuning.hz + pb.low), size.width), b = x(Double(tuning.hz + pb.high), size.width)
        ctx.fill(Path(CGRect(x: a, y: 0, width: max(1, b - a), height: size.height)), with: .color(amber.opacity(0.13)))
    }

    private func drawTrace(_ ctx: GraphicsContext, width: CGFloat, height: CGFloat) {
        let trace = panorama.trace
        guard trace.count > 1 else { return }
        let step = width / CGFloat(trace.count - 1)
        var line = Path()
        for (i, v) in trace.enumerated() {
            let p = CGPoint(x: CGFloat(i) * step, y: height - 2 - CGFloat(v) * (height - 6))
            i == 0 ? line.move(to: p) : line.addLine(to: p)
        }
        var fill = line
        fill.addLine(to: CGPoint(x: width, y: height))
        fill.addLine(to: CGPoint(x: 0, y: height))
        fill.closeSubpath()
        ctx.fill(fill, with: .linearGradient(Gradient(colors: [amber.opacity(0.45), amber.opacity(0.05)]),
                                             startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: height)))
        ctx.stroke(line, with: .color(amber), lineWidth: 1.2)
    }

    /// La scala fra spettro e cascata: in CB i numeri dei canali, altrove i kHz.
    private func drawScale(_ ctx: GraphicsContext, width: CGFloat, top: CGFloat) {
        ctx.fill(Path(CGRect(x: 0, y: top, width: width, height: scaleHeight)), with: .color(.black))
        let y = top + scaleHeight / 2
        let onCB = CitizensBand.dial.contains(tuning.hz) && !CitizensBand.isDX(tuning.hz)
        if onCB {
            for (i, hz) in CitizensBand.channels.enumerated() where Double(hz) > panorama.lowHz && Double(hz) < panorama.highHz {
                label(ctx, "\(i + 1)", at: CGPoint(x: x(Double(hz), width), y: y), lit: hz == tuning.hz)
            }
            return
        }
        let span = panorama.highHz - panorama.lowHz
        guard span > 0 else { return }
        let stepHz = span > 40_000 ? 10_000.0 : 5_000.0
        var hz = (panorama.lowHz / stepHz).rounded(.up) * stepHz
        while hz < panorama.highHz {
            let px = x(hz, width)
            if px > 18, px < width - 18 {
                label(ctx, String(format: "%.3f", hz / 1_000_000), at: CGPoint(x: px, y: y), lit: false)
            }
            hz += stepHz
        }
    }

    private func label(_ ctx: GraphicsContext, _ text: String, at point: CGPoint, lit: Bool) {
        ctx.draw(Text(text)
                    .font(.system(size: 8.5, weight: lit ? .heavy : .semibold, design: .monospaced))
                    .foregroundColor(lit ? amber : .white.opacity(0.6)),
                 at: point)
    }

    private func drawDial(_ ctx: GraphicsContext, _ size: CGSize) {
        let px = x(Double(tuning.hz), size.width)
        var dial = Path()
        dial.move(to: CGPoint(x: px, y: 0))
        dial.addLine(to: CGPoint(x: px, y: size.height))
        ctx.stroke(dial, with: .color(Color(red: 1, green: 0.35, blue: 0.2).opacity(0.85)), lineWidth: 1)
    }
}
