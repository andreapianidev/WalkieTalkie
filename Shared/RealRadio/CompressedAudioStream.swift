//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - CompressedAudioStream.swift
import AudioToolbox
import AVFoundation

//  Portato da RadioKit di Etere (MP3Stream), allargato all'AAC ADTS delle
//  radio che non trasmettono in MP3.

/// Uno stream MP3 o AAC dal vivo, tagliato in pezzi ovunque (anche dentro un
/// frame), decodificato in float mono con Core Audio: AudioFileStream trova i
/// frame, AVAudioConverter li decodifica e li porta a mono.
/// Un'istanza per stream; non thread safe.
nonisolated final class CompressedAudioStream {
    private var stream: AudioFileStreamID?
    private var input: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var bytes = Data()
    private var packets: [AudioStreamPacketDescription] = []

    var sampleRate: Double { input?.sampleRate ?? 0 }

    init?(type: AudioFileTypeID = kAudioFileMP3Type) {
        var id: AudioFileStreamID?
        let status = AudioFileStreamOpen(Unmanaged.passUnretained(self).toOpaque(), { _, _, _, _ in }, { client, count, n, data, descriptions in
            Unmanaged<CompressedAudioStream>.fromOpaque(client).takeUnretainedValue()
                .collect(count: count, packets: n, data: data, descriptions: descriptions)
        }, type, &id)
        guard status == noErr, let id else { return nil }
        stream = id
    }

    deinit {
        if let stream { AudioFileStreamClose(stream) }
    }

    /// Un pezzo di stream; restituisce l'audio che ha completato.
    func decode(_ data: Data) -> [Float] {
        guard let stream, !data.isEmpty else { return [] }
        bytes.removeAll(keepingCapacity: true)
        packets.removeAll(keepingCapacity: true)
        let status = data.withUnsafeBytes { raw in
            AudioFileStreamParseBytes(stream, UInt32(raw.count), raw.baseAddress, [])
        }
        guard status == noErr, !packets.isEmpty, prepare(), let input, let converter else { return [] }

        // Negli stream radio fra un pacchetto e l'altro ci sono byte in piu'
        // (tag ID3, scarti): lo spazio deve bastare per tutti i byte, non solo
        // per il pacchetto piu' grande moltiplicato per il numero di pacchetti.
        let largest = Int(packets.map(\.mDataByteSize).max() ?? 0)
        let perPacket = max(largest, (bytes.count + packets.count - 1) / packets.count, 1)
        let compressed = AVAudioCompressedBuffer(format: input, packetCapacity: AVAudioPacketCount(packets.count),
                                                 maximumPacketSize: perPacket)
        guard compressed.byteCapacity >= bytes.count else { return [] }
        bytes.withUnsafeBytes { raw in
            compressed.data.copyMemory(from: raw.baseAddress!, byteCount: raw.count)
        }
        compressed.byteLength = UInt32(bytes.count)
        compressed.packetCount = AVAudioPacketCount(packets.count)
        if let out = compressed.packetDescriptions {
            for (i, p) in packets.enumerated() { out[i] = p }
        }

        // 1152 campioni per frame MP3, 1024 (o 2048 con HE-AAC) per l'AAC,
        // piu' margine per il ritardo del decoder.
        let capacity = AVAudioFrameCount(packets.count * 2048 + 2304)
        guard let pcm = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return [] }
        var fed = false
        var error: NSError?
        converter.convert(to: pcm, error: &error) { _, state in
            if fed {
                state.pointee = .noDataNow
                return nil
            }
            fed = true
            state.pointee = .haveData
            return compressed
        }
        guard error == nil, let ch = pcm.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: ch[0], count: Int(pcm.frameLength)))
    }

    private func collect(count: UInt32, packets n: UInt32, data: UnsafeRawPointer,
                         descriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?) {
        // MP3 e AAC arrivano sempre con le descrizioni dei pacchetti: senza,
        // non si distinguono i frame.
        guard let descriptions, n > 0 else { return }
        let base = Int64(bytes.count)
        bytes.append(data.assumingMemoryBound(to: UInt8.self), count: Int(count))
        for i in 0 ..< Int(n) {
            var p = descriptions[i]
            p.mStartOffset += base
            packets.append(p)
        }
    }

    /// Il convertitore aspetta che lo stream dica cosa trasporta.
    private func prepare() -> Bool {
        if converter != nil { return true }
        guard let stream else { return false }
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_DataFormat, &size, &asbd) == noErr,
              asbd.mSampleRate > 0,
              let i = AVAudioFormat(streamDescription: &asbd),
              let o = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: asbd.mSampleRate, channels: 1, interleaved: false),
              let c = AVAudioConverter(from: i, to: o) else { return false }
        c.downmix = true
        input = i
        converter = c
        return true
    }
}
