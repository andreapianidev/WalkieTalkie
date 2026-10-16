//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - MumbleWire.swift
//  Talky
//
//  Formato del canale di controllo Mumble, portato da RadioKit di Etere.

import Foundation

// Mumble control channel: TLS over TCP, each message is a 2-byte type and a
// 4-byte length (both big endian) followed by a protobuf body. Voice travels in
// UDPTunnel messages whose body is the raw UDP voice packet, not protobuf
// (src/mumble/ServerHandler.cpp, sendMessage and message()).

nonisolated enum MumbleMessage: UInt16 {
    case version = 0
    case udpTunnel = 1
    case authenticate = 2
    case ping = 3
    case reject = 4
    case serverSync = 5
    case channelRemove = 6
    case channelState = 7
    case userRemove = 8
    case userState = 9
    case textMessage = 11
    case permissionDenied = 12
    case cryptSetup = 15
    case codecVersion = 21
    case serverConfig = 24
}

/// Splits a TCP byte stream into whole Mumble messages.
nonisolated struct MumbleFramer {
    private var buffer = Data()

    mutating func push(_ data: Data) -> [(type: UInt16, body: Data)] {
        buffer.append(data)
        var out: [(UInt16, Data)] = []
        while buffer.count >= 6 {
            let b = buffer.startIndex
            let type = UInt16(buffer[b]) << 8 | UInt16(buffer[b + 1])
            let len = Int(buffer[b + 2]) << 24 | Int(buffer[b + 3]) << 16 | Int(buffer[b + 4]) << 8 | Int(buffer[b + 5])
            guard len <= 8 << 20 else {
                buffer.removeAll()
                break
            }
            guard buffer.count >= 6 + len else { break }
            out.append((type, Data(buffer[(b + 6) ..< (b + 6 + len)])))
            buffer.removeFirst(6 + len)
        }
        return out
    }

    static func frame(_ type: MumbleMessage, _ body: Data) -> Data {
        var d = Data(capacity: body.count + 6)
        let t = type.rawValue
        let n = UInt32(body.count)
        d.append(contentsOf: [UInt8(t >> 8), UInt8(t & 0xFF),
                              UInt8(n >> 24), UInt8((n >> 16) & 0xFF), UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)])
        d.append(body)
        return d
    }
}

// MARK: protobuf, by hand, only what the client needs

nonisolated struct ProtoWriter {
    private(set) var data = Data()

    mutating func varint(_ field: Int, _ value: UInt64) {
        key(field, 0)
        raw(value)
    }

    mutating func bool(_ field: Int, _ value: Bool) { varint(field, value ? 1 : 0) }

    mutating func bytes(_ field: Int, _ value: Data) {
        key(field, 2)
        raw(UInt64(value.count))
        data.append(value)
    }

    mutating func string(_ field: Int, _ value: String) { bytes(field, Data(value.utf8)) }

    private mutating func key(_ field: Int, _ wire: UInt64) { raw(UInt64(field) << 3 | wire) }

    private mutating func raw(_ v: UInt64) {
        var v = v
        while v >= 0x80 {
            data.append(UInt8(v & 0x7F) | 0x80)
            v >>= 7
        }
        data.append(UInt8(v))
    }
}

/// Flat field map of one protobuf message. Repeated fields keep every value.
nonisolated struct ProtoFields {
    enum Value {
        case int(UInt64)
        case bytes(Data)
        case fixed32(UInt32)
        case fixed64(UInt64)
    }

    private(set) var fields: [Int: [Value]] = [:]

    init?(_ data: Data) {
        let b = [UInt8](data)
        var i = 0
        func next() -> UInt64? {
            var v: UInt64 = 0
            var shift: UInt64 = 0
            while i < b.count, shift < 64 {
                let x = b[i]
                i += 1
                v |= UInt64(x & 0x7F) << shift
                if x & 0x80 == 0 { return v }
                shift += 7
            }
            return nil
        }
        while i < b.count {
            guard let key = next() else { return nil }
            let field = Int(key >> 3)
            switch key & 7 {
            case 0:
                guard let v = next() else { return nil }
                fields[field, default: []].append(.int(v))
            case 1:
                guard i + 8 <= b.count else { return nil }
                var v: UInt64 = 0
                for k in 0 ..< 8 { v |= UInt64(b[i + k]) << (8 * UInt64(k)) }
                i += 8
                fields[field, default: []].append(.fixed64(v))
            case 2:
                guard let n = next(), i + Int(n) <= b.count else { return nil }
                fields[field, default: []].append(.bytes(Data(b[i ..< i + Int(n)])))
                i += Int(n)
            case 5:
                guard i + 4 <= b.count else { return nil }
                var v: UInt32 = 0
                for k in 0 ..< 4 { v |= UInt32(b[i + k]) << (8 * UInt32(k)) }
                i += 4
                fields[field, default: []].append(.fixed32(v))
            default:
                return nil
            }
        }
    }

    func int(_ f: Int) -> UInt64? {
        if case .int(let v) = fields[f]?.last { return v }
        return nil
    }

    func uint32(_ f: Int) -> UInt32? { int(f).map { UInt32(truncatingIfNeeded: $0) } }

    func bool(_ f: Int) -> Bool? { int(f).map { $0 != 0 } }

    func data(_ f: Int) -> Data? {
        if case .bytes(let v) = fields[f]?.last { return v }
        return nil
    }

    func string(_ f: Int) -> String? { data(f).map { String(decoding: $0, as: UTF8.self) } }

    func has(_ f: Int) -> Bool { fields[f] != nil }
}

// MARK: messages (field numbers from src/Mumble.proto)

nonisolated enum MumbleVersion {
    static let ours: (major: UInt64, minor: UInt64, patch: UInt64) = (1, 5, 0)

    static func v1(_ major: UInt64, _ minor: UInt64, _ patch: UInt64) -> UInt64 { major << 16 | minor << 8 | patch }
    static func v2(_ major: UInt64, _ minor: UInt64, _ patch: UInt64) -> UInt64 { major << 48 | minor << 32 | patch << 16 }

    /// 1.5.0 is where the protobuf voice format starts (PROTOBUF_INTRODUCTION_VERSION).
    static let protobufVoice = v2(1, 5, 0)

    /// Server Version message to the new 64-bit form.
    static func parse(_ f: ProtoFields) -> UInt64 {
        if let v = f.int(5), v != 0 { return v }
        guard let v = f.int(1) else { return 0 }
        return v2((v >> 16) & 0xFFFF, (v >> 8) & 0xFF, v & 0xFF)
    }
}

nonisolated enum MumbleControl {
    static func version() -> Data {
        var w = ProtoWriter()
        let v = MumbleVersion.ours
        w.varint(1, MumbleVersion.v1(v.major, v.minor, v.patch))
        w.string(2, "Talky")
        #if os(iOS)
        w.string(3, "iOS")
        #else
        w.string(3, "macOS")
        #endif
        w.string(4, ProcessInfo.processInfo.operatingSystemVersionString)
        w.varint(5, MumbleVersion.v2(v.major, v.minor, v.patch))
        return MumbleFramer.frame(.version, w.data)
    }

    static func authenticate(user: String, password: String) -> Data {
        var w = ProtoWriter()
        w.string(1, user)
        if !password.isEmpty { w.string(2, password) }
        w.bool(5, true)       // opus
        return MumbleFramer.frame(.authenticate, w.data)
    }

    static func ping(_ timestamp: UInt64) -> Data {
        var w = ProtoWriter()
        w.varint(1, timestamp)
        return MumbleFramer.frame(.ping, w.data)
    }

    /// Moves our own user to another channel.
    static func join(session: UInt32, channel: UInt32) -> Data {
        var w = ProtoWriter()
        w.varint(1, UInt64(session))
        w.varint(5, UInt64(channel))
        return MumbleFramer.frame(.userState, w.data)
    }

    /// Mette noi stessi in muto: Talky su Mumble ascolta soltanto, e gli
    /// altri lo vedono dall'icona accanto al nome.
    static func selfMute(session: UInt32) -> Data {
        var w = ProtoWriter()
        w.varint(1, UInt64(session))
        w.bool(9, true)       // self_mute
        return MumbleFramer.frame(.userState, w.data)
    }

    /// Reject.RejectType tradotto nei problemi che l'interfaccia sa dire.
    static func problem(_ type: UInt64?) -> LiveProblem {
        switch type {
        case 6: .full
        case 7: .needsCertificate
        default: .refused
        }
    }
}

nonisolated struct MumbleChannel: Sendable, Equatable {
    var id: UInt32
    var parent: UInt32?
    var name: String
}

nonisolated struct MumbleUser: Sendable, Equatable {
    var session: UInt32
    var name: String
    var channel: UInt32
}

// MARK: voice packets

/// Mumble's own variable-length integer (src/PacketDataStream.h), used by the
/// legacy voice format. Not the protobuf varint.
nonisolated enum MumbleVarint {
    /// Reads one value at `at`, moving it past the bytes used.
    static func decode(_ b: [UInt8], at i: inout Int, depth: Int = 0) -> UInt64? {
        func next() -> UInt64? {
            guard i < b.count else { return nil }
            defer { i += 1 }
            return UInt64(b[i])
        }
        guard let v = next() else { return nil }
        if v & 0x80 == 0 { return v & 0x7F }
        if v & 0xC0 == 0x80 { return next().map { (v & 0x3F) << 8 | $0 } }
        if v & 0xF0 == 0xF0 {
            switch v & 0xFC {
            case 0xF0:
                return take(4)
            case 0xF4:
                return take(8)
            case 0xF8:
                guard depth < 8, let inner = decode(b, at: &i, depth: depth + 1) else { return nil }
                return ~inner
            case 0xFC:
                return ~(v & 0x03)
            default:
                return nil
            }
        }
        if v & 0xF0 == 0xE0 { return take(3).map { (v & 0x0F) << 24 | $0 } }
        if v & 0xE0 == 0xC0 { return take(2).map { (v & 0x1F) << 16 | $0 } }
        return nil

        func take(_ n: Int) -> UInt64? {
            guard i + n <= b.count else { return nil }
            var r: UInt64 = 0
            for k in 0 ..< n { r = r << 8 | UInt64(b[i + k]) }
            i += n
            return r
        }
    }
}

nonisolated struct MumbleVoice: Equatable {
    var session: UInt32
    var sequence: UInt64
    var opus: Data
    var last: Bool
}

nonisolated enum MumbleVoicePacket {
    static let opusType: UInt8 = 4

    /// Server to client. Returns nil for pings and non-Opus codecs.
    static func parse(_ packet: Data, protobuf: Bool) -> MumbleVoice? {
        let b = [UInt8](packet)
        guard b.count > 1 else { return nil }
        if protobuf {
            guard b[0] == 0, let f = ProtoFields(Data(b[1...])), let opus = f.data(5) else { return nil }
            return MumbleVoice(session: f.uint32(3) ?? 0, sequence: f.int(4) ?? 0, opus: opus, last: f.bool(16) ?? false)
        }
        guard b[0] >> 5 == opusType else { return nil }
        var i = 1
        guard let session = MumbleVarint.decode(b, at: &i),
              let sequence = MumbleVarint.decode(b, at: &i),
              let header = MumbleVarint.decode(b, at: &i) else { return nil }
        let size = Int(header & 0x1FFF)
        guard i + size <= b.count else { return nil }
        return MumbleVoice(session: UInt32(truncatingIfNeeded: session), sequence: sequence,
                           opus: Data(b[i ..< i + size]), last: header & 0x2000 != 0)
    }
}

/// Opus TOC byte (RFC 6716, section 3.1): how many 48 kHz samples a packet holds.
nonisolated enum OpusTOC {
    static func samples(_ packet: Data) -> Int? {
        guard let toc = packet.first else { return nil }
        let config = Int(toc >> 3)
        let perFrame: Int
        switch config {
        case 0 ... 11: perFrame = [480, 960, 1920, 2880][config % 4]
        case 12 ... 15: perFrame = [480, 960][config % 2]
        default: perFrame = [120, 240, 480, 960][config % 4]
        }
        let frames: Int
        switch toc & 0x03 {
        case 0: frames = 1
        case 1, 2: frames = 2
        default:
            guard packet.count > 1 else { return nil }
            frames = Int(packet[packet.startIndex + 1] & 0x3F)
        }
        guard frames > 0 else { return nil }
        return perFrame * frames
    }
}


