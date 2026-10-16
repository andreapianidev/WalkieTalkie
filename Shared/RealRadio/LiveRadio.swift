//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - LiveRadio.swift
//  Talky
//
//  Il ricevitore dal vivo: HF dai KiwiSDR pubblici, POC dai canali pubblici
//  Mumble. Solo ascolto, solo servizi gratuiti senza chiavi. Sceglie il
//  ricevitore piu' adatto, passa al successivo se uno e' pieno o cade, e
//  per il POC propone solo canali dove c'e' davvero qualcuno.

import Foundation
import Combine

/// Un canale HF della lista di Talky: stazioni che trasmettono voce o
/// segnali tutto il giorno, piu' le frequenze di chiamata dei radioamatori.
nonisolated struct HFChannel: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case aviation, time, amateur, citizens, digital
    }

    let id: String
    let name: String
    let kind: Kind
    let tuning: Tuning
    /// Dove sta il trasmettitore: si ascolta da un ricevitore vicino, cosi'
    /// il segnale arriva davvero. Nil per le bande radioamatoriali, che si
    /// ascoltano vicino a chi usa l'app.
    let latitude: Double?
    let longitude: Double?

    static let all: [HFChannel] = [
        HFChannel(id: "shannon-volmet", name: "SHANNON VOLMET", kind: .aviation,
                  tuning: Tuning(hz: 5_505_000, emission: .usb, bandwidth: 2800), latitude: 52.70, longitude: -8.92),
        HFChannel(id: "raf-volmet", name: "RAF VOLMET", kind: .aviation,
                  tuning: Tuning(hz: 5_450_000, emission: .usb, bandwidth: 2800), latitude: 51.75, longitude: -1.58),
        HFChannel(id: "newyork-volmet", name: "NEW YORK VOLMET", kind: .aviation,
                  tuning: Tuning(hz: 6_604_000, emission: .usb, bandwidth: 2800), latitude: 40.78, longitude: -73.10),
        HFChannel(id: "shanwick", name: "SHANWICK OCEANIC", kind: .aviation,
                  tuning: Tuning(hz: 8_879_000, emission: .usb, bandwidth: 2800), latitude: 52.75, longitude: -8.93),
        HFChannel(id: "wwv-10", name: "WWV 10 MHz", kind: .time,
                  tuning: Tuning(hz: 10_000_000, emission: .am, bandwidth: 4000), latitude: 40.68, longitude: -105.04),
        HFChannel(id: "wwv-15", name: "WWV 15 MHz", kind: .time,
                  tuning: Tuning(hz: 15_000_000, emission: .am, bandwidth: 4000), latitude: 40.68, longitude: -105.04),
        HFChannel(id: "chu", name: "CHU CANADA", kind: .time,
                  tuning: Tuning(hz: 7_850_000, emission: .am, bandwidth: 4000), latitude: 45.30, longitude: -75.75),
        HFChannel(id: "ham-80", name: "80 m SSB", kind: .amateur,
                  tuning: Tuning(hz: 3_700_000, emission: .lsb, bandwidth: 2800), latitude: nil, longitude: nil),
        HFChannel(id: "ham-40", name: "40 m SSB", kind: .amateur,
                  tuning: Tuning(hz: 7_150_000, emission: .lsb, bandwidth: 2800), latitude: nil, longitude: nil),
        HFChannel(id: "ham-20", name: "20 m SSB", kind: .amateur,
                  tuning: Tuning(hz: 14_250_000, emission: .usb, bandwidth: 2800), latitude: nil, longitude: nil),
        HFChannel(id: "ft8-20", name: "FT8 20 m", kind: .digital,
                  tuning: Tuning(hz: 14_074_000, emission: .usb, bandwidth: 2800), latitude: nil, longitude: nil),
        HFChannel(id: "cb-27555", name: "CB 27.555", kind: .citizens,
                  tuning: Tuning(hz: 27_555_000, emission: .usb, bandwidth: 2800), latitude: nil, longitude: nil)
    ]
}

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class LiveRadio: ObservableObject {
    static let shared = LiveRadio()

    enum Band: String, Sendable {
        case hf, poc
    }

    @Published private(set) var band: Band?
    @Published private(set) var hfIndex = 0
    @Published private(set) var tuning: Tuning = HFChannel.all[0].tuning
    @Published private(set) var pocChannels: [MumbleLiveChannel] = []
    @Published private(set) var pocIndex = 0
    @Published private(set) var isScouting = false
    /// Scansione POC: salta da un canale all'altro e si ferma quando qualcuno parla.
    @Published private(set) var isScanning = false
    @Published private(set) var scanHolding = false
    @Published private(set) var state: LinkState = .idle
    /// Ricevitore HF o server POC a cui siamo collegati.
    @Published private(set) var sourceName = ""
    @Published private(set) var sourcePlace = ""
    /// Canale POC in cui siamo davvero entrati.
    @Published private(set) var channelName = ""
    @Published private(set) var talker: String?
    @Published private(set) var audience: Int?
    @Published private(set) var signalDBm: Double?
    @Published private(set) var level: Float = 0
    @Published var volume: Float = 0.9 {
        didSet { player.setVolume(volume) }
    }

    var hfChannels: [HFChannel] { HFChannel.all }
    var currentHF: HFChannel { HFChannel.all[hfIndex] }
    var currentPOC: MumbleLiveChannel? { pocChannels.indices.contains(pocIndex) ? pocChannels[pocIndex] : nil }
    var isOn: Bool { band != nil }

    private let player = LivePlayer()
    private var kiwi: KiwiListener?
    private var mumble: MumbleListener?
    private var pumps: [Task<Void, Never>] = []
    private var generation = 0
    private var wasOnline = false
    private var retried = false

    private var receivers: [KiwiReceiver] = []
    private var candidates: [KiwiReceiver] = []
    private var candidateIndex = 0
    private var benched: [String: Date] = [:]
    private var directoryTask: Task<Void, Never>?

    private var scoutTask: Task<Void, Never>?
    private var scoutedAt: Date?
    /// Server POC che non hanno risposto: non tornano in lista finche' non si aggiorna.
    private var badServers: Set<String> = []
    private let username = "Talky-\(Int.random(in: 1000 ... 9999))"

    private var scanTask: Task<Void, Never>?
    private var lastVoice = Date.distantPast
    private var scanSince = Date()

    private var lastLevelPush = Date.distantPast
    private var lastSignalPush = Date.distantPast

    private init() {
        player.setVolume(volume)
    }

    // MARK: comandi

    func start(_ band: Band) {
        guard self.band != band else { return }
        stopScan()
        disconnect()
        if band == .hf, scoutTask != nil {
            scoutTask?.cancel()
            scoutTask = nil
            isScouting = false
        }
        self.band = band
        player.start()
        switch band {
        case .hf:
            loadReceivers()
            connectHF(fresh: true)
        case .poc:
            sourceName = ""
            sourcePlace = ""
            if pocChannels.isEmpty || (scoutedAt.map { Date().timeIntervalSince($0) > 600 } ?? true) {
                scoutPOC()
            } else {
                connectPOC()
            }
        }
    }

    func stop() {
        stopScan()
        disconnect()
        scoutTask?.cancel()
        scoutTask = nil
        isScouting = false
        band = nil
        player.stop()
        state = .idle
    }

    /// Canale successivo o precedente nella banda accesa.
    func step(_ delta: Int) {
        switch band {
        case .hf:
            selectHF((hfIndex + delta + HFChannel.all.count) % HFChannel.all.count)
        case .poc:
            guard !pocChannels.isEmpty else { return }
            selectPOC((pocIndex + delta + pocChannels.count) % pocChannels.count)
        case nil:
            break
        }
    }

    func selectHF(_ index: Int) {
        guard HFChannel.all.indices.contains(index) else { return }
        let old = HFChannel.all[hfIndex]
        hfIndex = index
        tuning = HFChannel.all[index].tuning
        guard band == .hf else { return }
        // Stesso ricevitore se il nuovo canale si ascolta dalla stessa zona.
        let sameArea = old.latitude == currentHF.latitude && old.longitude == currentHF.longitude
        if sameArea, let kiwi, state == .online {
            player.flush()
            signalDBm = nil
            Task { await kiwi.tune(tuning) }
        } else {
            connectHF(fresh: true)
        }
    }

    /// Sintonia fine in HF, a passi di kHz.
    func nudge(kHz: Int) {
        guard band == .hf else { return }
        let hz = min(Tuning.hfRange.upperBound, max(Tuning.hfRange.lowerBound, tuning.hz + kHz * 1000))
        tuning.hz = hz
        if let kiwi { Task { await kiwi.tune(tuning) } }
    }

    func selectPOC(_ index: Int) {
        guard pocChannels.indices.contains(index) else { return }
        pocIndex = index
        guard band == .poc else { return }
        connectPOC()
    }

    /// Rilegge i server pubblici per trovare canali con persone dentro adesso.
    func rescanPOC() {
        guard band == .poc else { return }
        disconnect()
        pocChannels = []
        pocIndex = 0
        badServers = []
        scoutPOC()
    }

    // MARK: scansione POC

    /// Come lo scan dei preferiti di Etere: circa 7 secondi su un canale muto,
    /// fermo finche' qualcuno parla, avanti 4 secondi dopo che ha finito.
    func toggleScan() {
        isScanning ? stopScan() : startScan()
    }

    func startScan() {
        guard band == .poc, !isScanning else { return }
        isScanning = true
        scanHolding = false
        scanSince = Date()
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, self.isScanning, self.band == .poc else { return }
                self.scanTick()
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanHolding = false
    }

    private func scanTick() {
        guard pocChannels.count > 1 else { return }
        let now = Date()
        if now.timeIntervalSince(lastVoice) < 0.8 {
            scanHolding = true
            return
        }
        if scanHolding {
            guard now.timeIntervalSince(lastVoice) > 4 else { return }
            scanHolding = false
            scanSince = now
            step(1)
            return
        }
        let waited = now.timeIntervalSince(scanSince)
        if waited > (state == .online ? 7 : 8) {
            scanSince = now
            step(1)
        }
    }

    // MARK: HF

    private func loadReceivers() {
        if receivers.isEmpty { receivers = KiwiDirectory.cached() }
        guard directoryTask == nil else { return }
        directoryTask = Task { [weak self] in
            let fresh = (try? await KiwiDirectory.fetch()) ?? []
            guard let self else { return }
            self.directoryTask = nil
            guard !fresh.isEmpty else {
                if self.receivers.isEmpty, self.band == .hf { self.state = .refused(.down) }
                return
            }
            let hadNone = self.receivers.isEmpty
            self.receivers = fresh
            if hadNone, self.band == .hf { self.connectHF(fresh: true) }
        }
    }

    private func connectHF(fresh: Bool) {
        disconnect()
        guard band == .hf else { return }
        if fresh {
            candidates = rankReceivers(for: currentHF)
            candidateIndex = 0
        }
        tuning = fresh ? currentHF.tuning : tuning
        guard !receivers.isEmpty else {
            state = .connecting
            return
        }
        guard candidates.indices.contains(candidateIndex) else {
            state = .refused(.full)
            return
        }
        let receiver = candidates[candidateIndex]
        sourceName = receiver.name
        sourcePlace = receiver.location
        wasOnline = false
        retried = fresh ? false : retried
        let listener = KiwiListener(receiver: receiver, tuning: tuning)
        kiwi = listener
        attach(audio: listener.audio, events: listener.events)
        Task { await listener.connect() }
    }

    /// I ricevitori con posti liberi, dal piu' vicino alla stazione (o a chi
    /// ascolta, per le bande radioamatoriali).
    private func rankReceivers(for channel: HFChannel) -> [KiwiReceiver] {
        let here = ApproximatePlace.current
        let lat = channel.latitude ?? here.latitude
        let lon = channel.longitude ?? here.longitude
        let now = Date()
        return receivers
            .filter { $0.freeSlots > 0 && (benched[$0.id].map { $0 < now } ?? true) }
            .sorted { $0.distance(toLatitude: lat, longitude: lon) < $1.distance(toLatitude: lat, longitude: lon) }
            .prefix(10)
            .map { $0 }
    }

    private func hfFailed(_ problem: LiveProblem, refused: Bool) {
        // Caduto dopo aver funzionato: un secondo tentativo sullo stesso.
        if !refused, wasOnline, !retried {
            retried = true
            let gen = generation
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard let self, self.generation == gen else { return }
                self.connectHF(fresh: false)
            }
            return
        }
        if candidates.indices.contains(candidateIndex) {
            benched[candidates[candidateIndex].id] = Date().addingTimeInterval(refused ? 600 : 150)
        }
        candidateIndex += 1
        retried = false
        if candidates.indices.contains(candidateIndex) {
            connectHF(fresh: false)
        } else {
            disconnect()
            state = .refused(problem)
        }
    }

    // MARK: POC

    private func scoutPOC() {
        scoutTask?.cancel()
        isScouting = true
        state = .connecting
        let name = username
        scoutTask = Task { [weak self] in
            var servers = MumbleDirectory.cached()
            if let fresh = try? await MumbleDirectory.fetch() { servers = fresh }
            let ordered = Self.order(servers)
            var found: [MumbleLiveChannel] = []
            var offset = 0
            let batch = 6, maxServers = 48, enough = 16
            while offset < min(ordered.count, maxServers), found.count < enough, !Task.isCancelled {
                let slice = Array(ordered[offset ..< min(offset + batch, ordered.count)])
                offset += batch
                let live = await withTaskGroup(of: [MumbleLiveChannel].self) { group in
                    for server in slice {
                        group.addTask { (try? await MumbleScout.liveChannels(on: server, username: name + "s")) ?? [] }
                    }
                    var all: [MumbleLiveChannel] = []
                    for await list in group { all += list.prefix(2) }
                    return all
                }
                guard !Task.isCancelled, let self else { return }
                found += live
                self.publishScouted(found)
            }
            guard !Task.isCancelled, let self else { return }
            self.isScouting = false
            self.scoutedAt = Date()
            if found.isEmpty, self.band == .poc { self.state = .refused(.down) }
        }
    }

    private func publishScouted(_ found: [MumbleLiveChannel]) {
        let current = currentPOC
        pocChannels = found.filter { !badServers.contains($0.server.id) }.sorted { $0.users > $1.users }
        if let current, let i = pocChannels.firstIndex(of: current) {
            pocIndex = i
        } else if current == nil, !pocChannels.isEmpty, band == .poc {
            pocIndex = 0
            connectPOC()
        }
    }

    /// Prima i server che parlano di radio, poi quelli del paese di chi
    /// ascolta, poi gli altri in ordine sparso.
    nonisolated private static func order(_ servers: [MumbleServer]) -> [MumbleServer] {
        let radio = /(?i)radio|link|ham|ptt|walkie|qso|repeater|funk|cb|dmr|allstar|echolink/
        let country = Locale.current.region?.identifier ?? ""
        func score(_ s: MumbleServer) -> Int {
            (s.name.contains(radio) ? 2 : 0) + (s.countryCode == country ? 1 : 0)
        }
        return servers.shuffled().sorted { score($0) > score($1) }
    }

    private func connectPOC() {
        disconnect()
        guard band == .poc, let target = currentPOC else { return }
        sourceName = target.server.name
        sourcePlace = target.server.country
        channelName = target.channel
        audience = target.users
        wasOnline = false
        let listener = MumbleListener(target: target, username: username)
        mumble = listener
        attach(audio: listener.audio, events: listener.events)
        Task { await listener.connect() }
    }

    private func pocFailed(refused: Bool) {
        if !refused, wasOnline, !retried {
            retried = true
            let gen = generation
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard let self, self.generation == gen else { return }
                self.connectPOC()
            }
            return
        }
        retried = false
        // Canale non raggiungibile: si toglie dalla lista e si passa al prossimo.
        guard let bad = currentPOC else { return }
        badServers.insert(bad.server.id)
        pocChannels.removeAll { $0.server == bad.server }
        pocIndex = min(pocIndex, max(0, pocChannels.count - 1))
        if pocChannels.isEmpty {
            disconnect()
            state = isScouting ? .connecting : .refused(.down)
        } else {
            connectPOC()
        }
    }

    // MARK: flussi

    private func attach(audio: AsyncStream<PCMChunk>, events: AsyncStream<LiveEvent>) {
        generation += 1
        let gen = generation
        let player = player
        state = .connecting
        talker = nil
        level = 0
        signalDBm = nil
        pumps.append(Task.detached(priority: .userInitiated) {
            for await chunk in audio { player.play(chunk) }
        })
        pumps.append(Task { [weak self] in
            for await event in events {
                guard let self, self.generation == gen else { return }
                self.handle(event)
            }
        })
    }

    private func handle(_ event: LiveEvent) {
        switch event {
        case .link(let s):
            switch s {
            case .online:
                wasOnline = true
                state = .online
            case .refused(let p):
                band == .hf ? hfFailed(p, refused: true) : pocFailed(refused: true)
            case .dropped(let p):
                band == .hf ? hfFailed(p, refused: false) : pocFailed(refused: false)
            case .idle, .connecting:
                break
            }
        case .talker(let name):
            talker = name
            if name != nil { lastVoice = Date() }
        case .audience(let n):
            audience = n
        case .channel(let name):
            channelName = name
        case .signal(let dBm):
            let now = Date()
            guard now.timeIntervalSince(lastSignalPush) > 0.25 else { return }
            lastSignalPush = now
            signalDBm = dBm
        case .level(let v):
            let now = Date()
            if v > 0.02 { lastVoice = now }
            guard now.timeIntervalSince(lastLevelPush) > 0.1 || (v == 0 && level != 0) else { return }
            lastLevelPush = now
            level = v
        }
    }

    private func disconnect() {
        generation += 1
        pumps.forEach { $0.cancel() }
        pumps = []
        if let kiwi { Task { await kiwi.disconnect() } }
        if let mumble { Task { await mumble.disconnect() } }
        kiwi = nil
        mumble = nil
        player.flush()
        talker = nil
        level = 0
        signalDBm = nil
    }
}

/// Dove si trova, piu' o meno, chi ascolta: dal fuso orario e dal paese,
/// senza chiedere la posizione. Serve solo a scegliere un ricevitore vicino.
@available(iOS 16.0, macOS 13.0, *)
nonisolated enum ApproximatePlace {
    static var current: (latitude: Double, longitude: Double) {
        let tz = TimeZone.current
        let offset = Double(tz.secondsFromGMT() - Int(tz.daylightSavingTimeOffset())) / 3600
        let region = Locale.current.region?.identifier ?? ""
        let south: Set<String> = ["AU", "NZ", "BR", "AR", "CL", "ZA", "UY", "PY", "BO", "PE"]
        let tropics: Set<String> = ["IN", "ID", "TH", "VN", "PH", "MY", "SG", "NG", "KE", "MX", "CO", "VE", "EC", "GH", "SA", "AE"]
        let latitude = south.contains(region) ? -30.0 : tropics.contains(region) ? 15.0 : 45.0
        return (latitude, offset * 15)
    }
}
