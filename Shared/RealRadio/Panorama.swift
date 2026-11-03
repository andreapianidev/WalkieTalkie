//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - Panorama.swift
//  Talky
//
//  Lo schermo panoramico della radio: lo spettro intorno alla sintonia e,
//  sotto, la cascata degli ultimi secondi. Le righe arrivano dal ricevitore
//  KiwiSDR che si sta ascoltando, circa nove al secondo.

import Combine
import CoreGraphics
import Foundation

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class Panorama: ObservableObject {
    /// Colonne disegnate: la riga del ricevitore ne ha 1024, lo schermo di un
    /// telefono meno della meta'.
    static let columns = 256
    /// Righe di cascata tenute: circa otto secondi alla velocita' scelta.
    static let depth = 72

    /// La cascata pronta da disegnare, la riga piu' nuova in alto.
    @Published private(set) var waterfall: CGImage?
    /// Lo spettro dell'ultima riga, 0...1 per colonna sopra il fondo.
    @Published private(set) var trace: [Float] = []
    /// Bordi della finestra in Hz: la sintonia sta sempre nel mezzo.
    @Published private(set) var lowHz = 0.0
    @Published private(set) var highHz = 0.0
    /// Quanto il segnale nella banda passante sta sopra il rumore, in dB.
    @Published private(set) var marginDB: Float?

    private var sweeps: [SpectrumSweep] = []
    private var floorDBm: Float = -130
    private var smoothed: [Float] = []

    var hasPicture: Bool { waterfall != nil }

    /// Una riga nuova, con la sintonia e la banda passante del momento.
    func add(_ sweep: SpectrumSweep, dialHz: Int, passband: (low: Int, high: Int)) {
        sweeps.insert(sweep, at: 0)
        if sweeps.count > Self.depth { sweeps.removeLast(sweeps.count - Self.depth) }

        let span = sweep.endHz - sweep.startHz
        lowHz = Double(dialHz) - span / 2
        highHz = Double(dialHz) + span / 2

        // Fondo: un quinto delle fette sta sotto. Si muove piano, cosi' i
        // colori non pulsano a ogni passaggio.
        let sorted = sweep.dBm.sorted()
        let fifth = sorted[sorted.count / 5]
        floorDBm += (fifth - floorDBm) * (abs(fifth - floorDBm) > 15 ? 1 : 0.15)

        let row = resample(sweep)
        smoothed = smoothed.count == row.count ? zip(smoothed, row).map { $0 * 0.5 + $1 * 0.5 } : row
        trace = smoothed.map { level($0) }

        let lo = Double(dialHz + passband.low), hi = Double(dialHz + passband.high)
        let inside = row.indices.filter {
            let hz = lowHz + (Double($0) + 0.5) * (highHz - lowHz) / Double(Self.columns)
            return hz >= lo && hz <= hi
        }
        marginDB = inside.map { row[$0] }.max().map { $0 - floorDBm }

        waterfall = render()
    }

    /// Ricevitore nuovo o banda cambiata: la storia di prima non vale piu'.
    func clear() {
        sweeps = []
        smoothed = []
        trace = []
        marginDB = nil
        waterfall = nil
    }

    // MARK: disegno

    /// La riga del ricevitore portata sulle colonne della finestra: per ogni
    /// colonna la fetta piu' forte che ci cade dentro, cosi' una portante
    /// stretta non sparisce nella media.
    private func resample(_ sweep: SpectrumSweep) -> [Float] {
        let width = (highHz - lowHz) / Double(Self.columns)
        return (0 ..< Self.columns).map { col in
            let from = lowHz + Double(col) * width
            let a = Int(((from - sweep.startHz) / sweep.binHz).rounded(.down))
            let b = Int(((from + width - sweep.startHz) / sweep.binHz).rounded(.up))
            let lower = max(0, a), upper = min(sweep.dBm.count, max(b, a + 1))
            guard lower < upper else { return -160 }
            return sweep.dBm[lower ..< upper].max() ?? -160
        }
    }

    /// 0 al fondo, 1 a 45 dB sopra: la scala di un S-meter, da S0 a oltre S9.
    private func level(_ dBm: Float) -> Float {
        max(0, min(1, (dBm - floorDBm + 3) / 45))
    }

    private func render() -> CGImage? {
        let w = Self.columns, h = Self.depth
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        for (y, sweep) in sweeps.enumerated() {
            let row = resample(sweep)
            for x in 0 ..< w {
                let c = Self.palette[Int(level(row[x]) * 255)]
                let i = (y * w + x) * 4
                pixels[i] = c.r
                pixels[i + 1] = c.g
                pixels[i + 2] = c.b
                pixels[i + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Il display di Talky: nero, ambra, giallo del walkie, bianco sui segnali forti.
    private static let palette: [(r: UInt8, g: UInt8, b: UInt8)] = {
        let stops: [(at: Float, r: Float, g: Float, b: Float)] = [
            (0.00, 0.00, 0.00, 0.00),
            (0.18, 0.16, 0.07, 0.00),
            (0.45, 0.62, 0.30, 0.00),
            (0.70, 1.00, 0.72, 0.00),
            (0.88, 1.00, 0.90, 0.25),
            (1.00, 1.00, 1.00, 1.00)
        ]
        return (0 ... 255).map { n in
            let t = Float(n) / 255
            let k = stops.lastIndex { $0.at <= t } ?? 0
            let a = stops[k], b = stops[min(k + 1, stops.count - 1)]
            let f = b.at > a.at ? (t - a.at) / (b.at - a.at) : 0
            func mix(_ x: Float, _ y: Float) -> UInt8 { UInt8(max(0, min(255, (x + (y - x) * f) * 255))) }
            return (mix(a.r, b.r), mix(a.g, b.g), mix(a.b, b.b))
        }
    }()
}
