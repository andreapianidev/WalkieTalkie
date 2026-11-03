//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - RadioScope.swift
//  WalkieTalkie
//
//  L'audio della stazione che suona, letto mentre passa nel player: la forma
//  d'onda dell'ultimo istante e il livello degli ultimi secondi. Un tap di
//  MediaToolbox sulla traccia audio. ATTENZIONE, misurato il 03/11/2026: sugli
//  stream dal vivo il tap non riceve nessun campione, ne' Icecast ne' HLS
//  (funziona solo sui file). Va sostituito con una decodifica propria.

import AVFoundation
import MediaToolbox

nonisolated final class RadioScope: @unchecked Sendable {
    static let shared = RadioScope()

    /// Punti della forma d'onda disegnata.
    static let wavePoints = 160
    /// Colonne della storia del livello: circa sei secondi.
    static let historyLength = 90

    enum Source: Equatable {
        case idle, listening, unsupported
    }

    private let lock = NSLock()
    private var wave = [Float](repeating: 0, count: RadioScope.wavePoints)
    private var history = [Float](repeating: 0, count: RadioScope.historyLength)
    private var historyHead = 0
    private var pendingPeak: Float = 0
    private var lastColumn: TimeInterval = 0
    private var lastSamples: TimeInterval = 0
    private var interleavedChannels = 1
    private var isFloat = true
    private var source: Source = .idle

    struct Picture {
        var wave: [Float]
        /// Dal piu' vecchio al piu' nuovo, 0...1.
        var history: [Float]
        var source: Source
        /// Campioni arrivati nell'ultimo mezzo secondo: la musica scorre.
        var flowing: Bool
    }

    func picture() -> Picture {
        lock.lock()
        defer { lock.unlock() }
        let ordered = Array(history[historyHead...] + history[..<historyHead])
        let flowing = ProcessInfo.processInfo.systemUptime - lastSamples < 0.5
        return Picture(wave: wave, history: ordered, source: source, flowing: flowing)
    }

    // MARK: collegamento al player

    /// Mette il tap sulla traccia audio dell'elemento appena creato. Le tracce
    /// di uno stream arrivano solo quando il player ha letto i primi dati.
    func attach(to item: AVPlayerItem) {
        reset(.idle)
        Task {
            let tracks = (try? await item.asset.loadTracks(withMediaType: .audio)) ?? []
            guard let track = tracks.first, let mix = Self.mix(for: track) else {
                reset(.unsupported)
                return
            }
            await MainActor.run { item.audioMix = mix }
            reset(.listening)
        }
    }

    func detach() {
        reset(.idle)
    }

    private func reset(_ state: Source) {
        lock.lock()
        source = state
        wave = [Float](repeating: 0, count: Self.wavePoints)
        history = [Float](repeating: 0, count: Self.historyLength)
        historyHead = 0
        pendingPeak = 0
        lock.unlock()
    }

    private static func mix(for track: AVAssetTrack) -> AVAudioMix? {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(RadioScope.shared).toOpaque()),
            init: { _, clientInfo, storage in storage.pointee = clientInfo },
            finalize: nil,
            prepare: { tap, _, format in
                let scope = Unmanaged<RadioScope>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                scope.setFormat(format.pointee)
            },
            unprepare: nil,
            process: { tap, frames, _, buffers, framesOut, flagsOut in
                guard MTAudioProcessingTapGetSourceAudio(tap, frames, buffers, flagsOut, nil, framesOut) == noErr else { return }
                let scope = Unmanaged<RadioScope>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                scope.ingest(buffers, frames: Int(framesOut.pointee))
            })
        var tap: MTAudioProcessingTap?
        // Prima degli effetti: il volume del player non schiaccia le onde.
        guard MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap) == noErr,
              let tap else { return nil }
        let input = AVMutableAudioMixInputParameters(track: track)
        input.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [input]
        return mix
    }

    // MARK: thread audio

    private func setFormat(_ format: AudioStreamBasicDescription) {
        lock.lock()
        isFloat = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let nonInterleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        interleavedChannels = nonInterleaved ? 1 : max(1, Int(format.mChannelsPerFrame))
        lock.unlock()
    }

    /// Gira sul thread audio: niente allocazioni, solo letture e scritture
    /// negli array gia' pronti.
    private func ingest(_ list: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        guard frames > 0, let first = buffers.first, let data = first.mData else { return }
        lock.lock()
        defer { lock.unlock() }
        let stride = interleavedChannels
        func sample(_ i: Int) -> Float {
            isFloat ? data.assumingMemoryBound(to: Float.self)[i * stride]
                    : Float(data.assumingMemoryBound(to: Int16.self)[i * stride]) / 32768
        }
        var peak: Float = 0
        for p in 0 ..< Self.wavePoints {
            let v = sample(p * frames / Self.wavePoints)
            wave[p] = v
            peak = max(peak, abs(v))
        }
        pendingPeak = max(pendingPeak, peak)
        let now = ProcessInfo.processInfo.systemUptime
        lastSamples = now
        // Una colonna ogni 1/15 di secondo, qualunque sia la misura dei blocchi.
        if now - lastColumn >= 1.0 / 15 {
            lastColumn = now
            history[historyHead] = min(1, pendingPeak)
            historyHead = (historyHead + 1) % Self.historyLength
            pendingPeak = 0
        }
    }
}
