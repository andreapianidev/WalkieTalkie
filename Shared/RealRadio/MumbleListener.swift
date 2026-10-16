//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - MumbleListener.swift
//  Talky
//
//  POC vero: canali pubblici Mumble, solo in ascolto. Accesso anonimo con
//  un nome Talky, microfono mai aperto, noi stessi in muto. Portato da
//  RadioKit di Etere.

import AVFoundation

/// Un server dell'elenco pubblico di mumble.info.
nonisolated struct MumbleServer: Sendable, Equatable, Hashable, Codable, Identifiable {
    var name: String
    var host: String
    var port: UInt16
    var country: String
    var countryCode: String

    var id: String { "\(host):\(port)" }
}

@available(iOS 16.0, macOS 13.0, *)
nonisolated enum MumbleDirectory {
    // publist.mumble.info/v1/list e' quello che chiede il client 1.5; a ottobre
    // 2026 rispondeva 501 a corpo vuoto, mentre list2.cgi dava lo stesso XML.
    static let sources = [
        URL(string: "https://publist.mumble.info/v1/list")!,
        URL(string: "https://mumble.info/list2.cgi")!
    ]

    static func fetch() async throws -> [MumbleServer] {
        var lastError: Error = LinkError.timeout
        for url in sources {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                let list = parse(data)
                guard !list.isEmpty else { continue }
                if let json = try? JSONEncoder().encode(list) { try? json.write(to: cacheFile, options: .atomic) }
                return list
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    static func cached() -> [MumbleServer] {
        guard let data = try? Data(contentsOf: cacheFile) else { return [] }
        return (try? JSONDecoder().decode([MumbleServer].self, from: data)) ?? []
    }

    /// `<server name=".." ip=".." port=".." country=".." country_code=".." .../>`
    static func parse(_ data: Data) -> [MumbleServer] {
        let reader = ServerListReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.parse()
        return reader.servers
    }

    private static var cacheFile: URL {
        let dir = URL.cachesDirectory.appending(path: "Talky", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "mumble.json")
    }
}

nonisolated private final class ServerListReader: NSObject, XMLParserDelegate {
    var servers: [MumbleServer] = []

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes a: [String: String] = [:]) {
        guard name == "server", let host = a["ip"], !host.isEmpty,
              let port = UInt16(a["port"] ?? "64738") else { return }
        servers.append(MumbleServer(name: a["name"] ?? host, host: host, port: port,
                                    country: a["country"] ?? "", countryCode: a["country_code"] ?? ""))
    }
}

/// Un canale con qualcuno dentro, trovato leggendo l'albero di un server.
nonisolated struct MumbleLiveChannel: Sendable, Equatable, Hashable, Identifiable {
    var server: MumbleServer
    var channel: String
    var users: Int

    var id: String { "\(server.id)/\(channel)" }
}

/// Entra il tempo di leggere l'albero dei canali e chi c'e' dentro, poi esce.
@available(iOS 16.0, macOS 13.0, *)
nonisolated enum MumbleScout {
    static func liveChannels(on server: MumbleServer, username: String) async throws -> [MumbleLiveChannel] {
        let link = StreamLink(host: server.host, port: server.port)
        try await link.open(timeout: .seconds(6))
        defer { link.close() }
        link.send(MumbleControl.version())
        link.send(MumbleControl.authenticate(user: username, password: ""))

        let reading = Task { () throws -> (channels: [UInt32: MumbleChannel], seats: [UInt32: UInt32], me: UInt32?)? in
            var framer = MumbleFramer()
            var channels: [UInt32: MumbleChannel] = [:]
            var seats: [UInt32: UInt32] = [:]
            for try await bytes in link.bytes {
                for (type, body) in framer.push(bytes) {
                    guard let kind = MumbleMessage(rawValue: type), let f = ProtoFields(body) else { continue }
                    switch kind {
                    case .channelState:
                        guard let id = f.uint32(1) else { continue }
                        var c = channels[id] ?? MumbleChannel(id: id, parent: nil, name: "")
                        if let p = f.uint32(2) { c.parent = p }
                        if let n = f.string(3) { c.name = n }
                        channels[id] = c
                    case .userState:
                        if let s = f.uint32(1) { seats[s] = f.uint32(5) ?? seats[s] ?? 0 }
                    case .serverSync:
                        return (channels, seats, f.uint32(1))
                    case .reject:
                        throw LinkError.closed(MumbleControl.problem(f.int(1)))
                    default:
                        continue
                    }
                }
            }
            return nil
        }
        let timeout = Task {
            try? await Task.sleep(for: .seconds(8))
            reading.cancel()
            link.close()
        }
        defer { timeout.cancel() }
        guard let tree = try await reading.value else { throw LinkError.timeout }

        var counts: [UInt32: Int] = [:]
        for (session, channel) in tree.seats where session != tree.me {
            counts[channel, default: 0] += 1
        }
        return counts.compactMap { id, users in
            guard let name = tree.channels[id]?.name, !MumbleListener.isIdle(name) else { return nil }
            return MumbleLiveChannel(server: server, channel: name, users: users)
        }
        .sorted { $0.users > $1.users }
    }
}

/// Mumble sul canale di controllo TLS, voce nei messaggi UDPTunnel.
/// Come su un canale PTT, parla uno alla volta: la voce di altri viene
/// scartata finche' il passaggio in corso non finisce.
@available(iOS 16.0, macOS 13.0, *)
actor MumbleListener {
    nonisolated let audio: AsyncStream<PCMChunk>
    nonisolated let events: AsyncStream<LiveEvent>
    nonisolated let target: MumbleLiveChannel

    static let rate = 48_000.0

    private let audioSink: AsyncStream<PCMChunk>.Continuation
    private let eventSink: AsyncStream<LiveEvent>.Continuation
    private var username: String

    private var link: StreamLink?
    private var framer = MumbleFramer()
    private var tasks: [Task<Void, Never>] = []
    private var serverVersion: UInt64 = 0
    private var session: UInt32?
    private var synced = false
    private var renamed = false
    private var channels: [UInt32: MumbleChannel] = [:]
    private var users: [UInt32: MumbleUser] = [:]
    private var lastHeard = ContinuousClock.now
    private var lastPing = ContinuousClock.now

    private var floor: UInt32?
    private var floorHeard = ContinuousClock.now
    private var decoders: [Int: OpusDecoder] = [:]

    init(target: MumbleLiveChannel, username: String) {
        self.target = target
        self.username = username
        (audio, audioSink) = AsyncStream.makeStream(of: PCMChunk.self, bufferingPolicy: .bufferingNewest(64))
        (events, eventSink) = AsyncStream.makeStream(of: LiveEvent.self, bufferingPolicy: .bufferingNewest(128))
    }

    /// Canali da non scegliere da soli: chi c'e' dentro non parla.
    nonisolated static func isIdle(_ name: String) -> Bool {
        let n = name.lowercased()
        return ["afk", "away", "idle", "abwesend", "sleep"].contains { n.contains($0) }
    }

    func connect() async {
        await logon()
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                await self?.watch()
            }
        })
    }

    func disconnect() {
        tasks.forEach { $0.cancel() }
        tasks = []
        hangUp()
        audioSink.finish()
        eventSink.yield(.link(.idle))
        eventSink.finish()
    }

    private var usesProtobuf: Bool { serverVersion >= MumbleVersion.protobufVoice }

    // MARK: sessione

    private func logon() async {
        eventSink.yield(.link(.connecting))
        eventSink.yield(.talker(nil))
        let link = StreamLink(host: target.server.host, port: target.server.port)
        self.link = link
        framer = MumbleFramer()
        do { try await link.open() } catch {
            guard link === self.link else { return }
            eventSink.yield(.link(.dropped(.timeout)))
            return
        }
        guard link === self.link else { return }
        lastHeard = .now
        lastPing = .now
        link.send(MumbleControl.version())
        link.send(MumbleControl.authenticate(user: username, password: ""))
        tasks.append(Task { [weak self] in
            do {
                for try await bytes in link.bytes { await self?.receive(bytes, from: link) }
                await self?.closed(link: link)
            } catch {
                await self?.closed(link: link)
            }
        })
    }

    private func hangUp() {
        link?.close()
        link = nil
        synced = false
        session = nil
        channels = [:]
        users = [:]
        serverVersion = 0
        floor = nil
        decoders = [:]
    }

    private func closed(link: StreamLink) {
        guard link === self.link else { return }
        hangUp()
        eventSink.yield(.link(.dropped(.closed)))
    }

    private func watch() {
        let now = ContinuousClock.now
        if let link {
            if now - lastPing > .seconds(15) {
                lastPing = now
                link.send(MumbleControl.ping(UInt64(Date().timeIntervalSince1970 * 1000)))
            }
            if now - lastHeard > .seconds(45) {
                hangUp()
                eventSink.yield(.link(.dropped(.timeout)))
            }
        }
        if floor != nil, now - floorHeard > .milliseconds(500) { endOfOver() }
    }

    private func receive(_ bytes: Data, from link: StreamLink) async {
        guard link === self.link else { return }
        lastHeard = .now
        for (type, body) in framer.push(bytes) {
            await handle(type, body)
            guard link === self.link else { return }
        }
    }

    private func handle(_ type: UInt16, _ body: Data) async {
        guard let kind = MumbleMessage(rawValue: type) else { return }
        if kind == .udpTunnel {
            voice(body)
            return
        }
        guard let f = ProtoFields(body) else { return }
        switch kind {
        case .version:
            serverVersion = MumbleVersion.parse(f)
        case .reject:
            await rejected(f)
        case .serverSync:
            session = f.uint32(1)
            synced = true
            if let session { link?.send(MumbleControl.selfMute(session: session)) }
            eventSink.yield(.link(.online))
            enterChannel()
        case .channelState:
            guard let id = f.uint32(1) else { return }
            var c = channels[id] ?? MumbleChannel(id: id, parent: nil, name: "")
            if let p = f.uint32(2) { c.parent = p }
            if let n = f.string(3) { c.name = n }
            channels[id] = c
        case .channelRemove:
            if let id = f.uint32(1) { channels[id] = nil }
        case .userState:
            userState(f)
        case .userRemove:
            guard let s = f.uint32(1) else { return }
            if s == session {
                hangUp()
                eventSink.yield(.link(.dropped(.refused)))
                return
            }
            users[s] = nil
            if floor == s { endOfOver() }
            reportAudience()
        default:
            break
        }
    }

    private func rejected(_ f: ProtoFields) async {
        let type = f.int(1)
        if type == 5, !renamed {
            // Nome gia' in uso (spesso una nostra sessione fantasma): un altro tentativo con un suffisso.
            renamed = true
            username += String(Int.random(in: 10 ... 99))
            hangUp()
            await logon()
            return
        }
        hangUp()
        eventSink.yield(.link(.refused(MumbleControl.problem(type))))
    }

    private func userState(_ f: ProtoFields) {
        guard let s = f.uint32(1) else { return }
        var u = users[s] ?? MumbleUser(session: s, name: "", channel: 0)
        if let n = f.string(3) { u.name = n }
        if let c = f.uint32(5) { u.channel = c }
        users[s] = u
        if s == session, f.has(5) { reportChannel() }
        reportAudience()
    }

    /// Entra nel canale scelto; se non c'e' piu', in quello con piu' persone.
    private func enterChannel() {
        guard synced, let link, let session else { return }
        let wanted = target.channel.lowercased()
        let target = channels.values.first { $0.name.lowercased() == wanted } ?? busiest()
        if let target, users[session]?.channel != target.id {
            link.send(MumbleControl.join(session: session, channel: target.id))
        }
        reportChannel()
        reportAudience()
    }

    private func busiest() -> MumbleChannel? {
        var counts: [UInt32: Int] = [:]
        for u in users.values where u.session != session { counts[u.channel, default: 0] += 1 }
        return counts
            .filter { channels[$0.key].map { !Self.isIdle($0.name) } ?? false }
            .max { $0.value < $1.value }
            .flatMap { channels[$0.key] }
    }

    private func reportChannel() {
        guard let session, let here = users[session]?.channel else { return }
        eventSink.yield(.channel(channels[here]?.name ?? target.channel))
    }

    private func reportAudience() {
        guard let session, let here = users[session]?.channel else { return }
        eventSink.yield(.audience(users.values.filter { $0.channel == here && $0.session != session }.count))
    }

    // MARK: voce

    private func voice(_ packet: Data) {
        guard let v = MumbleVoicePacket.parse(packet, protobuf: usesProtobuf) else { return }
        if let floor, floor != v.session { return }
        if floor == nil {
            floor = v.session
            decoders = [:]
            eventSink.yield(.talker(users[v.session]?.name ?? "#\(v.session)"))
        }
        floorHeard = .now
        if !v.opus.isEmpty, let samples = OpusTOC.samples(v.opus) {
            if decoders[samples] == nil {
                decoders[samples] = OpusDecoder(rate: Self.rate, samplesPerPacket: AVAudioFrameCount(samples))
            }
            if let pcm = decoders[samples]?.decode(v.opus), !pcm.isEmpty {
                let chunk = PCMChunk(samples: pcm, sampleRate: Self.rate)
                audioSink.yield(chunk)
                eventSink.yield(.level(chunk.envelope))
            }
        }
        if v.last { endOfOver() }
    }

    private func endOfOver() {
        guard floor != nil else { return }
        floor = nil
        eventSink.yield(.level(0))
        eventSink.yield(.talker(nil))
    }
}

/// Opus con il codec di Core Audio, senza libopus a bordo.
/// Un'istanza per flusso, non thread safe.
nonisolated final class OpusDecoder {
    private let converter: AVAudioConverter
    private let input: AVAudioFormat
    private let output: AVAudioFormat
    private let framesPerPacket: AVAudioFrameCount

    /// Core Audio vuole la durata del pacchetto in anticipo; chi parla su
    /// Mumble sceglie la sua (da 10 a 60 ms), quindi un decoder per durata.
    init?(rate: Double, samplesPerPacket: AVAudioFrameCount) {
        guard rate > 0, samplesPerPacket > 0 else { return nil }
        framesPerPacket = samplesPerPacket
        var asbd = AudioStreamBasicDescription(
            mSampleRate: rate, mFormatID: kAudioFormatOpus, mFormatFlags: 0, mBytesPerPacket: 0,
            mFramesPerPacket: UInt32(framesPerPacket), mBytesPerFrame: 0, mChannelsPerFrame: 1,
            mBitsPerChannel: 0, mReserved: 0)
        guard let i = AVAudioFormat(streamDescription: &asbd),
              let o = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false),
              let c = AVAudioConverter(from: i, to: o) else { return nil }
        input = i
        output = o
        converter = c
    }

    func decode(_ packet: Data) -> [Float] {
        let compressed = AVAudioCompressedBuffer(format: input, packetCapacity: 1, maximumPacketSize: max(packet.count, 1))
        packet.withUnsafeBytes { raw in
            compressed.data.copyMemory(from: raw.baseAddress!, byteCount: packet.count)
        }
        compressed.byteLength = UInt32(packet.count)
        compressed.packetCount = 1
        compressed.packetDescriptions?[0] = AudioStreamPacketDescription(
            mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: UInt32(packet.count))

        guard let pcm = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: framesPerPacket * 2) else { return [] }
        var fed = false
        var error: NSError?
        converter.convert(to: pcm, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return compressed
        }
        guard error == nil, let ch = pcm.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: ch[0], count: Int(pcm.frameLength)))
    }
}
