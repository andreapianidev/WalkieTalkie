//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - MumbleTalk.swift
//  Talky (iOS e Mac)
//
//  La meta' di Mumble che mancava: parlare. Il microfono diventa Opus a
//  20 ms con il codec di Core Audio, i pacchetti viaggiano nello stesso
//  canale TLS dell'ascolto (UDPTunnel), come fanno i client Mumble quando
//  l'UDP non passa. Niente UDP vuol dire niente crittografia OCB2 da fare a
//  mano, e la voce attraversa anche le reti che lasciano passare solo TCP.

import AVFoundation
import CryptoKit
import Foundation

// MARK: pacchetti in uscita

nonisolated enum MumbleOutgoingVoice {
    /// Pacchetto voce client -> server, il corpo di un UDPTunnel.
    /// Dal 1.5 in su protobuf (MumbleUDP.Audio), prima il formato a byte
    /// di src/mumble/AudioInput.cpp: intestazione, sequenza, lunghezza Opus.
    static func packet(opus: Data, sequence: UInt64, last: Bool, protobuf: Bool) -> Data {
        if protobuf {
            var w = ProtoWriter()
            w.varint(1, 0)              // target: si parla al canale
            w.varint(4, sequence)       // frame_number
            w.bytes(5, opus)            // opus_data
            if last { w.bool(16, true) } // is_terminator
            var d = Data([0])           // tipo Audio
            d.append(w.data)
            return d
        }
        var d = Data([MumbleVoicePacket.opusType << 5])
        d.append(MumbleVarint.encode(sequence))
        d.append(MumbleVarint.encode(UInt64(opus.count) | (last ? 0x2000 : 0)))
        d.append(opus)
        return d
    }

    static func tunnel(_ packet: Data) -> Data { MumbleFramer.frame(.udpTunnel, packet) }
}

nonisolated extension MumbleVarint {
    static func encode(_ v: UInt64) -> Data {
        switch v {
        case 0 ..< 0x80:
            return Data([UInt8(v)])
        case 0x80 ..< 0x4000:
            return Data([UInt8(0x80 | (v >> 8)), UInt8(v & 0xFF)])
        case 0x4000 ..< 0x20_0000:
            return Data([UInt8(0xC0 | (v >> 16)), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
        case 0x20_0000 ..< 0x1000_0000:
            return Data([UInt8(0xE0 | (v >> 24)), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
        case 0x1000_0000 ... 0xFFFF_FFFF:
            return Data([0xF0, UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
        default:
            var d = Data([0xF4])
            for shift in stride(from: 56, through: 0, by: -8) { d.append(UInt8((v >> UInt64(shift)) & 0xFF)) }
            return d
        }
    }
}

nonisolated extension MumbleControl {
    /// Muto acceso o spento: il server scarta la voce di chi e' in muto,
    /// quindi si toglie solo per il tempo del passaggio.
    static func selfMute(session: UInt32, on: Bool) -> Data {
        var w = ProtoWriter()
        w.varint(1, UInt64(session))
        w.bool(9, on)
        return MumbleFramer.frame(.userState, w.data)
    }

    /// Chiede cosa possiamo fare in un canale; la risposta arriva come
    /// PermissionQuery con la maschera dei permessi.
    static func permissionQuery(channel: UInt32) -> Data {
        var w = ProtoWriter()
        w.varint(1, UInt64(channel))
        return MumbleFramer.frame(.permissionQuery, w.data)
    }

    /// ChanACL::Speak in src/ACL.h.
    static let speakPermission: UInt32 = 0x8
}

// MARK: codifica Opus

/// Opus con il codec di Core Audio, come il decoder accanto: niente
/// libopus a bordo. 20 ms per pacchetto, voce mono a 48 kHz.
nonisolated final class OpusEncoder {
    static let rate = 48_000.0
    static let frames: AVAudioFrameCount = 960

    private let converter: AVAudioConverter
    private let input: AVAudioFormat
    private let output: AVAudioFormat

    init?(bitRate: Int = 32_000) {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: Self.rate, mFormatID: kAudioFormatOpus, mFormatFlags: 0, mBytesPerPacket: 0,
            mFramesPerPacket: Self.frames, mBytesPerFrame: 0, mChannelsPerFrame: 1,
            mBitsPerChannel: 0, mReserved: 0)
        guard let i = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.rate, channels: 1, interleaved: false),
              let o = AVAudioFormat(streamDescription: &asbd),
              let c = AVAudioConverter(from: i, to: o) else { return nil }
        c.bitRate = bitRate
        input = i
        output = o
        converter = c
    }

    /// Esattamente `frames` campioni in, un pacchetto Opus fuori.
    func encode(_ samples: [Float]) -> Data? {
        guard samples.count == Int(Self.frames),
              let pcm = AVAudioPCMBuffer(pcmFormat: input, frameCapacity: Self.frames),
              let ch = pcm.floatChannelData else { return nil }
        pcm.frameLength = Self.frames
        samples.withUnsafeBufferPointer { ch[0].update(from: $0.baseAddress!, count: samples.count) }

        let size = max(converter.maximumOutputPacketSize, 1500)
        let out = AVAudioCompressedBuffer(format: output, packetCapacity: 1, maximumPacketSize: size)
        var fed = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, state in
            if fed {
                state.pointee = .noDataNow
                return nil
            }
            fed = true
            state.pointee = .haveData
            return pcm
        }
        guard error == nil, status != .error, out.packetCount > 0, out.byteLength > 0 else { return nil }
        return Data(bytes: out.data, count: Int(out.byteLength))
    }
}

// MARK: microfono

/// Microfono per il POC e le stanze: blocchi da 20 ms a 48 kHz mono, gia'
/// codificati in Opus. Un motore suo, separato da quello che suona, cosi'
/// accenderlo e spegnerlo non interrompe l'ascolto.
nonisolated final class MumbleMic: @unchecked Sendable {
    private let queue = DispatchQueue(label: "talky mumble mic", qos: .userInteractive)
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var encoder: OpusEncoder?
    private var pending: [Float] = []
    private var onPacket: ((Data) -> Void)?
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: OpusEncoder.rate, channels: 1, interleaved: false)!

    /// Chiede il permesso del microfono se serve. Falso se negato.
    static func requestAccess() async -> Bool {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        }
        return await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
        #else
        return await AVCaptureDevice.requestAccess(for: .audio)
        #endif
    }

    /// Accende il microfono; `packet` riceve un pacchetto Opus ogni 20 ms.
    /// `systemSession`: la sessione audio l'ha gia' attivata Push to Talk,
    /// che non vuole che l'app la tocchi.
    func start(systemSession: Bool = false, _ packet: @escaping (Data) -> Void) -> Bool {
        queue.sync {
            #if os(iOS)
            if !systemSession {
                let session = AVAudioSession.sharedInstance()
                if session.category != .playAndRecord {
                    try? session.setCategory(.playAndRecord, mode: .default,
                                             options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
                }
                try? session.setActive(true)
            }
            #endif
            if encoder == nil { encoder = OpusEncoder() }
            guard encoder != nil else { return false }
            onPacket = packet
            pending = []
            let node = engine.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { return false }
            converter = AVAudioConverter(from: format, to: target)
            node.removeTap(onBus: 0)
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.queue.async { self?.ingest(buffer) }
            }
            engine.prepare()
            do {
                try engine.start()
                return true
            } catch {
                node.removeTap(onBus: 0)
                return false
            }
        }
    }

    func stop() {
        queue.sync {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            onPacket = nil
            pending = []
        }
    }

    private func ingest(_ buffer: AVAudioPCMBuffer) {
        guard let converter, let encoder, let onPacket else { return }
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, state in
            if fed {
                state.pointee = .noDataNow
                return nil
            }
            fed = true
            state.pointee = .haveData
            return buffer
        }
        guard error == nil, let ch = out.floatChannelData else { return }
        pending.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: Int(out.frameLength)))
        let n = Int(OpusEncoder.frames)
        while pending.count >= n {
            let frame = Array(pending.prefix(n))
            pending.removeFirst(n)
            if let opus = encoder.encode(frame) { onPacket(opus) }
        }
    }
}

// MARK: regole e moderazione

/// Quello che Apple chiede a un'app dove si parla con sconosciuti (linea
/// guida 1.2): regole accettate prima di parlare, chi disturba si silenzia
/// da soli, una segnalazione che arriva a chi gestisce Talky. I server
/// pubblici li moderano i loro amministratori; un server segnalato sparisce
/// dalla lista di chi l'ha segnalato.
nonisolated enum MumbleManners {
    private static let defaults = UserDefaults.standard
    private static let rulesKey = "mumble_rules_accepted"
    private static let nickKey = "mumble_nickname"
    private static let blockedKey = "mumble_blocked"
    private static let hiddenKey = "mumble_hidden_servers"

    static var rulesAccepted: Bool {
        get { defaults.bool(forKey: rulesKey) }
        set { defaults.set(newValue, forKey: rulesKey) }
    }

    /// Il nome con cui si entra nei canali, scelto dall'utente. Il primo
    /// avvio ne inventa uno e lo tiene, cosi' chi ascolta lo riconosce.
    static var nickname: String {
        get {
            if let n = defaults.string(forKey: nickKey), !n.isEmpty { return n }
            let n = "Talky-\(Int.random(in: 1000 ... 9999))"
            defaults.set(n, forKey: nickKey)
            return n
        }
        set { defaults.set(clean(newValue), forKey: nickKey) }
    }

    /// Lettere, cifre, trattino e trattino basso, al massimo 24: quello che
    /// accetta l'espressione predefinita dei nomi in mumble-server.
    static func clean(_ raw: String) -> String {
        let ok = raw.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
        let s = String(String.UnicodeScalarView(ok)).prefix(24)
        return s.isEmpty ? "Talky-\(Int.random(in: 1000 ... 9999))" : String(s)
    }

    /// Chi si e' silenziato, per server: "host:porta|nome".
    static func isBlocked(_ name: String, on server: String) -> Bool {
        blocked.contains(key(name, server))
    }

    static func block(_ name: String, on server: String) {
        var b = blocked
        b.insert(key(name, server))
        defaults.set(Array(b), forKey: blockedKey)
    }

    static var hiddenServers: Set<String> {
        Set(defaults.stringArray(forKey: hiddenKey) ?? [])
    }

    static func hide(server: String) {
        var h = hiddenServers
        h.insert(server)
        defaults.set(Array(h), forKey: hiddenKey)
    }

    private static var blocked: Set<String> { Set(defaults.stringArray(forKey: blockedKey) ?? []) }
    private static func key(_ name: String, _ server: String) -> String { "\(server)|\(name.lowercased())" }
}

// MARK: stanze private

/// Una stanza privata sul server Mumble di Talky (VM2, scripts/server/).
/// Dal codice che ci si scambia si ricavano due cose diverse: il nome del
/// canale, che vedono tutti quelli collegati al server, e il token che
/// apre la porta, che arriva solo al custode in un messaggio privato. Le
/// stesse derivazioni stanno in scripts/server/talky_rooms.py (prova).
nonisolated struct TalkyRoom: Sendable, Hashable {
    /// Otto caratteri senza 0, 1, I, L, O: si dettano al telefono senza errori.
    let code: String

    static let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
    /// Il server delle stanze. La 22 perche' e' l'unica porta che la rete
    /// Oracle lascia passare; sulla VM e' girata sulla 64738 di mumble-server.
    static let server = MumbleServer(name: "Talky", host: "92.5.15.244", port: 22, country: "", countryCode: "")

    init?(code raw: String) {
        let clean = raw.uppercased().filter { Self.alphabet.contains($0) }
        guard clean.count == 8 else { return nil }
        code = clean
    }

    static func make() -> TalkyRoom {
        var g = SystemRandomNumberGenerator()
        return TalkyRoom(code: String((0 ..< 8).map { _ in alphabet.randomElement(using: &g)! }))!
    }

    /// "K7P2-QX9A", come si mostra e si condivide.
    var display: String { "\(code.prefix(4))-\(code.suffix(4))" }

    var channelName: String { "room-" + Self.hex("talky-room-name:" + code).prefix(16) }
    var token: String { String(Self.hex("talky-room-token:" + code).prefix(32)) }

    var target: MumbleLiveChannel { MumbleLiveChannel(server: Self.server, channel: channelName, users: 0) }

    /// Link d'invito: apre Talky nella stanza; chi non ce l'ha usa il codice.
    var link: URL { URL(string: "talky://room/\(code)")! }

    private static func hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated extension MumbleControl {
    /// Authenticate con i token d'accesso (campo 3, ripetuto).
    static func authenticate(user: String, tokens: [String]) -> Data {
        var w = ProtoWriter()
        w.string(1, user)
        for t in tokens { w.string(3, t) }
        w.bool(5, true)
        return MumbleFramer.frame(.authenticate, w.data)
    }

    /// Messaggio privato a una sessione (TextMessage, campi session 2 e message 5).
    static func text(to session: UInt32, _ message: String) -> Data {
        var w = ProtoWriter()
        w.varint(2, UInt64(session))
        w.string(5, message)
        return MumbleFramer.frame(.textMessage, w.data)
    }
}
