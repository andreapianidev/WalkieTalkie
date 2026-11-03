//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - SoundBandsView.swift
//  Talky (iOS e Mac)
//
//  Il display a barre di un equalizzatore: 24 colonne a LED, l'ultimo quinto
//  rosso, e sotto il livello degli ultimi sei secondi. Disegna SoundBands.

import SwiftUI

struct SoundBandsView: View {
    let display: SoundBands.Display
    var color = Color(red: 1.0, green: 0.8, blue: 0.0)

    var body: some View {
        Canvas { ctx, size in
            let split = size.height * 0.7
            drawBars(ctx, in: CGRect(x: 0, y: 0, width: size.width, height: split))
            drawHistory(ctx, in: CGRect(x: 0, y: split, width: size.width, height: size.height - split))
        }
    }

    private func drawBars(_ ctx: GraphicsContext, in rect: CGRect) {
        let count = display.bands.count
        guard count > 0 else { return }
        let gap: CGFloat = 3
        let width = (rect.width - gap * CGFloat(count + 1)) / CGFloat(count)
        let step: CGFloat = 6
        let segments = max(4, Int((rect.height - 10) / step))
        for (i, value) in display.bands.enumerated() {
            let x = rect.minX + gap + CGFloat(i) * (width + gap)
            let lit = Int((CGFloat(value) * CGFloat(segments)).rounded())
            for s in 0 ..< segments {
                let y = rect.maxY - 4 - CGFloat(s + 1) * step
                let cell = Path(roundedRect: CGRect(x: x, y: y, width: width, height: step - 2), cornerRadius: 1)
                let hot = s >= segments * 4 / 5
                ctx.fill(cell, with: .color((hot ? Color.red : color).opacity(s < lit ? 1 : 0.09)))
            }
        }
    }

    private func drawHistory(_ ctx: GraphicsContext, in rect: CGRect) {
        let history = display.history
        guard !history.isEmpty else { return }
        let width = rect.width / CGFloat(history.count)
        let mid = rect.midY
        for (i, level) in history.enumerated() {
            let h = max(1, CGFloat(level) * rect.height * 0.85)
            let bar = CGRect(x: rect.minX + CGFloat(i) * width + 0.5, y: mid - h / 2, width: max(1, width - 1), height: h)
            ctx.fill(Path(bar), with: .color(color.opacity(0.2 + 0.6 * Double(i) / Double(history.count))))
        }
    }
}
