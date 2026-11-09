//creato da Andrea Piani - 13/06/26 - https://www.andreapiani.com - TalkyCrossPlatformManager.swift

import Foundation
import Network
import UIKit
import Combine

/// Bridge TCP/Bonjour compatibile con Android.
///
/// MultipeerConnectivity resta il transport primario iPhone-iPhone. Questo manager
/// espone in parallelo un endpoint esplicito `TALKY1` che Android può scoprire via
/// Bonjour e usare per l'handshake iniziale senza implementare il protocollo privato MC.
final class TalkyCrossPlatformManager: NSObject, ObservableObject {
    static let shared = TalkyCrossPlatformManager()

    private enum Constant {
        static let version = "TALKY1"
        static let serviceType = "_walkie-talkie._tcp."
        static let serviceDomain = "local."
        static let txtProtocolKey = "proto"
        static let txtProtocolValue = "talky1"
        static let defaultChannel = "public"
    }

    struct Peer: Identifiable, Equatable {
        let id: String
        let name: String
        let host: String
        let port: Int
        let channel: String
    }

    @Published private(set) var peers: [Peer] = []
    @Published private(set) var connectedPeerCount: Int = 0
    @Published private(set) var connectedPeerIDs: Set<String> = []
    @Published private(set) var status: String = "Cross-platform idle"

    private let logger = Logger.shared
    private let audioManager = AudioManager.shared
    private let queue = DispatchQueue(label: "talky.crossplatform.queue", qos: .userInitiated)
    /// Lo stesso id che l'iPhone annuncia su Multipeer: chi fa da ponte
    /// riconosce un dispositivo anche se lo vede da due trasporti.
    private let uid = Ponte.shared.uidLocale
    private let deviceName = UIDevice.current.name

    private var listener: NWListener?
    private var netService: NetService?
    private var browser: NetServiceBrowser?
    private var resolvingServices: [NetService] = []
    /// Nome Bonjour -> uid del peer. Il nome del servizio non e' il nome del
    /// dispositivo, quindi senza questa mappa un peer sparito restava in elenco.
    /// Toccata solo dai delegate NetService, sul main.
    private var serviceNameToPeerID: [String: String] = [:]
    private var started = false
    /// Tutte le connessioni vive per peer, la piu' recente in fondo. Con il Mac
    /// e Android ci si chiama a vicenda, quindi per un peer ce ne possono essere
    /// due, e l'altro lato ne chiude una sola: tenerne una per peer voleva dire
    /// restare, a volte, proprio con quella chiusa e smettere di trasmettere.
    private var connections: [String: [NWConnection]] = [:]

    /// Il messaggio che sta arrivando su ogni connessione, fra AUDIO_META e la
    /// sua fine. Serve al ponte: un messaggio si ritrasmette solo intero.
    private struct InArrivo {
        /// nil = versione senza ponte: si suona e basta.
        let trasmissione: Trasmissione?
        let peerUID: String?
        /// Android manda tanti frame fino ad AUDIO_END, iPhone e Mac uno solo.
        let flusso: Bool
        let attesi: Int
        let doppione: Bool
        var pcm16 = Data()
    }
    private var inArrivo: [ObjectIdentifier: InArrivo] = [:]
    /// Canale dichiarato nell'HELLO di ogni peer. Si manda e si ritrasmette solo
    /// a chi e' sul nostro canale: una connessione rimasta da prima di un cambio
    /// porterebbe la voce di una stanza privata a chi non ne fa parte.
    private var canalePerPeer: [String: String] = [:]

    /// Un messaggio intero arrivato da TALKY1 con ancora tratte da fare:
    /// MultipeerManager lo ritrasmette sugli altri peer, di tutti e due i
    /// trasporti. Chiamato sul main con l'audio gia' in Float32.
    var daInoltrare: ((Trasmissione, Data, String?) -> Void)?

    /// Oltre un frame TALKY1 nessuno legge: tutti scartano i frame sopra 1 MB.
    private static let maxFrameBytes = 1024 * 1024
    /// Una connessione uscente che non e' pronta entro questo tempo e' persa.
    private static let connectTimeout: TimeInterval = 10
    /// `kDNSServiceErr_PolicyDenied`: il permesso Rete locale e' spento.
    private static let policyDenied: Int32 = -65570

    private override init() {
        super.init()
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.started else { return }
            self.started = true
            self.startListener()
            self.startBrowsing()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.ferma()
            self?.setStatus("Cross-platform stopped")
        }
    }

    /// Dopo un cambio di canale: le connessioni del canale vecchio si chiudono,
    /// il TXT Bonjour si ripubblica con il canale nuovo e la ricerca riparte da
    /// capo, cosi' chi era gia' sul canale nuovo viene trovato e chiamato.
    func riavvia() {
        queue.async { [weak self] in
            guard let self, self.started else { return }
            self.ferma()
            self.started = true
            self.startListener()
            self.startBrowsing()
        }
    }

    /// Su `queue`.
    private func ferma() {
        listener?.cancel()
        listener = nil
        // NetService e browser vivono sul main run loop: si fermano li'.
        let service = netService
        let browser = browser
        netService = nil
        self.browser = nil
        DispatchQueue.main.async {
            service?.stop()
            browser?.stop()
            self.resolvingServices.removeAll()
            self.serviceNameToPeerID.removeAll()
            self.peers.removeAll()
        }
        let tutte = connections.values.joined()
        for connessione in tutte {
            abbandonaInArrivo(connessione)
        }
        connections.removeAll()
        canalePerPeer.removeAll()
        tutte.forEach { $0.cancel() }
        publishConnectionCount()
        started = false
    }

    /// Manda un messaggio audio ai peer TALKY1 indicati (uid), tutti se `a` e' nil.
    /// AUDIO_META e frame partono di seguito sulla stessa coda, quindi un
    /// messaggio ritrasmesso non si infila mai in mezzo a un altro.
    func sendAudio(floatPCM data: Data, trasmissione: Trasmissione, a destinatari: Set<String>? = nil) {
        queue.async { [weak self] in
            guard let self else { return }
            let canale = self.currentChannelID
            let scelte = self.connections.filter {
                (destinatari?.contains($0.key) ?? true) && self.canalePerPeer[$0.key] == canale
            }
            guard !scelte.isEmpty else { return }

            var pcm16 = self.convertFloat32ToPCM16LE(data)
            if pcm16.count > Self.maxFrameBytes {
                pcm16 = pcm16.prefix(Self.maxFrameBytes)
            }
            guard !pcm16.isEmpty else { return }

            var fields = trasmissione.campi
            fields["byteCount"] = "\(pcm16.count)"
            fields["sampleRate"] = "48000"
            fields["channels"] = "1"
            fields["encoding"] = "pcm_s16le"
            let meta = self.encodeLine(type: "AUDIO_META", fields: fields)

            for connection in scelte.values.compactMap(\.last) {
                self.sendFrame(Data(meta.utf8), on: connection)
                self.sendFrame(pcm16, on: connection)
            }

            self.logger.logAudioInfo("Cross-platform audio inviato: \(pcm16.count) bytes a \(scelte.count) peer")
        }
    }

    private var currentChannelID: String {
        UserDefaults.standard.string(forKey: "private_channel_id") ?? Constant.defaultChannel
    }

    private func startListener() {
        do {
            let listener = try NWListener(using: .tcp)
            self.listener = listener

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleIncoming(connection)
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    if let port = listener.port {
                        self.publishService(port: Int(port.rawValue))
                        self.setStatus("Cross-platform ready on \(port.rawValue)")
                    }
                case .failed(let error):
                    self.logger.logNetworkError(error, context: "Cross-platform listener failed")
                    self.setStatus("Cross-platform listener failed")
                case .cancelled:
                    self.setStatus("Cross-platform listener cancelled")
                default:
                    break
                }
            }

            listener.start(queue: queue)
        } catch {
            logger.logNetworkError(error, context: "Cross-platform listener setup")
            setStatus("Cross-platform unavailable")
        }
    }

    private func publishService(port: Int) {
        let service = NetService(
            domain: Constant.serviceDomain,
            type: Constant.serviceType,
            name: "Talky iPhone \(uid.prefix(4))",
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
        // NetService lavora sul run loop del thread che lo avvia, e questa coda
        // GCD non ne ha uno che giri: va agganciato al main, come sul Mac.
        DispatchQueue.main.async {
            service.schedule(in: .main, forMode: .common)
            service.publish()
        }
        netService = service
        logger.logNetworkInfo("Cross-platform Bonjour pubblicato su porta \(port)")
    }

    /// Creato su questa coda il browser non riceveva mai risposte: l'iPhone non
    /// trovava ne' chiamava nessun Mac o Android, si collegava solo se era
    /// l'altro a cercarlo (misurato con scripts/audit/talky1_prova.py).
    private func startBrowsing() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.schedule(in: .main, forMode: .common)
            browser.searchForServices(ofType: Constant.serviceType, inDomain: Constant.serviceDomain)
            self.queue.async { self.browser = browser }
        }
    }

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

    private func connect(to peer: Peer) {
        let endpointHost = NWEndpoint.Host(peer.host)
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(peer.port)) else { return }
        let connection = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
        // Il motivo si registra una volta sola per tentativo: `.waiting` puo'
        // ripetersi e dopo il cancel arriva comunque `.cancelled`.
        var esito: String?
        func fallita(_ motivo: String) {
            guard esito == nil else { return }
            esito = motivo
            Funnel.log(Funnel.connectionFailed, ["reason": motivo, "transport": "talky1"])
        }
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                esito = "ready"
                self?.sendHello(on: connection)
                self?.receiveFrame(on: connection)
            case .waiting(let error):
                // Con Rete locale spenta NWConnection resta in attesa per sempre.
                if Self.negatoDalPermesso(error) {
                    fallita("permission")
                    connection.cancel()
                }
            case .failed(let error):
                fallita(Self.motivo(error))
                self?.remove(connection: connection)
            case .cancelled:
                self?.remove(connection: connection)
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + Self.connectTimeout) {
            guard esito == nil else { return }
            fallita("timeout")
            connection.cancel()
        }
    }

    private static func negatoDalPermesso(_ error: NWError) -> Bool {
        if case .dns(let code) = error, code == policyDenied { return true }
        return false
    }

    private static func motivo(_ error: NWError) -> String {
        if negatoDalPermesso(error) { return "permission" }
        if case .posix(let code) = error {
            switch code {
            case .ETIMEDOUT: return "timeout"
            case .ECONNREFUSED: return "refused"
            default: break
            }
        }
        return "network"
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
                self?.logger.logNetworkError(error, context: "Cross-platform frame send")
            }
        })
    }

    private func receiveFrame(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, isComplete, error in
            guard let self else { return }
            if let error {
                self.logger.logNetworkError(error, context: "Cross-platform frame header receive")
                return
            }
            guard let header, header.count == 4 else { return }

            let length = header.reduce(UInt32(0)) { partial, byte in
                (partial << 8) | UInt32(byte)
            }

            guard length > 0, length <= 1024 * 1024 else { return }

            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] payload, _, payloadComplete, payloadError in
                guard let self else { return }
                if let payloadError {
                    self.logger.logNetworkError(payloadError, context: "Cross-platform frame payload receive")
                    return
                }
                if let payload {
                    self.handleFrame(payload, from: connection)
                }
                if !payloadComplete {
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

        let chiave = ObjectIdentifier(connection)
        if inArrivo[chiave]?.doppione == true { return }
        guard let uid = peerUID(of: connection), canalePerPeer[uid] == currentChannelID else { return }

        let floatPCM = convertPCM16LEToFloat32(payload)
        guard !floatPCM.isEmpty else { return }
        audioManager.playReceivedAudio(floatPCM)

        guard var corrente = inArrivo[chiave], corrente.trasmissione != nil else { return }
        let spazio = Self.maxFrameBytes - corrente.pcm16.count
        if spazio > 0 { corrente.pcm16.append(payload.prefix(spazio)) }
        inArrivo[chiave] = corrente
        if !corrente.flusso, corrente.pcm16.count >= corrente.attesi {
            concludi(connection)
        }
    }

    /// Chiude il messaggio in arrivo su questa connessione e, se ha ancora
    /// tratte da fare, lo passa al ponte. Su `queue`.
    private func concludi(_ connection: NWConnection) {
        guard let finito = inArrivo.removeValue(forKey: ObjectIdentifier(connection)),
              let trasmissione = finito.trasmissione, !finito.doppione else { return }
        // Da qui le altre copie sono doppioni: prima no, perche' se questa si
        // fosse interrotta una copia intera da un ponte doveva ancora passare.
        Ponte.shared.completa(trasmissione.id)
        guard trasmissione.ttl > 1, !finito.pcm16.isEmpty,
              let da = finito.peerUID, canalePerPeer[da] == currentChannelID else { return }
        let audio = convertPCM16LEToFloat32(finito.pcm16)
        DispatchQueue.main.async { [weak self] in
            self?.daInoltrare?(trasmissione, audio, da)
        }
    }

    /// Una connessione si chiude con un messaggio a meta': non lo si segna come
    /// arrivato, cosi' una copia intera da un altro ponte si suona. Su `queue`.
    private func abbandonaInArrivo(_ connection: NWConnection) {
        guard let rimasto = inArrivo.removeValue(forKey: ObjectIdentifier(connection)),
              let trasmissione = rimasto.trasmissione, !rimasto.doppione else { return }
        Ponte.shared.abbandona(trasmissione.id)
    }

    private func peerUID(of connection: NWConnection) -> String? {
        connections.first { $0.value.contains { $0 === connection } }?.key
    }

    private func handleMessage(_ message: (type: String, fields: [String: String]), from connection: NWConnection) {
        switch message.type {
        case "HELLO":
            let peer = Peer(
                id: message.fields["uid"] ?? UUID().uuidString,
                name: message.fields["name"] ?? "Android",
                host: "tcp",
                port: 0,
                channel: message.fields["channel"] ?? Constant.defaultChannel
            )
            guard peer.channel == currentChannelID else {
                logger.logNetworkInfo("Cross-platform HELLO da \(peer.name) su un altro canale: chiusa")
                connection.cancel()
                return
            }
            canalePerPeer[peer.id] = peer.channel
            var vive = connections[peer.id] ?? []
            if !vive.contains(where: { $0 === connection }) { vive.append(connection) }
            connections[peer.id] = vive
            publishConnectionCount()
            upsert(peer)
            Funnel.once(Funnel.connectionEstablished, ["transport": "talky1"])
            logger.logNetworkInfo("Cross-platform HELLO ricevuto da \(peer.name)")
        case "HEARTBEAT":
            break
        case "AUDIO_META":
            // Un messaggio rimasto aperto (flusso senza AUDIO_END) si chiude qui.
            if inArrivo[ObjectIdentifier(connection)] != nil { concludi(connection) }
            let trasmissione = Trasmissione(campi: message.fields)
            let doppione = trasmissione.map { !Ponte.shared.inizia($0.id) } ?? false
            inArrivo[ObjectIdentifier(connection)] = InArrivo(
                trasmissione: trasmissione,
                peerUID: peerUID(of: connection),
                flusso: message.fields[Trasmissione.Chiave.flusso] == "1",
                attesi: message.fields["byteCount"].flatMap(Int.init) ?? 0,
                doppione: doppione
            )
            logger.logAudioInfo(doppione ? "Cross-platform doppione scartato" : "Cross-platform audio in arrivo")
        case "AUDIO_END":
            concludi(connection)
        default:
            logger.logNetworkDebug("Cross-platform messaggio non gestito: \(message.type)")
        }
    }

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

    private func upsert(_ peer: Peer) {
        DispatchQueue.main.async {
            self.peers.removeAll { $0.id == peer.id }
            self.peers.append(peer)
        }
    }

    private func remove(connection: NWConnection) {
        abbandonaInArrivo(connection)
        var removedIDs: [String] = []
        for (id, vive) in connections where vive.contains(where: { $0 === connection }) {
            let rimaste = vive.filter { $0 !== connection }
            if rimaste.isEmpty {
                connections.removeValue(forKey: id)
                canalePerPeer.removeValue(forKey: id)
                removedIDs.append(id)
            } else {
                connections[id] = rimaste
            }
        }
        publishConnectionCount()
        guard !removedIDs.isEmpty else { return }

        DispatchQueue.main.async {
            self.peers.removeAll { removedIDs.contains($0.id) }
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

extension TalkyCrossPlatformManager: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        logger.logNetworkInfo("Cross-platform service published: \(sender.name)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        logger.logNetworkWarning("Cross-platform service publish failed: \(errorDict)")
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        defer { resolvingServices.removeAll { $0 === sender } }
        guard sender.name.hasPrefix("Talky iPhone") == false else { return }
        // Mai chiamare se stessi o un peer gia' collegato con un altro nome.
        let peerUID = sender.txtRecordData().flatMap(NetService.dictionary(fromTXTRecord:))?["uid"]
            .flatMap { String(data: $0, encoding: .utf8) }
        guard peerUID != uid else { return }

        let txtData = sender.txtRecordData().flatMap(NetService.dictionary(fromTXTRecord:))
        let proto = txtData?[Constant.txtProtocolKey].flatMap { String(data: $0, encoding: .utf8) }
        guard proto == Constant.txtProtocolValue else { return }

        let peerChannel = txtData?["channel"].flatMap { String(data: $0, encoding: .utf8) } ?? Constant.defaultChannel
        guard peerChannel == currentChannelID else { return }

        let host = sender.hostName ?? ""
        guard !host.isEmpty else { return }

        let peer = Peer(
            id: txtData?["uid"].flatMap { String(data: $0, encoding: .utf8) } ?? sender.name,
            name: txtData?["name"].flatMap { String(data: $0, encoding: .utf8) } ?? sender.name,
            host: host,
            port: sender.port,
            channel: peerChannel
        )
        serviceNameToPeerID[sender.name] = peer.id
        upsert(peer)
        Funnel.once(Funnel.peerFound, ["transport": "talky1"])
        queue.async { [weak self] in
            guard let self else { return }
            // Gia' collegati (magari e' stato lui a chiamare): niente doppione.
            guard self.connections[peer.id] == nil else { return }
            self.connect(to: peer)
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        resolvingServices.removeAll { $0 === sender }
        logger.logNetworkWarning("Cross-platform resolve failed: \(errorDict)")
    }
}

extension TalkyCrossPlatformManager: NetServiceBrowserDelegate {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        logger.logNetworkInfo("Cross-platform browser avviato")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        guard let peerID = serviceNameToPeerID.removeValue(forKey: service.name) else { return }
        DispatchQueue.main.async {
            self.peers.removeAll { $0.id == peerID }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        logger.logNetworkWarning("Cross-platform browser failed: \(errorDict)")
    }
}
