//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - WalkieEngine.swift
//  macTalky
//
//  Porta macOS del bridge TALKY1 (TalkyCrossPlatformManager su iOS,
//  CrossPlatformWalkieManager su Android). Stesso protocollo di rete:
//  Bonjour `_walkie-talkie._tcp.` + TCP con frame [len UInt32 BE][payload],
//  messaggi testuali "TALKY1|TYPE|k=v|k=v\n" e audio PCM16LE mono 48kHz.
//
//  A differenza di iOS (dove Multipeer resta il transport primario
//  iPhone-iPhone), su macOS questo È il transport: parla con iPhone,
//  Android e altri Mac attraverso lo stesso endpoint TALKY1.

import Foundation
import Network
import AVFoundation
import Combine

final class WalkieEngine: NSObject, ObservableObject {
    static let shared = WalkieEngine()

    private enum Constant {
        static let version = "TALKY1"
        static let serviceType = "_walkie-talkie._tcp."
        static let serviceDomain = "local."
        static let txtProtocolKey = "proto"
        static let txtProtocolValue = "talky1"
        static let defaultChannel = "public"
        static let sampleRate: Double = 48000
        /// Durata massima di una singola trasmissione PTT (una trasmissione = un frame,
        /// e il receiver iOS/Android scarta frame > 1 MB ≈ 10.9 s di PCM16 @48k).
        static let maxTransmitSeconds: Double = 10
        /// Jitter buffer prima di far partire il player node su uno stream a
        /// frame piccoli (Android). Sotto questa soglia si parte comunque dopo
        /// `prerollTimeout` — le trasmissioni brevissime non devono restare in coda.
        static let prerollSeconds: Double = 0.15
        static let prerollTimeout: Double = 0.12
        /// Silenzio dopo l'ultimo frame oltre il quale la ricezione è conclusa
        /// (il protocollo TALKY1 non ha un marcatore di fine trasmissione).
        static let receiveTailSeconds: Double = 0.35
        /// Margine oltre la durata dell'audio ancora in coda dopo il quale la
        /// ricezione viene chiusa comunque. Serve da salvagente: se i completion
        /// del player node non arrivano più (tipico se il device audio di output
        /// cambia a metà ricezione) `isReceiving` resterebbe alto per sempre e,
        /// essendo il PTT half-duplex, bloccherebbe il microfono fino al riavvio.
        static let receiveHardTimeout: Double = 2
        /// Intervallo di riconciliazione dei peer scoperti ma non connessi.
        static let reconnectInterval: Double = 5
        /// Oltre questa attesa una connessione uscente è considerata persa e
        /// il peer torna candidabile per un nuovo tentativo.
        static let connectAttemptTimeout: Double = 10
    }

    struct Peer: Identifiable, Equatable {
        let id: String
        let name: String
        let host: String
        let port: Int
        let channel: String
    }

    // MARK: - Published state (UI)

    @Published private(set) var peers: [Peer] = []
    @Published private(set) var connectedPeerCount: Int = 0
    @Published private(set) var connectedPeerIDs: Set<String> = []
    @Published private(set) var status: String = "Standby"
    @Published private(set) var isNetworkActive = false
    @Published private(set) var isTransmitting = false
    @Published private(set) var isReceiving = false
    @Published private(set) var hasMicPermission = false
    /// Livello RMS 0...1 del microfono durante la trasmissione (per il VU meter).
    @Published private(set) var inputLevel: Float = 0
    /// Secondi trascorsi dall'inizio della trasmissione corrente.
    @Published private(set) var transmitElapsed: Double = 0

    // MARK: - Private

    private let logger = Logger.shared
    private let queue = DispatchQueue(label: "talky.mac.network", qos: .userInitiated)
    private let uid = UUID().uuidString
    private var deviceName: String {
        SettingsManager.shared.deviceDisplayName
    }

    private var listener: NWListener?
    private var netService: NetService?
    private var browser: NetServiceBrowser?
    private var resolvingServices: [NetService] = []
    private var started = false
    private var connections: [String: NWConnection] = [:]

    // Roster di discovery (tutto isolato su `queue`). Bonjour annuncia un peer
    // una volta sola: se il TCP cade, nessun nuovo evento `didFind` arriva, per
    // cui la riconnessione deve partire da qui e non dal browser.
    private var discovered: [String: Peer] = [:]
    private var serviceNameToPeerID: [String: String] = [:]
    /// peerID → tentativo di connessione uscente in volo. Tenere anche la
    /// NWConnection permette di chiudere quella bloccata prima di riprovare,
    /// altrimenti ogni giro del timer ne accumulerebbe una nuova.
    private var connecting: [String: (started: Date, connection: NWConnection)] = [:]
    private var reconnectTimer: DispatchSourceTimer?

    // Audio capture
    private var captureEngine: AVAudioEngine?
    private var captureConverter: AVAudioConverter?
    private let captureAccumulator = PCMAccumulator()
    private var transmitTimer: Timer?
    private var transmitStartDate: Date?

    // Audio playback (streaming, main thread)
    //
    // Android trasmette a raffica frame PCM piccoli (~2048 campioni ≈ 43 ms)
    // per tutta la durata della pressione; iOS invia invece l'intera
    // trasmissione in un frame solo. Un engine per frame spezzerebbe l'audio
    // Android in continuazione, quindi engine e player node sono persistenti e
    // i buffer vengono semplicemente accodati.
    private var playbackEngine: AVAudioEngine?
    private var playbackNode: AVAudioPlayerNode?
    private var duckedRadioVolume: Float?
    /// Frame accodati al player node e non ancora riprodotti.
    private var queuedFrames = 0
    /// True dopo il `play()` della ricezione corrente (post pre-roll).
    private var playbackStarted = false
    private var lastAudioArrival = Date.distantPast
    private var receiveWatchdog: Timer?
    private lazy var playbackFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                    sampleRate: Constant.sampleRate,
                                                    channels: 1,
                                                    interleaved: false)

    private var ownServiceName: String { "Talky Mac \(uid.prefix(4))" }

    private var currentChannelID: String {
        UserDefaults.standard.string(forKey: "private_channel_id") ?? Constant.defaultChannel
    }

    private override init() {
        super.init()
        refreshMicPermission()
    }

    // MARK: - Lifecycle

    func start() {
        queue.async { [weak self] in
            guard let self, !self.started else { return }
            self.started = true
            self.setStatus("Starting link…")
            self.startListener()
            // Se il listener non è nemmeno partito, `startListener` ha già fatto
            // teardown e azzerato `started`: non avviare browser e timer.
            guard self.started else { return }
            self.startBrowsing()
            self.startReconnectTimer()
        }
        // `isNetworkActive` NON viene alzato qui: la lampada NET deve accendersi
        // solo quando il listener è davvero in `.ready` e Bonjour ha pubblicato,
        // altrimenti un listener fallito resta indistinguibile da uno attivo.
    }

    func stop() {
        queue.async { [weak self] in
            self?.teardown(status: "Standby")
        }
    }

    /// Smonta listener, Bonjour, connessioni e timer. Da chiamare su `queue`.
    private func teardown(status: String) {
        listener?.cancel()
        listener = nil
        browser?.stop()
        browser = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        discovered.removeAll()
        serviceNameToPeerID.removeAll()
        connecting.removeAll()
        reconnectTimer?.cancel()
        reconnectTimer = nil
        publishConnectionCount()
        started = false
        setStatus(status)

        // NetService è schedulato sul main runloop: va fermato lì.
        let service = netService
        netService = nil
        DispatchQueue.main.async {
            service?.stop()
            // `resolvingServices` è toccato solo dai delegate NetService, che
            // girano sul main runloop: svuotarlo da `queue` sarebbe una race.
            self.resolvingServices.removeAll()
            self.peers.removeAll()
            self.isNetworkActive = false
            self.endReceiving()
        }
    }

    /// Riavvia pubblicazione e browsing dopo un cambio canale (pubblico ↔ privato).
    func channelDidChange() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.start()
        }
    }

    // MARK: - Microphone permission

    func refreshMicPermission() {
        hasMicPermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasMicPermission = granted
                self?.logger.logAudioInfo("Permesso microfono macOS: \(granted ? "concesso" : "negato")")
            }
        }
    }

    // MARK: - Push-to-talk

    func startTransmitting() {
        guard !isTransmitting else { return }
        guard hasMicPermission else {
            requestMicPermission()
            return
        }
        guard connectedPeerCount > 0 else {
            setStatus("No peers connected")
            return
        }
        // Half-duplex, come una radio vera: aprire il microfono mentre un peer
        // sta parlando farebbe rientrare dagli altoparlanti la voce ricevuta.
        guard !isReceiving else {
            setStatus("Busy — a peer is talking")
            return
        }

        captureAccumulator.reset()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let nativeFormat = input.outputFormat(forBus: 0)
        guard nativeFormat.sampleRate > 0, nativeFormat.channelCount > 0 else {
            logger.logAudioError(WalkieTalkieError.invalidAudioFormat, context: "Formato input non valido")
            return
        }

        guard let wireFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: Constant.sampleRate,
                                             channels: 1,
                                             interleaved: false),
              let converter = AVAudioConverter(from: nativeFormat, to: wireFormat) else {
            logger.logAudioError(WalkieTalkieError.invalidAudioFormat, context: "Creazione converter 48k mono")
            return
        }

        captureEngine = engine
        captureConverter = converter

        let accumulator = captureAccumulator
        let ratio = Constant.sampleRate / nativeFormat.sampleRate

        input.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] buffer, _ in
            // Thread audio realtime: converte a 48k mono e accumula (lock-protected).
            let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: wireFormat, frameCapacity: outCapacity) else { return }

            var fed = false
            var convError: NSError?
            converter.convert(to: outBuffer, error: &convError) { _, outStatus in
                if fed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                fed = true
                outStatus.pointee = .haveData
                return buffer
            }
            guard convError == nil, outBuffer.frameLength > 0,
                  let channel = outBuffer.floatChannelData?[0] else { return }

            let frames = Int(outBuffer.frameLength)
            let data = Data(bytes: channel, count: frames * MemoryLayout<Float32>.size)
            accumulator.append(data)

            // VU meter: RMS del buffer convertito.
            var sum: Float = 0
            for i in 0..<frames { sum += channel[i] * channel[i] }
            let rms = sqrt(sum / Float(max(frames, 1)))
            DispatchQueue.main.async {
                self?.inputLevel = min(1, rms * 4)
            }
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            captureEngine = nil
            captureConverter = nil
            logger.logAudioError(error, context: "Avvio capture engine")
            return
        }

        isTransmitting = true
        transmitStartDate = Date()
        transmitElapsed = 0
        setStatus("Transmitting…")
        logger.logAudioInfo("Trasmissione PTT avviata (native SR \(nativeFormat.sampleRate) → 48000 mono)")

        transmitTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.transmitStartDate else { return }
            self.transmitElapsed = Date().timeIntervalSince(start)
            if self.transmitElapsed >= Constant.maxTransmitSeconds {
                self.stopTransmitting()
            }
        }
        // `.common`: il PTT si tiene premuto col mouse, quindi il run loop è in
        // event tracking e un timer in modalità default si fermerebbe proprio
        // lì — cronometro fermo e cap dei 10 s che non scatta.
        RunLoop.main.add(timer, forMode: .common)
        transmitTimer = timer
    }

    func stopTransmitting() {
        guard isTransmitting else { return }

        transmitTimer?.invalidate()
        transmitTimer = nil
        transmitStartDate = nil

        if let engine = captureEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        captureEngine = nil
        captureConverter = nil

        isTransmitting = false
        inputLevel = 0
        setStatus("Ready")

        let floatPCM = captureAccumulator.drain()
        guard !floatPCM.isEmpty else {
            logger.logAudioInfo("Trasmissione vuota, nessun invio")
            return
        }
        sendAudio(floatPCM: floatPCM)
        logger.logAudioInfo("Trasmissione PTT conclusa: \(floatPCM.count) bytes Float32 @48k")
    }

    // MARK: - Wire send (identico a iOS TalkyCrossPlatformManager)

    func sendAudio(floatPCM data: Data) {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.connections.isEmpty else { return }

            let pcm16 = self.convertFloat32ToPCM16LE(data)
            guard !pcm16.isEmpty else { return }

            let meta = self.encodeLine(
                type: "AUDIO_META",
                fields: [
                    "byteCount": "\(pcm16.count)",
                    "sampleRate": "48000",
                    "channels": "1",
                    "encoding": "pcm_s16le"
                ]
            )

            for connection in self.connections.values {
                self.sendFrame(Data(meta.utf8), on: connection)
                self.sendFrame(pcm16, on: connection)
            }

            self.logger.logAudioInfo("TALKY1 audio inviato: \(pcm16.count) bytes a \(self.connections.count) peer")
        }
    }

    // MARK: - Listener / Bonjour

    private func startListener() {
        do {
            let listener = try NWListener(using: .tcp)
            self.listener = listener

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleIncoming(connection)
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                // Un cambio canale fa stop()+start(): senza questo controllo il
                // `.cancelled` del listener vecchio potrebbe arrivare dopo il
                // `.ready` di quello nuovo e spegnere la lampada NET.
                guard self.listener === listener else { return }
                switch state {
                case .ready:
                    if let port = listener.port {
                        self.publishService(port: Int(port.rawValue))
                        self.setStatus("Ready on port \(port.rawValue)")
                        DispatchQueue.main.async { self.isNetworkActive = true }
                    }
                case .failed(let error):
                    self.logger.logNetworkError(error, context: "TALKY1 listener failed")
                    // Teardown completo: senza questo `started` resterebbe true e
                    // il pulsante START LINK non potrebbe più riprovare.
                    self.teardown(status: "Listener failed")
                case .cancelled:
                    DispatchQueue.main.async { self.isNetworkActive = false }
                default:
                    break
                }
            }

            listener.start(queue: queue)
        } catch {
            logger.logNetworkError(error, context: "TALKY1 listener setup")
            teardown(status: "Network unavailable")
        }
    }

    private func publishService(port: Int) {
        let service = NetService(
            domain: Constant.serviceDomain,
            type: Constant.serviceType,
            name: ownServiceName,
            port: Int32(port)
        )
        let txt: [String: Data] = [
            Constant.txtProtocolKey: Data(Constant.txtProtocolValue.utf8),
            "uid": Data(uid.utf8),
            "name": Data(deviceName.utf8),
            "channel": Data(currentChannelID.utf8)
        ]
        service.setTXTRecord(NetService.data(fromTXTRecord: txt))
        service.delegate = self
        // NetService è runloop-based: schedulato sul main runloop.
        DispatchQueue.main.async {
            service.schedule(in: .main, forMode: .common)
            service.publish()
        }
        netService = service
        logger.logNetworkInfo("TALKY1 Bonjour pubblicato su porta \(port) come \(ownServiceName)")
    }

    private func startBrowsing() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.schedule(in: .main, forMode: .common)
            browser.searchForServices(ofType: Constant.serviceType, inDomain: Constant.serviceDomain)
            self.browser = browser
        }
    }

    // MARK: - Connections

    private func handleIncoming(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.sendHello(on: connection)
                self?.receiveFrame(on: connection)
            } else if case .failed = state {
                self?.remove(connection: connection)
            } else if case .cancelled = state {
                self?.remove(connection: connection)
            }
        }
        connection.start(queue: queue)
    }

    /// Registra un peer risolto via Bonjour e prova a connettersi. Su `queue`.
    private func registerDiscovered(_ peer: Peer, serviceName: String) {
        discovered[peer.id] = peer
        serviceNameToPeerID[serviceName] = peer.id
        upsert(peer)
        connectIfNeeded(to: peer)
    }

    /// Apre una connessione uscente solo se non ce n'è già una viva o in volo.
    private func connectIfNeeded(to peer: Peer) {
        guard connections[peer.id] == nil else { return }
        if let attempt = connecting[peer.id] {
            guard Date().timeIntervalSince(attempt.started) >= Constant.connectAttemptTimeout else { return }
            // Tentativo precedente mai andato a buon fine: chiuderlo, altrimenti
            // resta appeso e se ne somma uno nuovo a ogni riconciliazione.
            attempt.connection.cancel()
            connecting.removeValue(forKey: peer.id)
        }

        let endpointHost = NWEndpoint.Host(peer.host)
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(peer.port)) else { return }

        let connection = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.sendHello(on: connection)
                self.receiveFrame(on: connection)
            case .failed, .cancelled:
                // Solo se è ancora IL tentativo tracciato: il cancel di un
                // tentativo vecchio arriva dopo che il nuovo è già registrato.
                if self.connecting[peer.id]?.connection === connection {
                    self.connecting.removeValue(forKey: peer.id)
                }
                self.remove(connection: connection)
            default:
                break
            }
        }
        connecting[peer.id] = (Date(), connection)
        connection.start(queue: queue)
    }

    /// Riconciliazione periodica: Bonjour annuncia un peer una volta sola, quindi
    /// dopo una caduta TCP nessun evento del browser rimetterebbe su il link.
    private func startReconnectTimer() {
        reconnectTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Constant.reconnectInterval,
                       repeating: Constant.reconnectInterval)
        timer.setEventHandler { [weak self] in
            guard let self, self.started else { return }
            for (id, peer) in self.discovered where self.connections[id] == nil {
                self.connectIfNeeded(to: peer)
            }
        }
        reconnectTimer = timer
        timer.resume()
    }

    private func sendHello(on connection: NWConnection) {
        let line = encodeLine(
            type: "HELLO",
            fields: [
                "uid": uid,
                "name": deviceName,
                "channel": currentChannelID
            ]
        )
        sendFrame(Data(line.utf8), on: connection)
    }

    private func sendFrame(_ payload: Data, on connection: NWConnection) {
        var length = UInt32(payload.count).bigEndian
        let header = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        var frame = Data()
        frame.append(header)
        frame.append(payload)

        connection.send(content: frame, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.logger.logNetworkError(error, context: "TALKY1 frame send")
            }
        })
    }

    private func receiveFrame(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, isComplete, error in
            guard let self else { return }
            if error != nil { return }
            guard let header, header.count == 4 else {
                if isComplete { connection.cancel() }
                return
            }

            let length = header.reduce(UInt32(0)) { partial, byte in
                (partial << 8) | UInt32(byte)
            }

            guard length > 0, length <= 1024 * 1024 else { return }

            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] payload, _, payloadComplete, payloadError in
                guard let self else { return }
                if payloadError != nil { return }
                if let payload {
                    self.handleFrame(payload, from: connection)
                }
                if payloadComplete {
                    connection.cancel()
                } else {
                    self.receiveFrame(on: connection)
                }
            }

            if isComplete {
                connection.cancel()
            }
        }
    }

    private func handleFrame(_ payload: Data, from connection: NWConnection) {
        if let line = String(data: payload, encoding: .utf8),
           let message = decodeLine(line) {
            handleMessage(message, from: connection)
            return
        }

        let floatPCM = convertPCM16LEToFloat32(payload)
        guard !floatPCM.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.playReceivedAudio(floatPCM)
        }
    }

    private func handleMessage(_ message: (type: String, fields: [String: String]), from connection: NWConnection) {
        switch message.type {
        case "HELLO":
            let peer = Peer(
                id: message.fields["uid"] ?? UUID().uuidString,
                name: message.fields["name"] ?? "Talky device",
                host: "tcp",
                port: 0,
                channel: message.fields["channel"] ?? Constant.defaultChannel
            )
            if let existing = connections[peer.id], existing !== connection {
                existing.cancel()
            }
            connections[peer.id] = connection
            // Se l'HELLO è arrivato su una connessione entrante mentre ne era in
            // volo una uscente verso lo stesso peer, quest'ultima va chiusa.
            if let attempt = connecting.removeValue(forKey: peer.id), attempt.connection !== connection {
                attempt.connection.cancel()
            }
            publishConnectionCount()
            upsert(peer)
            setStatus("Ready")
            logger.logNetworkInfo("TALKY1 HELLO ricevuto da \(peer.name)")
        case "HEARTBEAT":
            break
        case "AUDIO_META":
            logger.logAudioInfo("TALKY1 audio in arrivo")
        default:
            logger.logNetworkDebug("TALKY1 messaggio non gestito: \(message.type)")
        }
    }

    // MARK: - Playback (main thread)

    /// Accoda un frame audio in arrivo. Non ferma mai la riproduzione in corso:
    /// engine e player node restano vivi per tutta la ricezione, così uno stream
    /// Android fatto di decine di frame da ~43 ms suona continuo.
    private func playReceivedAudio(_ floatPCM: Data) {
        guard let format = playbackFormat else { return }

        let frameCount = AVAudioFrameCount(floatPCM.count / MemoryLayout<Float32>.size)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        floatPCM.withUnsafeBytes { bytes in
            guard let src = bytes.bindMemory(to: Float32.self).baseAddress,
                  let dst = buffer.floatChannelData?[0] else { return }
            dst.update(from: src, count: Int(frameCount))
        }

        guard let node = preparePlaybackNode(format: format) else { return }

        lastAudioArrival = Date()
        if !isReceiving { beginReceiving() }

        queuedFrames += Int(frameCount)
        node.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                // Clamp: `endReceiving()` azzera la coda e i completion residui
                // arriverebbero comunque, falsando il pre-roll successivo.
                self.queuedFrames = max(0, self.queuedFrames - Int(frameCount))
            }
        }

        // Pre-roll: con frame piccoli conviene accumulare un minimo di jitter
        // buffer prima di partire, altrimenti il node va in underrun a ogni
        // esitazione della rete. Un frame unico (iOS) supera subito la soglia.
        if !playbackStarted, Double(queuedFrames) / Constant.sampleRate >= Constant.prerollSeconds {
            playbackStarted = true
            node.play()
        }
    }

    /// Crea (una volta sola) engine e player node e li rimette in moto se erano
    /// stati fermati alla fine della ricezione precedente.
    private func preparePlaybackNode(format: AVAudioFormat) -> AVAudioPlayerNode? {
        if playbackEngine == nil {
            let engine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            playbackEngine = engine
            playbackNode = node
        }
        guard let engine = playbackEngine, let node = playbackNode else { return nil }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                logger.logAudioError(error, context: "Avvio playback engine")
                return nil
            }
        }
        return node
    }

    private func beginReceiving() {
        isReceiving = true

        // Duck della radio mentre parla un peer. Il ripristino usa il volume
        // persistito nelle Impostazioni (fonte di verità), così un tocco allo
        // slider durante la ricezione non viene sovrascritto dal restore.
        if duckedRadioVolume == nil, RadioManager.shared.isPlaying {
            duckedRadioVolume = SettingsManager.shared.radioVolume
            RadioManager.shared.setVolume((duckedRadioVolume ?? 0.5) * 0.2)
        }

        receiveWatchdog?.invalidate()
        let watchdog = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkReceiveProgress()
        }
        // `.common`: in modalità default il timer si ferma mentre il run loop è
        // in event tracking (trascinamento, scroll) — cioè proprio mentre si
        // tiene premuto il PTT — e la ricezione non si chiuderebbe in tempo.
        RunLoop.main.add(watchdog, forMode: .common)
        receiveWatchdog = watchdog
        logger.logAudioInfo("Ricezione audio avviata")
    }

    /// TALKY1 non ha un marcatore di fine trasmissione: la ricezione si chiude
    /// quando la coda è vuota e da un po' non arriva più nulla.
    private func checkReceiveProgress() {
        guard isReceiving else { return }
        let idle = Date().timeIntervalSince(lastAudioArrival)

        // Trasmissione più corta del pre-roll: parti comunque.
        if !playbackStarted, queuedFrames > 0, idle >= Constant.prerollTimeout {
            playbackStarted = true
            playbackNode?.play()
        }

        if playbackStarted, queuedFrames <= 0, idle >= Constant.receiveTailSeconds {
            endReceiving()
            return
        }

        // Salvagente contro una coda che non si svuota più. La soglia include la
        // durata dell'audio ancora accodato, altrimenti troncherebbe le
        // trasmissioni iOS, che arrivano in un frame unico da 10 s: lì `idle`
        // cresce da subito mentre il buffer è ancora tutto da riprodurre.
        let queuedSeconds = Double(max(queuedFrames, 0)) / Constant.sampleRate
        if idle >= queuedSeconds + Constant.receiveHardTimeout {
            logger.logAudioWarning("Ricezione chiusa dal timeout di sicurezza (coda non svuotata)")
            endReceiving()
        }
    }

    private func endReceiving() {
        receiveWatchdog?.invalidate()
        receiveWatchdog = nil
        playbackNode?.stop()
        playbackEngine?.stop()
        playbackStarted = false
        queuedFrames = 0

        guard isReceiving else { return }
        isReceiving = false
        if duckedRadioVolume != nil {
            RadioManager.shared.setVolume(SettingsManager.shared.radioVolume)
            duckedRadioVolume = nil
        }
        logger.logAudioInfo("Ricezione audio conclusa")
    }

    // MARK: - PCM conversion (identica a iOS)

    private func convertPCM16LEToFloat32(_ data: Data) -> Data {
        var output = Data()
        output.reserveCapacity((data.count / 2) * MemoryLayout<Float32>.size)

        var index = 0
        while index + 1 < data.count {
            let low = UInt16(data[index])
            let high = UInt16(data[index + 1]) << 8
            let sample = Int16(bitPattern: high | low)
            var floatSample = max(-1.0, min(1.0, Float32(sample) / Float32(Int16.max)))
            output.append(Data(bytes: &floatSample, count: MemoryLayout<Float32>.size))
            index += 2
        }

        return output
    }

    private func convertFloat32ToPCM16LE(_ data: Data) -> Data {
        var output = Data()
        output.reserveCapacity((data.count / MemoryLayout<Float32>.size) * 2)

        data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Float32.self)
            for sample in samples {
                let clipped = max(-1.0, min(1.0, sample))
                var pcm = Int16(clipped * Float32(Int16.max)).littleEndian
                output.append(Data(bytes: &pcm, count: MemoryLayout<Int16>.size))
            }
        }

        return output
    }

    // MARK: - Bookkeeping

    private func upsert(_ peer: Peer) {
        DispatchQueue.main.async {
            self.peers.removeAll { $0.id == peer.id }
            self.peers.append(peer)
        }
    }

    private func remove(connection: NWConnection) {
        let removedIDs = connections.compactMap { id, storedConnection in
            storedConnection === connection ? id : nil
        }
        guard !removedIDs.isEmpty else { return }

        for id in removedIDs {
            connections.removeValue(forKey: id)
        }
        publishConnectionCount()

        // I peer ancora annunciati su Bonjour restano nel roster come
        // "discovered": il timer di riconnessione riproverà il link.
        let dropped = removedIDs.filter { discovered[$0] == nil }
        guard !dropped.isEmpty else { return }
        DispatchQueue.main.async {
            self.peers.removeAll { dropped.contains($0.id) }
        }
    }

    private func publishConnectionCount() {
        let count = connections.count
        let ids = Set(connections.keys)
        DispatchQueue.main.async {
            self.connectedPeerCount = count
            self.connectedPeerIDs = ids
        }
    }

    private func setStatus(_ status: String) {
        DispatchQueue.main.async {
            self.status = status
        }
    }

    // MARK: - Line protocol

    private func encodeLine(type: String, fields: [String: String]) -> String {
        let encodedFields = fields
            .map { "\(percentEncode($0.key))=\(percentEncode($0.value))" }
            .joined(separator: "|")
        return "\(Constant.version)|\(type)|\(encodedFields)\n"
    }

    private func decodeLine(_ rawLine: String) -> (type: String, fields: [String: String])? {
        let line = rawLine.trimmingCharacters(in: .newlines)
        let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, parts[0] == Constant.version else { return nil }

        var fields: [String: String] = [:]
        for part in parts.dropFirst(2) {
            guard let separator = part.firstIndex(of: "=") else { continue }
            let key = String(part[..<separator])
            let value = String(part[part.index(after: separator)...])
            fields[percentDecode(key)] = percentDecode(value)
        }
        return (type: parts[1], fields: fields)
    }

    private func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func percentDecode(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }
}

// MARK: - NetServiceDelegate

extension WalkieEngine: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        logger.logNetworkInfo("TALKY1 service published: \(sender.name)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        logger.logNetworkWarning("TALKY1 service publish failed: \(errorDict)")
        // Senza annuncio Bonjour nessuno ci trova: la lampada NET non deve
        // restare accesa come se il link fosse operativo.
        setStatus("Bonjour publish failed")
        DispatchQueue.main.async { self.isNetworkActive = false }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        defer { resolvingServices.removeAll { $0 === sender } }
        guard sender.name != ownServiceName else { return }

        let txtData = sender.txtRecordData().flatMap(NetService.dictionary(fromTXTRecord:))
        let proto = txtData?[Constant.txtProtocolKey].flatMap { String(data: $0, encoding: .utf8) }
        guard proto == Constant.txtProtocolValue else { return }

        // Mai connettersi a se stessi (il nome può cambiare, l'uid no).
        let peerUID = txtData?["uid"].flatMap { String(data: $0, encoding: .utf8) }
        guard peerUID != uid else { return }

        let peerChannel = txtData?["channel"].flatMap { String(data: $0, encoding: .utf8) } ?? Constant.defaultChannel
        guard peerChannel == currentChannelID else { return }

        let host = sender.hostName ?? ""
        guard !host.isEmpty else { return }

        let peer = Peer(
            id: peerUID ?? sender.name,
            name: txtData?["name"].flatMap { String(data: $0, encoding: .utf8) } ?? sender.name,
            host: host,
            port: sender.port,
            channel: peerChannel
        )
        let serviceName = sender.name
        queue.async { [weak self] in
            self?.registerDiscovered(peer, serviceName: serviceName)
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolvingServices.removeAll { $0 === sender }
        logger.logNetworkWarning("TALKY1 resolve failed: \(errorDict)")
    }
}

// MARK: - NetServiceBrowserDelegate

extension WalkieEngine: NetServiceBrowserDelegate {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        logger.logNetworkInfo("TALKY1 browser avviato")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard service.name != ownServiceName else { return }
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        // Il nome del servizio Bonjour non coincide con il nome del dispositivo:
        // la rimozione passa dalla mappa serviceName → peerID.
        let serviceName = service.name
        queue.async { [weak self] in
            guard let self, let peerID = self.serviceNameToPeerID.removeValue(forKey: serviceName) else { return }
            self.discovered.removeValue(forKey: peerID)
            self.connecting.removeValue(forKey: peerID)
            self.connections.removeValue(forKey: peerID)?.cancel()
            self.publishConnectionCount()
            DispatchQueue.main.async {
                self.peers.removeAll { $0.id == peerID }
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        logger.logNetworkWarning("TALKY1 browser failed: \(errorDict)")
        setStatus("Discovery unavailable")
    }
}

// MARK: - PCMAccumulator

/// Accumulatore thread-safe per i buffer PCM provenienti dal thread audio realtime.
/// `nonisolated` esplicito: il progetto usa default-MainActor isolation, ma questo
/// oggetto è toccato dal tap audio fuori dal main thread.
final class PCMAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    /// 10.5 s di Float32 mono @48kHz — oltre, la trasmissione viene troncata
    /// (il frame TALKY1 max è 1 MB in PCM16).
    private let maxBytes = Int(48000 * 10.5) * MemoryLayout<Float32>.size

    func reset() {
        lock.lock()
        data = Data()
        lock.unlock()
    }

    func append(_ chunk: Data) {
        lock.lock()
        if data.count < maxBytes {
            data.append(chunk.prefix(maxBytes - data.count))
        }
        lock.unlock()
    }

    func drain() -> Data {
        lock.lock()
        let out = data
        data = Data()
        lock.unlock()
        return out
    }
}
