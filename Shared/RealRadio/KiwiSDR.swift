//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - KiwiSDR.swift
//  Talky
//
//  Onde corte vere: ascolto attraverso i KiwiSDR pubblici di kiwisdr.com.
//  Un solo WebSocket per l'audio (SND), come kiwirecorder. Portato da
//  RadioKit di Etere, senza la cascata (waterfall) che Talky non mostra.

import Foundation

/// Un KiwiSDR pubblico dell'elenco di kiwisdr.com.
nonisolated struct KiwiReceiver: Codable, Sendable, Hashable, Identifiable {
    var id: String
    var name: String
    var host: String
    var port: Int
    var latitude: Double
    var longitude: Double
    var location: String
    var users: Int
    var slots: Int
    var snr: Int?

    var freeSlots: Int { max(0, slots - users) }

    /// Distanza ortodromica in km.
    func distance(toLatitude lat: Double, longitude lon: Double) -> Double {
        let r = 6371.0
        let p1 = latitude * .pi / 180, p2 = lat * .pi / 180
        let dp = (lat - latitude) * .pi / 180, dl = (lon - longitude) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * atan2(a.squareRoot(), (1 - a).squareRoot())
    }
}

/// L'elenco pubblico dei ricevitori, ripubblicato ogni pochi minuti da
/// rx.linkfanel.net a partire da kiwisdr.com/public. Copia su disco per
/// partire anche quando il sito non risponde.
@available(iOS 16.0, macOS 13.0, *)
nonisolated enum KiwiDirectory {
    /// Solo http: il server non ha https. Eccezione ATS in Info.plist.
    static let source = URL(string: "http://rx.linkfanel.net/kiwisdr_com.js")!

    static func fetch() async throws -> [KiwiReceiver] {
        var req = URLRequest(url: source, timeoutInterval: 20)
        req.setValue("Talky", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        let list = parse(String(decoding: data, as: UTF8.self))
        if !list.isEmpty { save(list) }
        return list
    }

    static func cached() -> [KiwiReceiver] {
        guard let data = try? Data(contentsOf: cacheFile) else { return [] }
        return (try? JSONDecoder().decode([KiwiReceiver].self, from: data)) ?? []
    }

    /// Il file e' un'assegnazione JavaScript di un array quasi JSON, con virgole finali.
    static func parse(_ js: String) -> [KiwiReceiver] {
        guard let a = js.firstIndex(of: "["), let b = js.lastIndex(of: "]"), a < b else { return [] }
        var body = String(js[a ... b])
        body = body.replacingOccurrences(of: #",\s*\]"#, with: "]", options: .regularExpression)
        body = body.replacingOccurrences(of: #",\s*\}"#, with: "}", options: .regularExpression)
        guard let rows = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [[String: Any]] else { return [] }
        return rows.compactMap(receiver)
    }

    static func receiver(_ row: [String: Any]) -> KiwiReceiver? {
        func s(_ k: String) -> String { (row[k] as? String) ?? "" }
        guard s("offline") == "no", s("status") == "active",
              let url = URL(string: s("url")), let host = url.host, !host.isEmpty else { return nil }
        // Solo HF senza convertitore: la frequenza a schermo e' quella vera.
        let offset = Double(s("freq_offset")) ?? 0
        guard abs(offset) < 0.001 else { return nil }
        let bands = s("bands").split(separator: "-").compactMap { Double($0) }
        guard bands.count == 2, bands[0] <= 100_000, bands[1] >= 29_000_000 else { return nil }

        let gps = s("gps").trimmingCharacters(in: CharacterSet(charactersIn: "() "))
            .split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard gps.count == 2, !(gps[0] == 0 && gps[1] == 0) else { return nil }

        return KiwiReceiver(
            id: s("id").isEmpty ? host : s("id"),
            name: s("name").trimmingCharacters(in: .whitespaces),
            host: host,
            port: url.port ?? 8073,
            latitude: gps[0],
            longitude: gps[1],
            location: s("loc").trimmingCharacters(in: .whitespaces),
            users: Int(s("users")) ?? 0,
            slots: Int(s("users_max")) ?? 0,
            snr: s("snr").split(separator: ",").first.flatMap { Int($0) }
        )
    }

    private static var cacheFile: URL {
        let dir = URL.cachesDirectory.appending(path: "Talky", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "kiwisdr.json")
    }

    private static func save(_ list: [KiwiReceiver]) {
        if let data = try? JSONEncoder().encode(list) { try? data.write(to: cacheFile, options: .atomic) }
    }
}

/// Ascolto da un KiwiSDR: un WebSocket audio, sintonia, keepalive.
@available(iOS 16.0, macOS 13.0, *)
actor KiwiListener {
    nonisolated let audio: AsyncStream<PCMChunk>
    nonisolated let events: AsyncStream<LiveEvent>
    nonisolated let receiver: KiwiReceiver

    private let audioSink: AsyncStream<PCMChunk>.Continuation
    private let eventSink: AsyncStream<LiveEvent>.Continuation

    private var snd: WebSocketLink?
    private var tasks: [Task<Void, Never>] = []
    private var tuning: Tuning
    private var adpcm = ImaAdpcm()
    private var sampleRate = 12_000.0
    private var ready = false
    private var failed = false
    private var pendingTune: Task<Void, Never>?

    init(receiver: KiwiReceiver, tuning: Tuning) {
        self.receiver = receiver
        self.tuning = tuning
        (audio, audioSink) = AsyncStream.makeStream(of: PCMChunk.self, bufferingPolicy: .bufferingNewest(32))
        (events, eventSink) = AsyncStream.makeStream(of: LiveEvent.self, bufferingPolicy: .bufferingNewest(128))
    }

    func connect() async {
        eventSink.yield(.link(.connecting))
        let stamp = UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970))
        var url = URLComponents()
        url.scheme = "ws"
        url.host = receiver.host
        url.port = receiver.port
        url.path = "/\(stamp)/SND"
        guard let sndURL = url.url else {
            refuse(.refused)
            return
        }
        let snd = WebSocketLink(url: sndURL)
        self.snd = snd
        do {
            try await snd.open()
        } catch {
            snd.close()
            lost(.timeout)
            return
        }
        snd.send("SET auth t=kiwi p=")
        tasks.append(Task { [weak self] in await self?.pump(snd) })
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                await self.keepAlive()
            }
        })
    }

    func disconnect() {
        tasks.forEach { $0.cancel() }
        tasks = []
        pendingTune?.cancel()
        pendingTune = nil
        snd?.close()
        snd = nil
        audioSink.finish()
        eventSink.yield(.link(.idle))
        eventSink.finish()
    }

    func tune(_ t: Tuning) {
        tuning = t
        // Raggruppa i giri veloci della manopola in ~25 comandi al secondo.
        guard pendingTune == nil else { return }
        pendingTune = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(40))
            await self?.flushTune()
        }
    }

    // MARK: flusso

    private func pump(_ link: WebSocketLink) async {
        do {
            for try await message in link.messages {
                guard case .data(let data) = message, let frame = KiwiFrame.parse(data) else { continue }
                handle(frame)
            }
            lost(.closed)
        } catch {
            lost(.closed)
        }
    }

    private func lost(_ why: LiveProblem) {
        guard !failed else { return }
        failed = true
        eventSink.yield(.link(.dropped(why)))
    }

    private func refuse(_ why: LiveProblem) {
        guard !failed else { return }
        failed = true
        eventSink.yield(.link(.refused(why)))
    }

    private func handle(_ frame: KiwiFrame) {
        switch frame {
        case .message(let p):
            handle(p)
        case let .sound(flags, rssi, payload):
            eventSink.yield(.signal(dBm: rssi))
            let pcm: [Float]
            if flags & KiwiFrame.compressed != 0 {
                pcm = adpcm.decode(payload).map { Float($0) / 32768 }
            } else {
                pcm = stride(from: 0, to: payload.count - 1, by: 2).map {
                    let hi = UInt16(payload[payload.startIndex + $0]) << 8
                    let s = Int16(bitPattern: hi | UInt16(payload[payload.startIndex + $0 + 1]))
                    return Float(s) / 32768
                }
            }
            guard !pcm.isEmpty else { return }
            let chunk = PCMChunk(samples: pcm, sampleRate: sampleRate)
            audioSink.yield(chunk)
            eventSink.yield(.level(chunk.envelope))
        case .other:
            break
        }
    }

    private func handle(_ p: [String: String?]) {
        if p["too_busy"] != nil {
            refuse(.full)
            return
        }
        if let code = p["badp"] ?? nil, code != "0" {
            refuse(code == "1" ? .full : .refused)
            return
        }
        if p["down"] != nil {
            refuse(.down)
            return
        }
        if p["redirect"] != nil {
            refuse(.refused)
            return
        }
        if let v = p["audio_rate"] ?? nil, let rate = Double(v) {
            snd?.send("SET AR OK in=\(Int(rate)) out=44100")
        }
        if let v = p["sample_rate"] ?? nil, let rate = Double(v) {
            sampleRate = rate
            adpcm.reset()
            snd?.send("SET squelch=0 max=0")
            snd?.send("SET genattn=0")
            snd?.send("SET gen=0 mix=-1")
            snd?.send("SET ident_user=Talky")
            ready = true
            sendTune()
            // AGC lento: la voce resta stabile fra un passaggio e l'altro.
            snd?.send("SET agc=1 hang=0 thresh=-100 slope=6 decay=1000 manGain=50")
            snd?.send("SET compression=1")
            snd?.send("SET keepalive")
            eventSink.yield(.link(.online))
        }
    }

    private func keepAlive() {
        snd?.send("SET keepalive")
    }

    private func flushTune() {
        pendingTune = nil
        sendTune()
    }

    private func sendTune() {
        guard ready else { return }
        let pb = KiwiFrame.passband(tuning)
        let khz = String(format: "%.3f", Double(tuning.hz) / 1000)
        snd?.send("SET mod=\(KiwiFrame.modName(tuning.emission)) low_cut=\(pb.low) high_cut=\(pb.high) freq=\(khz)")
    }
}

/// IMA ADPCM come lo usa l'audio dei KiwiSDR (prima il nibble basso). Lo
/// stato passa da un pacchetto all'altro.
nonisolated struct ImaAdpcm: Sendable {
    private static let steps: [Int32] = [
        7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34,
        37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143,
        157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494,
        544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552,
        1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026,
        4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442,
        11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623,
        27086, 29794, 32767
    ]
    private static let indexShift: [Int] = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]

    private var index = 0
    private var previous: Int32 = 0

    mutating func reset() {
        index = 0
        previous = 0
    }

    mutating func decode(_ bytes: some Collection<UInt8>) -> [Int16] {
        var out = [Int16]()
        out.reserveCapacity(bytes.count * 2)
        for b in bytes {
            out.append(sample(b & 0x0F))
            out.append(sample(b >> 4))
        }
        return out
    }

    private mutating func sample(_ code: UInt8) -> Int16 {
        let step = Self.steps[index]
        index = min(Self.steps.count - 1, max(0, index + Self.indexShift[Int(code)]))
        var diff = step >> 3
        if code & 1 != 0 { diff += step >> 2 }
        if code & 2 != 0 { diff += step >> 1 }
        if code & 4 != 0 { diff += step }
        if code & 8 != 0 { diff = -diff }
        previous = min(32767, max(-32768, previous + diff))
        return Int16(previous)
    }
}

/// I frame binari di un Kiwi: un'etichetta di 3 byte, poi il corpo.
nonisolated enum KiwiFrame {
    case message([String: String?])
    case sound(flags: UInt8, rssi: Double, payload: Data)
    case other

    static let compressed: UInt8 = 0x10

    static func parse(_ data: Data) -> KiwiFrame? {
        guard data.count >= 3 else { return nil }
        let bytes = [UInt8](data)
        let tag = String(decoding: bytes[0 ..< 3], as: UTF8.self)
        switch tag {
        case "MSG":
            let text = String(decoding: bytes.dropFirst(4), as: UTF8.self)
            return .message(params(text))
        case "SND":
            guard bytes.count >= 10 else { return nil }
            let meter = UInt16(bytes[8]) << 8 | UInt16(bytes[9])
            return .sound(flags: bytes[3], rssi: 0.1 * Double(meter) - 127, payload: Data(bytes[10...]))
        default:
            return .other
        }
    }

    /// `nome=valore nome nome=valore`, valori con percent-encoding.
    static func params(_ text: String) -> [String: String?] {
        var out = [String: String?]()
        for pair in text.split(separator: " ") {
            if let eq = pair.firstIndex(of: "=") {
                let v = String(pair[pair.index(after: eq)...])
                out[String(pair[..<eq])] = v.removingPercentEncoding ?? v
            } else {
                out[String(pair)] = .some(nil)
            }
        }
        return out
    }

    /// Banda passante Kiwi per una sintonia, `low_cut high_cut` in Hz.
    static func passband(_ t: Tuning) -> (low: Int, high: Int) {
        switch t.emission {
        case .lsb: (-(t.bandwidth + 300), -300)
        case .usb: (300, t.bandwidth + 300)
        case .cw: (500 - t.bandwidth / 2, 500 + t.bandwidth / 2)
        case .am: (-t.bandwidth * 2, t.bandwidth * 2)
        }
    }

    static func modName(_ e: Emission) -> String {
        switch e {
        case .lsb: "lsb"
        case .usb: "usb"
        case .cw: "cw"
        case .am: "am"
        }
    }
}
