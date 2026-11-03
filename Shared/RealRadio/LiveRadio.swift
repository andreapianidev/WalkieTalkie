//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - LiveRadio.swift
//  Talky
//
//  Il ricevitore dal vivo: HF e CB dai KiwiSDR pubblici, POC dai canali
//  pubblici Mumble. Solo ascolto, solo servizi gratuiti senza chiavi. Sceglie il
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
                  tuning: Tuning(hz: 14_074_000, emission: .usb, bandwidth: 2800), latitude: nil, longitude: nil)
    ]
}

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class LiveRadio: ObservableObject {
    static let shared = LiveRadio()

    enum Band: String, Sendable {
        case hf, cb, poc

        /// HF e CB arrivano dagli stessi ricevitori KiwiSDR.
        var isKiwi: Bool { self != .poc }
    }

    /// Funzione Pro chiesta da chi non ce l'ha: l'interfaccia propone
    /// Talky Pro o, su iPhone, un video per 24 ore.
    enum ProPrompt: String, Identifiable {
        case scan, background, freeTime
        var id: String { rawValue }
    }

    /// Talky Pro (o, su iPhone, il pass di 24 ore guadagnato con un video):
    /// ascolto senza limite, SCAN automatico e ascolto a schermo spento.
    /// Ogni app imposta il suo controllo all'avvio.
    var proGate: () -> Bool = { true }

    @Published private(set) var band: Band?
    @Published private(set) var hfIndex = 0
    @Published private(set) var tuning: Tuning = HFChannel.all[0].tuning
    @Published private(set) var pocChannels: [MumbleLiveChannel] = []
    @Published private(set) var pocIndex = 0
    @Published private(set) var isScouting = false
    /// Squelch CB acceso: fra un passaggio e l'altro non si sente il fruscio.
    @Published private(set) var squelchOn: Bool
    /// C'e' un segnale sulla frequenza CB adesso.
    @Published private(set) var squelchOpen = false
    /// Scansione POC e CB: salta da un canale all'altro e si ferma quando qualcuno parla.
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
    @Published var proPrompt: ProPrompt?
    /// Secondi gratis rimasti oggi, nil con Pro o con il pass.
    @Published private(set) var freeSecondsLeft: Int?
    /// I minuti gratis di oggi sono finiti: la banda resta scelta, muta.
    @Published private(set) var isOutOfFreeTime = false
    /// Spettro e cascata del ricevitore KiwiSDR che si ascolta.
    let panorama = Panorama()
    /// Ascolto fermato perche' l'app e' andata in background senza Pro.
    @Published private(set) var isSuspended = false
    @Published var volume: Float = 0.9 {
        didSet { player.setVolume(volume) }
    }

    var hfChannels: [HFChannel] { HFChannel.all }
    var currentHF: HFChannel { HFChannel.all[hfIndex] }
    var currentPOC: MumbleLiveChannel? { pocChannels.indices.contains(pocIndex) ? pocChannels[pocIndex] : nil }
    var isOn: Bool { band != nil }

    private let player = LivePlayer()
    private let squelch: Squelch
    /// Ultima sintonia CB, per riaccendere dove si era rimasti.
    private var cbTuning: Tuning
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

    private var listenTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private static let freeDayKey = "live_free_day"
    private static let freeUsedKey = "live_free_used"
    private static let cbHzKey = "live_cb_hz"
    private static let cbEmissionKey = "live_cb_emission"
    private static let squelchKey = "live_cb_squelch"

    private var lastLevelPush = Date.distantPast
    private var lastSignalPush = Date.distantPast

    private init() {
        let on = defaults.object(forKey: Self.squelchKey) as? Bool ?? true
        squelchOn = on
        squelch = Squelch(enabled: on)
        let hz = defaults.integer(forKey: Self.cbHzKey)
        let emission = defaults.string(forKey: Self.cbEmissionKey).flatMap(Emission.init(rawValue:))
        cbTuning = CitizensBand.dial.contains(hz)
            ? CitizensBand.tuning(hz: hz, emission: emission ?? CitizensBand.usualEmission(at: hz))
            : CitizensBand.firstTuning
        player.setVolume(volume)
    }

    // MARK: comandi

    func start(_ band: Band) {
        guard self.band != band else { return }
        stopScan()
        disconnect()
        isSuspended = false
        if band.isKiwi, scoutTask != nil {
            scoutTask?.cancel()
            scoutTask = nil
            isScouting = false
        }
        self.band = band
        panorama.clear()
        refreshFreeTime()
        guard !isOutOfFreeTime else {
            state = .idle
            proPrompt = .freeTime
            return
        }
        player.start()
        switch band {
        case .hf:
            tuning = currentHF.tuning
            loadReceivers()
            connectHF(fresh: true)
        case .cb:
            tuning = cbTuning
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
        isSuspended = false
        isOutOfFreeTime = false
        disconnect()
        panorama.clear()
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
        case .cb:
            stepCB(delta)
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

    /// Sintonia fine in HF e CB, a passi di kHz.
    func nudge(kHz: Int) {
        switch band {
        case .hf:
            let hz = min(Tuning.hfRange.upperBound, max(Tuning.hfRange.lowerBound, tuning.hz + kHz * 1000))
            tuning.hz = hz
            if let kiwi { Task { await kiwi.tune(tuning) } }
        case .cb:
            let range = CitizensBand.dial
            let hz = min(range.upperBound, max(range.lowerBound, tuning.hz + kHz * 1000))
            retuneCB(CitizensBand.tuning(hz: hz, emission: tuning.emission))
        case .poc, nil:
            break
        }
    }

    // MARK: CB

    /// Numero del canale CB su cui si e' sintonizzati, nil fuori canale.
    var cbChannel: Int? { CitizensBand.channel(at: tuning.hz) }
    var cbIsDX: Bool { CitizensBand.isDX(tuning.hz) }

    /// Canale 1...40.
    func selectCBChannel(_ number: Int) {
        guard (1 ... 40).contains(number) else { return }
        let hz = CitizensBand.channels[number - 1]
        retuneCB(CitizensBand.tuning(hz: hz, emission: emissionFollowing(to: hz)))
    }

    /// Frequenza scritta a mano, in Hz. Falso se e' fuori dalla CB.
    @discardableResult
    func tuneCB(hz: Int) -> Bool {
        guard CitizensBand.dial.contains(hz) else { return false }
        retuneCB(CitizensBand.tuning(hz: hz, emission: emissionFollowing(to: hz)))
        return true
    }

    /// Dai canali alla zona DX e ritorno.
    func toggleCBSection() {
        if cbIsDX {
            selectCBChannel(19)
        } else {
            retuneCB(CitizensBand.tuning(hz: CitizensBand.dxCall, emission: .usb))
        }
    }

    /// AM, FM, LSB, USB: in CB si usano tutte e quattro.
    func cycleCBMode() {
        guard band == .cb else { return }
        let order: [Emission] = [.am, .fm, .lsb, .usb]
        let next = order[((order.firstIndex(of: tuning.emission) ?? -1) + 1) % order.count]
        retuneCB(CitizensBand.tuning(hz: tuning.hz, emission: next))
    }

    func toggleSquelch() {
        squelchOn.toggle()
        squelch.isEnabled = squelchOn
        defaults.set(squelchOn, forKey: Self.squelchKey)
    }

    /// Canale dopo canale fra i 40, a passi di 5 kHz nella zona DX. Fuori
    /// griglia (dopo una sintonia fine) va al primo canale nella direzione.
    private func stepCB(_ delta: Int) {
        let hz = tuning.hz
        if CitizensBand.isDX(hz) {
            let steps = CitizensBand.dxSteps
            let target = delta > 0 ? steps.first { $0 > hz } ?? steps[0]
                                   : steps.last { $0 < hz } ?? steps[steps.count - 1]
            retuneCB(CitizensBand.tuning(hz: target, emission: tuning.emission))
            return
        }
        if let number = CitizensBand.channel(at: hz) {
            selectCBChannel((number - 1 + delta + 40) % 40 + 1)
            return
        }
        let channels = CitizensBand.channels
        let ahead = channels.indices.filter { delta > 0 ? channels[$0] > hz : channels[$0] < hz }
        let pick = delta > 0 ? ahead.min { channels[$0] < channels[$1] } : ahead.max { channels[$0] < channels[$1] }
        selectCBChannel((pick ?? (delta > 0 ? 0 : 39)) + 1)
    }

    /// L'emissione di solito segue il canale (AM fino al 35, LSB dal 36,
    /// USB in DX); se l'ha scelta chi ascolta (FM, per esempio) resta quella.
    private func emissionFollowing(to hz: Int) -> Emission {
        let usualHere = CitizensBand.usualEmission(at: tuning.hz)
        guard band == .cb, tuning.emission != usualHere else { return CitizensBand.usualEmission(at: hz) }
        return tuning.emission
    }

    private func retuneCB(_ t: Tuning) {
        cbTuning = t
        defaults.set(t.hz, forKey: Self.cbHzKey)
        defaults.set(t.emission.rawValue, forKey: Self.cbEmissionKey)
        guard band == .cb else { return }
        tuning = t
        squelch.retuned(to: t)
        squelchOpen = false
        if isScanning { scanSince = Date() }
        if let kiwi {
            if !isScanning { player.flush() }
            Task { await kiwi.tune(t) }
        }
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
        guard band == .poc || band == .cb, !isScanning else { return }
        guard proGate() else {
            proPrompt = .scan
            return
        }
        isScanning = true
        scanHolding = false
        scanSince = Date()
        let scanning = band
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(scanning == .cb ? 100 : 250))
                guard let self, self.isScanning, self.band == scanning else { return }
                scanning == .cb ? self.cbScanTick() : self.scanTick()
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

    /// Come lo SCAN di un baracchino: un attimo su ogni canale, fermo finche'
    /// lo squelch resta aperto, avanti 3 secondi dopo che il segnale e' sparito.
    /// Scorre la parte in cui si e': i 40 canali o la zona DX.
    private func cbScanTick() {
        let now = Date()
        guard state == .online else {
            scanSince = now
            return
        }
        if squelch.isOpen {
            scanHolding = true
            lastVoice = now
            return
        }
        if scanHolding {
            // Se era solo rumore o una portante muta, avanti subito.
            guard squelch.closedOnNoise || now.timeIntervalSince(lastVoice) > 3 else { return }
            scanHolding = false
            scanSince = now
            stepCB(1)
            return
        }
        // Assestamento dopo il cambio, piu' qualche pacchetto per decidere.
        if now.timeIntervalSince(scanSince) > Squelch.settle + 0.45 {
            stepCB(1)
        }
    }

    // MARK: background

    /// L'app va in background senza Pro: l'ascolto si ferma ma la banda
    /// resta scelta, cosi' al ritorno riparte da sola.
    func suspendForBackground() {
        guard band != nil, !isSuspended, !proGate() else { return }
        stopScan()
        disconnect()
        player.stop()
        state = .idle
        isSuspended = true
    }

    /// Ritorno in primo piano dopo una sospensione: riparte e propone il Pro.
    func resumeFromBackground() {
        guard isSuspended, !isOutOfFreeTime, let band else { return }
        isSuspended = false
        player.start()
        switch band {
        case .hf, .cb: connectHF(fresh: true)
        case .poc: pocChannels.isEmpty ? scoutPOC() : connectPOC()
        }
        proPrompt = .background
    }

    // MARK: tempo d'ascolto

    /// Conta solo l'ascolto vero: collegati e con il ricevitore in linea.
    private func startListeningClock() {
        guard listenTask == nil else { return }
        listenTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled, self.state == .online else { continue }
                self.spendFreeTime(5)
            }
        }
    }

    private func spendFreeTime(_ seconds: Int) {
        guard !proGate() else {
            freeSecondsLeft = nil
            return
        }
        let used = usedToday + seconds
        defaults.set(Self.today, forKey: Self.freeDayKey)
        defaults.set(used, forKey: Self.freeUsedKey)
        freeSecondsLeft = max(0, FreeListening.secondsPerDay - used)
        guard used >= FreeListening.secondsPerDay else { return }
        stopScan()
        disconnect()
        player.stop()
        state = .idle
        isOutOfFreeTime = true
        proPrompt = .freeTime
    }

    private var usedToday: Int {
        defaults.string(forKey: Self.freeDayKey) == Self.today ? defaults.integer(forKey: Self.freeUsedKey) : 0
    }

    private static var today: String {
        let d = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(d.year ?? 0)-\(d.month ?? 0)-\(d.day ?? 0)"
    }

    private func refreshFreeTime() {
        if proGate() {
            freeSecondsLeft = nil
            isOutOfFreeTime = false
        } else {
            freeSecondsLeft = max(0, FreeListening.secondsPerDay - usedToday)
            isOutOfFreeTime = freeSecondsLeft == 0
        }
    }

    /// Arrivati Pro o il pass, o cominciato un giorno nuovo: se l'ascolto era
    /// fermo per i minuti finiti, riparte sulla stessa banda.
    func entitlementsChanged() {
        let wasOut = isOutOfFreeTime
        refreshFreeTime()
        guard wasOut, !isOutOfFreeTime, let band else { return }
        if proPrompt == .freeTime { proPrompt = nil }
        player.start()
        switch band {
        case .hf, .cb: connectHF(fresh: true)
        case .poc: pocChannels.isEmpty ? scoutPOC() : connectPOC()
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
                if self.receivers.isEmpty, self.band?.isKiwi == true { self.state = .refused(.down) }
                return
            }
            let hadNone = self.receivers.isEmpty
            self.receivers = fresh
            if hadNone, self.band?.isKiwi == true { self.connectHF(fresh: true) }
        }
    }

    private func connectHF(fresh: Bool) {
        disconnect()
        guard let band, band.isKiwi, !isSuspended else { return }
        if fresh {
            // La CB si ascolta vicino a chi usa l'app, come le bande radioamatoriali.
            candidates = band == .cb ? rankReceivers(latitude: nil, longitude: nil)
                                     : rankReceivers(latitude: currentHF.latitude, longitude: currentHF.longitude)
            candidateIndex = 0
            if band == .hf { tuning = currentHF.tuning }
        }
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
        squelch.reset(for: tuning)
        squelchOpen = false
        panorama.clear()
        // CB: sei canali in vista (58 kHz); HF: 29 kHz, una manciata di stazioni SSB.
        let listener = KiwiListener(receiver: receiver, tuning: tuning, squelch: band == .cb ? squelch : nil,
                                    spectrumZoom: band == .cb ? 9 : 10)
        kiwi = listener
        attach(audio: listener.audio, events: listener.events)
        Task { await listener.connect() }
    }

    /// I ricevitori con posti liberi, dal piu' vicino alla stazione (o a chi
    /// ascolta, per le bande radioamatoriali).
    private func rankReceivers(latitude: Double?, longitude: Double?) -> [KiwiReceiver] {
        let here = ApproximatePlace.current
        let lat = latitude ?? here.latitude
        let lon = longitude ?? here.longitude
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
        guard band == .poc, !isSuspended, let target = currentPOC else { return }
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
                startListeningClock()
            case .refused(let p):
                band == .poc ? pocFailed(refused: true) : hfFailed(p, refused: true)
            case .dropped(let p):
                band == .poc ? pocFailed(refused: false) : hfFailed(p, refused: false)
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
        case .squelch(let open):
            squelchOpen = open
        case .level(let v):
            let now = Date()
            if v > 0.02 { lastVoice = now }
            guard now.timeIntervalSince(lastLevelPush) > 0.1 || (v == 0 && level != 0) else { return }
            lastLevelPush = now
            level = v
        case .sweep(let sweep):
            panorama.add(sweep, dialHz: tuning.hz, passband: KiwiFrame.passband(tuning))
        }
    }

    private func disconnect() {
        listenTask?.cancel()
        listenTask = nil
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
        squelchOpen = false
    }
}

/// Dove si trova, piu' o meno, chi ascolta, senza chiedere la posizione:
/// il capoluogo del suo fuso orario (Atlantic/Canary e' Las Palmas, non la
/// Francia che dava la sola differenza da UTC). Serve solo a scegliere un
/// ricevitore vicino.
@available(iOS 16.0, macOS 13.0, *)
nonisolated enum ApproximatePlace {
    static var current: (latitude: Double, longitude: Double) {
        let tz = TimeZone.current
        if let spot = zoneSpots[tz.identifier] { return spot }
        // Fuso fuori tabella (GMT+3 e simili): dalla differenza da UTC e dal paese.
        let offset = Double(tz.secondsFromGMT() - Int(tz.daylightSavingTimeOffset())) / 3600
        let region = Locale.current.region?.identifier ?? ""
        let south: Set<String> = ["AU", "NZ", "BR", "AR", "CL", "ZA", "UY", "PY", "BO", "PE"]
        let tropics: Set<String> = ["IN", "ID", "TH", "VN", "PH", "MY", "SG", "NG", "KE", "MX", "CO", "VE", "EC", "GH", "SA", "AE"]
        let latitude = south.contains(region) ? -30.0 : tropics.contains(region) ? 15.0 : 45.0
        return (latitude, offset * 15)
    }

    /// TimeZoneSpots.txt: `Europe/Rome 41.90 12.48`, una riga per fuso.
    private static let zoneSpots: [String: (latitude: Double, longitude: Double)] = {
        guard let url = Bundle.main.url(forResource: "TimeZoneSpots", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var spots: [String: (latitude: Double, longitude: Double)] = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let f = line.split(separator: " ")
            guard f.count == 3, let lat = Double(f[1]), let lon = Double(f[2]) else { continue }
            spots[String(f[0])] = (lat, lon)
        }
        return spots
    }()
}
