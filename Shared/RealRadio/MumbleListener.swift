//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - MumbleListener.swift
//  Talky
//
//  POC vero: canali pubblici Mumble. Accesso anonimo con un nome Talky,
//  noi stessi in muto finche' non si parla, e solo sul server scelto da chi
//  usa Talky: la lista si fa con il ping UDP, senza entrare (issue #12).
//  Portato da RadioKit di Etere.

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

/// Un server pubblico con qualcuno collegato, come lo dice il suo ping.
/// `channel` e' vuoto finche' non si entra: il canale si sa solo dopo che
/// chi usa Talky ha scelto il server, e allora si va in quello con piu' persone.
nonisolated struct MumbleLiveChannel: Sendable, Equatable, Hashable, Identifiable {
    var server: MumbleServer
    var channel: String
    var users: Int

    var id: String { "\(server.id)/\(channel)" }
}

/// Mumble sul canale di controllo TLS, voce nei messaggi UDPTunnel.
/// Come su un canale PTT, parla uno alla volta: la voce di altri viene
/// scartata finche' il passaggio in corso non finisce. Si parla solo dove
/// il server da' il permesso Speak a chi entra senza registrarsi, e
/// mentre parliamo noi la voce degli altri non si suona.
@available(iOS 16.0, macOS 13.0, *)
actor MumbleListener {
    nonisolated let audio: AsyncStream<PCMChunk>
    nonisolated let events: AsyncStream<LiveEvent>
    nonisolated let target: MumbleLiveChannel
    /// Stanza privata: si entra con il suo token e solo nel suo canale.
    nonisolated let room: TalkyRoom?

    static let rate = 48_000.0
    /// Quanto si resta senza muto dopo un passaggio. Il server conta i
    /// cambi di stato nel suo limite di messaggi (1 al secondo, 5 di scorta
    /// sui server pubblici): chi parla a botta e risposta, togliendo e
    /// rimettendo il muto a ogni passaggio, lo supera e il muto tolto si perde.
    static let unmuteHold: Duration = .seconds(8)
    /// Tempo per avere la stanza dal custode ed entrarci.
    static let roomPatience: Duration = .seconds(15)

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
    private var plainNamed = false
    private var channels: [UInt32: MumbleChannel] = [:]
    private var users: [UInt32: MumbleUser] = [:]
    private var lastHeard = ContinuousClock.now
    private var lastPing = ContinuousClock.now
    /// Banda massima del server (ServerSync), in bit al secondo.
    private var maxBandwidth: Int?

    private var floor: UInt32?
    private var floorHeard = ContinuousClock.now
    private var decoders: [Int: OpusDecoder] = [:]

    /// Permessi per canale, dalle risposte PermissionQuery.
    private var permissions: [UInt32: UInt32] = [:]
    /// Muto o soppresso da un amministratore: non si parla.
    private var silencedByServer = false
    private var mayTalk = false
    /// Il passaggio in corso, con il numero dato da beginTalking: send e
    /// endTalking di un passaggio gia' chiuso non toccano quello nuovo.
    private var over: Int?
    private var overs = 0
    private var unmuted = false
    private var lastOverEnd: ContinuousClock.Instant?
    /// In unita' da 10 ms, come il contatore dei client Mumble.
    private var sequence: UInt64 = 0

    /// Da quando si sta cercando di entrare nella stanza.
    private var roomSince: ContinuousClock.Instant?
    private var keeperAsked = false
    /// Il canale che il custode ha dato alla stanza.
    private var roomChannel: String?
    private var inRoom = false

    init(target: MumbleLiveChannel, username: String, room: TalkyRoom? = nil) {
        self.target = room?.target ?? target
        self.room = room
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
        link.send(MumbleControl.authenticate(user: username, tokens: room.map { [$0.token] } ?? []))
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
        maxBandwidth = nil
        floor = nil
        decoders = [:]
        permissions = [:]
        silencedByServer = false
        over = nil
        unmuted = false
        lastOverEnd = nil
        roomSince = nil
        keeperAsked = false
        setInRoom(false)
        reportMayTalk()
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
                return
            }
            if unmuted, over == nil, let end = lastOverEnd, now - end > Self.unmuteHold, let session {
                link.send(MumbleControl.selfMute(session: session, on: true))
                unmuted = false
            }
        }
        if floor != nil, now - floorHeard > .milliseconds(500) { endOfOver() }
        if let since = roomSince, now - since > Self.roomPatience {
            hangUp()
            eventSink.yield(.link(.refused(.down)))
        }
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
            if let bw = f.uint32(2), bw > 0 { maxBandwidth = Int(bw) }
            if let root = f.uint32(4) { permissions[0] = root }
            if let session { link?.send(MumbleControl.selfMute(session: session, on: true)) }
            eventSink.yield(.link(.online))
            enterChannel()
        case .permissionQuery:
            if f.bool(3) == true { permissions = [:] }
            if let c = f.uint32(1), let p = f.uint32(2) { permissions[c] = p }
            reportMayTalk()
        case .permissionDenied:
            denied(f)
        case .textMessage:
            keeperSaid(f)
        case .channelState:
            guard let id = f.uint32(1) else { return }
            var c = channels[id] ?? MumbleChannel(id: id, parent: nil, name: "")
            if let p = f.uint32(2) { c.parent = p }
            if let n = f.string(3) { c.name = n }
            channels[id] = c
            if room != nil, synced, let wanted = roomChannel, c.name == wanted { enterChannel() }
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
        if type == 2, !plainNamed {
            // Nome rifiutato: molti server pubblici accettano solo lettere
            // latine, e un nome in thai o in hindi non passa.
            plainNamed = true
            username = MumbleManners.plainName(for: username)
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
        if s == session {
            if f.has(6) || f.has(8) { silencedByServer = (f.bool(6) ?? false) || (f.bool(8) ?? false) }
            if f.has(5) {
                reportChannel()
                link?.send(MumbleControl.permissionQuery(channel: u.channel))
                updateInRoom()
            }
            reportMayTalk()
        }
        reportAudience()
    }

    /// Entra nel canale scelto; se non c'e' piu', in quello con piu' persone.
    /// Per una stanza privata invece si chiede al custode quale canale e'.
    private func enterChannel() {
        guard synced, let link, let session else { return }
        if let room {
            enterRoom(room, link: link, session: session)
            return
        }
        let wanted = target.channel.lowercased()
        let target = channels.values.first { $0.name.lowercased() == wanted } ?? busiest()
        if let target, users[session]?.channel != target.id {
            link.send(MumbleControl.join(session: session, channel: target.id))
        } else if let here = users[session]?.channel {
            link.send(MumbleControl.permissionQuery(channel: here))
        }
        reportChannel()
        reportAudience()
    }

    private func enterRoom(_ room: TalkyRoom, link: StreamLink, session: UInt32) {
        if roomSince == nil, !inRoom { roomSince = .now }
        if let name = roomChannel, let here = roomChannelID(name) {
            if users[session]?.channel != here {
                link.send(MumbleControl.join(session: session, channel: here))
            }
            updateInRoom()
            reportChannel()
            reportAudience()
            return
        }
        // Nome ancora da sapere, o stanza tolta dallo sweep: lo dice il custode.
        guard !keeperAsked else { return }
        guard let keeper = keeperSession() else {
            hangUp()
            eventSink.yield(.link(.refused(.down)))
            return
        }
        keeperAsked = true
        link.send(MumbleControl.text(to: keeper, "room \(room.token)"))
    }

    /// Le risposte del custode alla domanda "room".
    private func keeperSaid(_ f: ProtoFields) {
        guard room != nil, let actor = f.uint32(1), actor == keeperSession(), let text = f.string(5) else { return }
        let words = text.split(separator: " ").map(String.init)
        switch words.first {
        case "ok" where words.count == 2 && TalkyRoom.isChannelName(words[1]):
            roomChannel = words[1]
            keeperAsked = false
            enterChannel()
        case "slow", "no":
            hangUp()
            eventSink.yield(.link(.refused(.refused)))
        default:
            break
        }
    }

    /// Un no del server. Sui canali pubblici si resta dove si e', come
    /// prima; nella stanza invece restare nella radice vorrebbe dire sembrare
    /// in linea senza sentire niente.
    private func denied(_ f: ProtoFields) {
        guard room != nil else { return }
        let type = f.int(5)
        let full = type == 9                                     // DenyType.ChannelFull
        let inRoomChannel = f.uint32(2).map { $0 == roomChannel.flatMap(roomChannelID) } ?? false
        let keeperUnreachable = f.uint32(1) == 0x200             // TextMessage verso il custode
        guard full || inRoomChannel || keeperUnreachable else { return }
        hangUp()
        eventSink.yield(.link(.refused(full ? .full : .refused)))
    }

    private func roomChannelID(_ name: String) -> UInt32? {
        channels.values.first { $0.name == name && ($0.parent ?? 0) == 0 }?.id
    }

    private func keeperSession() -> UInt32? {
        users.values.first { $0.name == "SuperUser" }?.session
    }

    private func updateInRoom() {
        guard room != nil, let session, let name = roomChannel, let id = roomChannelID(name) else {
            setInRoom(false)
            return
        }
        setInRoom(users[session]?.channel == id)
    }

    private func setInRoom(_ now: Bool) {
        if now { roomSince = nil }
        guard now != inRoom else { return }
        inRoom = now
        eventSink.yield(.inRoom(now))
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
        guard over == nil, let v = MumbleVoicePacket.parse(packet, protobuf: usesProtobuf) else { return }
        if let floor, floor != v.session { return }
        if let name = users[v.session]?.name, MumbleManners.isBlocked(name, on: target.server.id) { return }
        if floor == nil {
            // Un terminatore da solo non apre un passaggio.
            guard !v.opus.isEmpty else { return }
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

    // MARK: parlare

    /// Il permesso Speak vale nel canale dove siamo; se il server non ha
    /// ancora risposto per quel canale vale quello della radice.
    private func reportMayTalk() {
        var ok = false
        if synced, let session, let here = users[session]?.channel, !silencedByServer {
            let p = permissions[here] ?? permissions[0] ?? 0
            ok = p & MumbleControl.speakPermission != 0
        }
        guard ok != mayTalk else { return }
        mayTalk = ok
        eventSink.yield(.mayTalk(ok))
    }

    /// Bitrate Opus che sta nella banda del server. Il server conta 32 byte
    /// in piu' per pacchetto (20 + 8 + 4, Server.cpp), 50 pacchetti al secondo.
    func voiceBitRate() -> Int {
        guard let bw = maxBandwidth else { return 32_000 }
        return max(8_000, min(32_000, Int(Double(bw) * 0.85) - 12_800))
    }

    /// Inizio di un passaggio: il numero del passaggio, nil se qui non si puo'.
    func beginTalking() -> Int? {
        guard mayTalk, let link, let session else { return nil }
        if floor != nil { endOfOver() }
        overs += 1
        over = overs
        if !unmuted {
            link.send(MumbleControl.selfMute(session: session, on: false))
            unmuted = true
        }
        return overs
    }

    /// Un pacchetto Opus da 20 ms del passaggio `id`.
    func send(_ opus: Data, over id: Int) {
        guard over == id, let link else { return }
        sequence += 2
        link.send(MumbleOutgoingVoice.tunnel(
            MumbleOutgoingVoice.packet(opus: opus, sequence: sequence, last: false, protobuf: usesProtobuf)))
    }

    /// Fine del passaggio `id`: pacchetto di chiusura. Il muto torna dopo
    /// `unmuteHold` senza passaggi (watch).
    func endTalking(over id: Int) {
        guard over == id else { return }
        over = nil
        lastOverEnd = .now
        guard let link else { return }
        sequence += 2
        link.send(MumbleOutgoingVoice.tunnel(
            MumbleOutgoingVoice.packet(opus: Data(), sequence: sequence, last: true, protobuf: usesProtobuf)))
    }

    /// Al custode: comincia un passaggio, avvisa con Push to Talk chi della
    /// stanza non e' collegato.
    func keeperTalk() {
        guard let room else { return }
        tellKeeper("talk \(room.token) \(username)")
    }

    /// Al custode: il gettone Push to Talk di questo telefono per la stanza.
    /// Falso se non si e' ancora dentro, e allora va rimandato dopo.
    func keeperPushToTalk(token: String, environment: String) -> Bool {
        guard let room, inRoom else { return false }
        return tellKeeper("ptt \(room.token) \(token) \(environment) \(username)")
    }

    @discardableResult
    private func tellKeeper(_ text: String) -> Bool {
        guard room != nil, synced, let link, let keeper = keeperSession() else { return false }
        link.send(MumbleControl.text(to: keeper, text))
        return true
    }

    /// Chi parla adesso non si sente piu', qui e nei collegamenti futuri.
    func blockTalker() -> String? {
        guard let floor, let name = users[floor]?.name else { return nil }
        MumbleManners.block(name, on: target.server.id)
        endOfOver()
        return name
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
