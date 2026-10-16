//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - LivePlayer.swift
//  Talky
//
//  Altoparlante dell'ascolto dal vivo: ricampiona a 48 kHz e mette in coda
//  con un piccolo cuscino contro il jitter di rete. Ridotto da AudioDeck di
//  Etere: niente microfono, niente fruscio aggiunto, niente registrazione.
//  Quello che si sente arriva tutto dal ricevitore o dal canale.

import AVFoundation

nonisolated final class LivePlayer: @unchecked Sendable {
    static let outputRate = 48_000.0

    private let queue = DispatchQueue(label: "talky live player", qos: .userInitiated)
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let output = AVAudioFormat(standardFormatWithSampleRate: LivePlayer.outputRate, channels: 1)!

    private var converter: AVAudioConverter?
    private var converterRate = 0.0
    private var holding: [AVAudioPCMBuffer] = []
    private var holdingFrames: AVAudioFramePosition = 0
    private let backlog = Backlog()
    private var live = false

    /// Cuscino prima di partire, per assorbire il jitter di rete.
    private let preroll = AVAudioFramePosition(LivePlayer.outputRate * 0.25)
    /// Oltre questo ritardo si scarta invece di accumulare.
    private let ceiling = AVAudioFramePosition(LivePlayer.outputRate * 1.0)

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: output)
        #if os(iOS)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                               object: nil, queue: nil) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            self?.resume()
        }
        #endif
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
                                               object: engine, queue: nil) { [weak self] _ in
            self?.resume()
        }
    }

    func start() {
        queue.async { [self] in
            live = true
            guard !engine.isRunning else { return }
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            engine.prepare()
            try? engine.start()
        }
    }

    func stop() {
        queue.async { [self] in
            live = false
            player.stop()
            engine.stop()
            reset()
        }
    }

    /// Svuota la coda, per un cambio di canale.
    func flush() {
        queue.async { [self] in
            player.stop()
            reset()
        }
    }

    /// 0...1.
    func setVolume(_ v: Float) {
        queue.async { [self] in player.volume = max(0, min(1, v)) }
    }

    func play(_ chunk: PCMChunk) {
        queue.async { [self] in
            guard live, let buf = resample(chunk) else { return }
            if !engine.isRunning { try? engine.start() }
            let queued = backlog.value
            if queued > ceiling { return }

            // Coda vuota (inizio di un passaggio o un buco di rete): si
            // ricostruisce un po' di cuscino prima di suonare.
            if queued == 0 {
                holding.append(buf)
                holdingFrames += AVAudioFramePosition(buf.frameLength)
                guard holdingFrames >= preroll else { return }
                let batch = holding
                holding = []
                holdingFrames = 0
                batch.forEach(schedule)
                if !player.isPlaying { player.play() }
                return
            }
            schedule(buf)
        }
    }

    private func resume() {
        queue.async { [self] in
            guard live else { return }
            player.stop()
            reset()
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            engine.prepare()
            try? engine.start()
        }
    }

    private func schedule(_ buf: AVAudioPCMBuffer) {
        let n = AVAudioFramePosition(buf.frameLength)
        backlog.add(n)
        player.scheduleBuffer(buf, completionCallbackType: .dataConsumed) { [backlog] _ in
            backlog.add(-n)
        }
    }

    private func reset() {
        holding = []
        holdingFrames = 0
        backlog.clear()
    }

    private func resample(_ chunk: PCMChunk) -> AVAudioPCMBuffer? {
        guard !chunk.samples.isEmpty,
              let inFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: chunk.sampleRate, channels: 1, interleaved: false),
              let src = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: AVAudioFrameCount(chunk.samples.count)) else { return nil }
        src.frameLength = AVAudioFrameCount(chunk.samples.count)
        chunk.samples.withUnsafeBufferPointer { src.floatChannelData![0].update(from: $0.baseAddress!, count: $0.count) }
        if chunk.sampleRate == Self.outputRate { return src }

        if converter == nil || converterRate != chunk.sampleRate {
            converter = AVAudioConverter(from: inFormat, to: output)
            converterRate = chunk.sampleRate
        }
        guard let converter else { return nil }
        let capacity = AVAudioFrameCount(Double(chunk.samples.count) * Self.outputRate / chunk.sampleRate) + 64
        guard let dst = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: dst, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return src
        }
        return error == nil && dst.frameLength > 0 ? dst : nil
    }
}

/// Fotogrammi in coda nel player, toccati anche dal thread audio.
nonisolated private final class Backlog: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: AVAudioFramePosition = 0

    var value: AVAudioFramePosition {
        lock.lock()
        defer { lock.unlock() }
        return frames
    }

    func add(_ n: AVAudioFramePosition) {
        lock.lock()
        frames = max(0, frames + n)
        lock.unlock()
    }

    func clear() {
        lock.lock()
        frames = 0
        lock.unlock()
    }
}
