//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - SoundBands.swift
//  Talky (iOS e Mac)
//
//  Quello che si sente, diviso in bande come sul display di un equalizzatore:
//  una FFT di 1024 campioni, 24 bande da 60 Hz in su in scala logaritmica,
//  in dB. Lo usano la radio del mondo (con l'audio decodificato da StreamTap)
//  e i canali POC e le bande HF e CB (con l'audio che arriva dal server).

import Accelerate
import Foundation

nonisolated final class SoundBands: @unchecked Sendable {
    static let bandCount = 24
    static let historyLength = 90

    struct Frame {
        /// Secondi di audio dall'inizio dell'ascolto.
        var time: Double
        var bands: [Float]
        var peak: Float
    }

    /// Quello che lo schermo disegna adesso.
    struct Display {
        var bands: [Float]
        /// Livello degli ultimi sei secondi, dal piu' vecchio al piu' nuovo.
        var history: [Float]
        /// L'audio scorre: e' arrivato qualcosa nell'ultimo secondo.
        var flowing: Bool
    }

    private static let size = 1024
    private let lock = NSLock()
    private let fft = vDSP.FFT(log2n: 10, radix: .radix2, ofType: DSPSplitComplex.self)
    private let window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: SoundBands.size, isHalfWindow: false)
    private var pending: [Float] = []
    private var clock: Double = 0
    /// Circa 45 secondi di righe: abbastanza per allinearsi al buffer del player.
    private var frames: [Frame] = []
    private var lastIngest: TimeInterval = 0
    private var shown = [Float](repeating: 0, count: SoundBands.bandCount)
    private var lastShown: TimeInterval = 0

    func reset() {
        lock.lock()
        pending = []
        clock = 0
        frames = []
        shown = [Float](repeating: 0, count: Self.bandCount)
        lastIngest = 0
        lock.unlock()
    }

    /// Campioni mono, nell'ordine in cui arrivano.
    func ingest(_ samples: [Float], rate: Double) {
        guard rate > 0, !samples.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        pending.append(contentsOf: samples)
        lastIngest = ProcessInfo.processInfo.systemUptime
        while pending.count >= Self.size {
            let block = Array(pending.prefix(Self.size))
            pending.removeFirst(Self.size)
            frames.append(Frame(time: clock, bands: analyse(block, rate: rate), peak: block.map(abs).max() ?? 0))
            clock += Double(Self.size) / rate
        }
        if frames.count > 2400 { frames.removeFirst(frames.count - 2000) }
    }

    /// Le bande al secondo `time` dell'ascolto; nil = l'ultimo arrivato (audio
    /// che si suona appena arriva, come POC e HF).
    func display(at time: Double? = nil) -> Display {
        lock.lock()
        defer { lock.unlock() }
        let now = ProcessInfo.processInfo.systemUptime
        let t = time ?? frames.last?.time ?? 0
        let index = frames.lastIndex { $0.time <= t }
        let target = index.map { frames[$0].bands } ?? [Float](repeating: 0, count: Self.bandCount)
        // Sale subito, scende piano: come gli strumenti a lancetta.
        let dt = Float(min(0.2, max(0, now - lastShown)))
        lastShown = now
        for i in 0 ..< Self.bandCount {
            shown[i] = target[i] >= shown[i] ? target[i] : max(target[i], shown[i] - dt * 1.6)
        }
        var history = [Float](repeating: 0, count: Self.historyLength)
        if let index {
            let span = 6.0 / Double(Self.historyLength)
            var j = index
            for column in stride(from: Self.historyLength - 1, through: 0, by: -1) {
                let edge = t - Double(Self.historyLength - 1 - column) * span
                var peak: Float = 0
                while j >= 0, frames[j].time > edge - span {
                    peak = max(peak, frames[j].peak)
                    j -= 1
                }
                history[column] = min(1, peak)
                if j < 0 { break }
            }
        }
        // Con un istante preciso (la radio) conta avere audio per quell'istante:
        // gli HLS arrivano a blocchi di un segmento ogni 6-10 secondi. Senza
        // (POC, HF) conta che l'audio sia arrivato nell'ultimo secondo.
        let flowing: Bool
        if let time, let last = frames.last {
            flowing = index != nil && time <= last.time + 1.5
        } else {
            flowing = now - lastIngest < 1 && index != nil
        }
        return Display(bands: shown, history: history, flowing: flowing)
    }

    private func analyse(_ block: [Float], rate: Double) -> [Float] {
        guard let fft else { return [Float](repeating: 0, count: Self.bandCount) }
        let half = Self.size / 2
        let windowed = vDSP.multiply(block, window)
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var power = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                windowed.withUnsafeBufferPointer { wp in
                    wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                fft.forward(input: split, output: &split)
                power.withUnsafeMutableBufferPointer { pp in
                    vDSP_zvmags(&split, 1, pp.baseAddress!, 1, vDSP_Length(half))
                }
            }
        }
        // Un seno a piena scala da' |X| circa n/2 dopo la forward di vDSP
        // (che raddoppia) e la finestra di Hann (che dimezza): 0 dB.
        let fullScale = Float(Self.size / 2) * Float(Self.size / 2)
        let top = min(16_000, rate / 2 * 0.95)
        var out = [Float](repeating: 0, count: Self.bandCount)
        for b in 0 ..< Self.bandCount {
            let f0 = 60 * pow(top / 60, Double(b) / Double(Self.bandCount))
            let f1 = 60 * pow(top / 60, Double(b + 1) / Double(Self.bandCount))
            let i0 = max(1, Int(f0 / rate * Double(Self.size)))
            let i1 = min(half - 1, max(i0, Int(f1 / rate * Double(Self.size))))
            var strongest: Float = 0
            for i in i0 ... i1 { strongest = max(strongest, power[i]) }
            let db = 10 * log10(max(strongest / fullScale, 1e-12))
            out[b] = min(1, max(0, (db + 60) / 60))
        }
        return out
    }
}
