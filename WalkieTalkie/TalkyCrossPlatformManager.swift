//creato da Andrea Piani - Immaginet Srl - 13/06/26 - https://www.andreapiani.com - TalkyCrossPlatformManager.swift

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
    private let uid = UUID().uuidString
    private let deviceName = UIDevice.current.name

    private var listener: NWListener?
    private var netService: NetService?
    private var browser: NetServiceBrowser?
    private var resolvingServices: [NetService] = []
    private var started = false
    private var connections: [String: NWConnection] = [:]

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
            guard let self else { return }
            self.listener?.cancel()
            self.listener = nil
            self.netService?.stop()
            self.netService = nil
            self.browser?.stop()
            self.browser = nil
            self.resolvingServices.removeAll()
            self.connections.values.forEach { $0.cancel() }
            self.connections.removeAll()
            self.publishConnectionCount()
            self.started = false
            self.setStatus("Cross-platform stopped")
        }
    }

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

            self.logger.logAudioInfo("Cross-platform audio inviato: \(pcm16.count) bytes")
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
        service.publish()
        netService = service
        logger.logNetworkInfo("Cross-platform Bonjour pubblicato su porta \(port)")
    }

    private func startBrowsing() {
        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: Constant.serviceType, inDomain: Constant.serviceDomain)
        self.browser = browser
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

        let floatPCM = convertPCM16LEToFloat32(payload)
        guard !floatPCM.isEmpty else { return }
        audioManager.playReceivedAudio(floatPCM)
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
            connections[peer.id] = connection
            publishConnectionCount()
            upsert(peer)
            logger.logNetworkInfo("Cross-platform HELLO ricevuto da \(peer.name)")
        case "HEARTBEAT":
            break
        case "AUDIO_META":
            logger.logAudioInfo("Cross-platform audio in arrivo")
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
        let removedIDs = connections.compactMap { id, storedConnection in
            storedConnection === connection ? id : nil
        }
        guard !removedIDs.isEmpty else { return }

        for id in removedIDs {
            connections.removeValue(forKey: id)
        }
        publishConnectionCount()

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
        upsert(peer)
        connect(to: peer)
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
        DispatchQueue.main.async {
            self.peers.removeAll { $0.name == service.name }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        logger.logNetworkWarning("Cross-platform browser failed: \(errorDict)")
    }
}
