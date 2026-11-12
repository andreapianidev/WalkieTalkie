//creato da Andrea Piani - 16/10/26 - https://www.andreapiani.com - LiveLinks.swift
//  Talky
//
//  Trasporti su Network.framework: WebSocket in chiaro verso i KiwiSDR
//  (indirizzi qualsiasi, che URLSession rifiuterebbe per ATS) e TLS verso
//  i server Mumble. Portati da RadioKit di Etere.

import Foundation
import Network

/// WebSocket su Network.framework, per i KiwiSDR pubblici.
@available(iOS 16.0, macOS 13.0, *)
nonisolated final class WebSocketLink: @unchecked Sendable {
    enum Message: Sendable {
        case text(String)
        case data(Data)
    }

    let messages: AsyncThrowingStream<Message, Error>
    private let sink: AsyncThrowingStream<Message, Error>.Continuation
    private let connection: NWConnection
    private let queue: DispatchQueue

    init(url: URL) {
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        ws.maximumMessageSize = 4 << 20
        let params: NWParameters = url.scheme == "wss" ? .tls : .tcp
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)
        connection = NWConnection(to: .url(url), using: params)
        queue = DispatchQueue(label: "ws \(url.host ?? "")")
        (messages, sink) = AsyncThrowingStream.makeStream(of: Message.self)
    }

    /// Ritorna a handshake concluso.
    func open(timeout: Duration = .seconds(10)) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let once = Once(cont)
            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    once.resume()
                    self?.receive()
                case .failed(let e):
                    once.fail(e)
                    self?.sink.finish(throwing: e)
                case .waiting(let e):
                    once.fail(e)
                case .cancelled:
                    once.fail(LinkError.closed(.closed))
                    self?.sink.finish()
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout.seconds) { once.fail(LinkError.timeout) }
        }
    }

    func send(_ text: String) {
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let ctx = NWConnection.ContentContext(identifier: "text", metadata: [meta])
        connection.send(content: Data(text.utf8), contentContext: ctx, isComplete: true, completion: .idempotent)
    }

    func close() {
        connection.cancel()
        sink.finish()
    }

    private func receive() {
        connection.receiveMessage { [weak self] content, context, _, error in
            guard let self else { return }
            if let error {
                sink.finish(throwing: error)
                return
            }
            let meta = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            switch meta?.opcode {
            case .text:
                if let content, let s = String(data: content, encoding: .utf8) { sink.yield(.text(s)) }
            case .binary:
                if let content { sink.yield(.data(content)) }
            case .close:
                sink.finish(throwing: LinkError.closed(.closed))
                return
            default:
                break
            }
            receive()
        }
    }
}

/// Flusso TLS per il canale di controllo Mumble. I server pubblici hanno quasi
/// tutti certificati autofirmati: si accettano come sono, la stessa scelta che
/// il client ufficiale propone alla prima connessione.
@available(iOS 16.0, macOS 13.0, *)
nonisolated final class StreamLink: @unchecked Sendable {
    let bytes: AsyncThrowingStream<Data, Error>
    private let sink: AsyncThrowingStream<Data, Error>.Continuation
    private let connection: NWConnection
    private let queue: DispatchQueue

    init(host: String, port: UInt16) {
        let tls = NWProtocolTLS.Options()
        let sec = tls.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(sec, .TLSv12)
        sec_protocol_options_set_verify_block(sec, { _, _, done in done(true) }, .global())
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 64738,
                                  using: NWParameters(tls: tls, tcp: tcp))
        queue = DispatchQueue(label: "tls \(host)", qos: .userInitiated)
        (bytes, sink) = AsyncThrowingStream.makeStream(of: Data.self)
    }

    func open(timeout: Duration = .seconds(10)) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let once = Once(cont)
            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    once.resume()
                    self?.receive()
                case .failed(let e):
                    once.fail(e)
                    self?.sink.finish(throwing: e)
                case .waiting(let e):
                    once.fail(e)
                case .cancelled:
                    once.fail(LinkError.closed(.closed))
                    self?.sink.finish()
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout.seconds) { once.fail(LinkError.timeout) }
        }
    }

    func send(_ data: Data) {
        connection.send(content: data, completion: .idempotent)
    }

    func close() {
        connection.cancel()
        sink.finish()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, complete, error in
            guard let self else { return }
            if let content, !content.isEmpty { sink.yield(content) }
            if let error {
                sink.finish(throwing: error)
                return
            }
            if complete {
                sink.finish(throwing: LinkError.closed(.closed))
                return
            }
            receive()
        }
    }
}

/// Riprende una continuation una volta sola, qualunque callback arrivi prima.
nonisolated private final class Once: @unchecked Sendable {
    private var cont: CheckedContinuation<Void, Error>?
    private let lock = NSLock()

    init(_ cont: CheckedContinuation<Void, Error>) { self.cont = cont }

    func resume() { take()?.resume() }
    func fail(_ e: Error) { take()?.resume(throwing: e) }

    private func take() -> CheckedContinuation<Void, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let c = cont
        cont = nil
        return c
    }
}

@available(iOS 16.0, macOS 13.0, *)
nonisolated extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

/// Dove risponde davvero un KiwiSDR. Quelli dietro il proxy di kiwisdr.com
/// (`nome.proxy.kiwisdr.com:8073`) rispondono "307" verso `proxy2`, e il
/// WebSocket di Network.framework non segue i rimandi: senza questo passaggio
/// la connessione scade dopo dieci secondi e si passa a un ricevitore piu'
/// lontano. Si fa la stessa richiesta di apertura e si legge solo l'intestazione.
@available(iOS 16.0, macOS 13.0, *)
nonisolated enum KiwiAddress {
    static func resolve(host: String, port: Int, path: String) async -> (String, Int) {
        var host = host, port = port
        for _ in 0 ..< 3 {
            guard let head = await header(host: host, port: port, path: path),
                  let status = head.split(separator: " ").dropFirst().first.flatMap({ Int($0) }),
                  [301, 302, 307, 308].contains(status) else { break }
            guard let line = head.split(separator: "\r\n").first(where: { $0.lowercased().hasPrefix("location:") }),
                  let url = URL(string: line.dropFirst("location:".count).trimmingCharacters(in: .whitespaces)),
                  let next = url.host else { break }
            host = next
            port = url.port ?? 80
        }
        return (host, port)
    }

    private static func header(host: String, port: Int, path: String) async -> String? {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else { return nil }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let queue = DispatchQueue(label: "kiwi resolve \(host)")
        let request = "GET \(path) HTTP/1.1\r\nHost: \(host):\(port)\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n"
            + "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGFsa3lyZXNvbHZlMDAwMQ==\r\n\r\n"
        let text: String? = await withCheckedContinuation { cont in
            let once = OnceValue<String?>(cont)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: Data(request.utf8), completion: .contentProcessed { _ in })
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                        once.resume(data.map { String(decoding: $0, as: UTF8.self) })
                    }
                case .failed, .waiting, .cancelled:
                    once.resume(nil)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 5) { once.resume(nil) }
        }
        connection.cancel()
        return text
    }
}

/// Quante persone ha collegate un server Mumble, chiesto con il ping UDP
/// senza connessione: lo stesso che usa l'elenco dei server del client
/// ufficiale. Nessun accesso e nessuna sessione, quindi sul server non
/// compare nessuno che entra ed esce (issue #12). Un server che ha spento
/// il ping non risponde, e resta fuori dalla lista.
@available(iOS 16.0, macOS 13.0, *)
nonisolated enum MumblePing {
    /// Richiesta: 4 byte a zero e 8 di identificativo. Risposta: versione (4),
    /// lo stesso identificativo (8), utenti (4), massimo (4), banda (4).
    static func users(on server: MumbleServer, timeout: Duration = .seconds(3)) async -> Int? {
        guard let port = NWEndpoint.Port(rawValue: server.port) else { return nil }
        let connection = NWConnection(host: NWEndpoint.Host(server.host), port: port, using: .udp)
        let queue = DispatchQueue(label: "mumble ping \(server.host)")
        let ident = (0 ..< 8).map { _ in UInt8.random(in: 0 ... 255) }
        let request = Data([0, 0, 0, 0] + ident)
        let reply: Data? = await withCheckedContinuation { cont in
            let once = OnceValue<Data?>(cont)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: request, completion: .contentProcessed { _ in })
                    connection.receiveMessage { data, _, _, _ in once.resume(data) }
                case .failed, .waiting, .cancelled:
                    once.resume(nil)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout.seconds) { once.resume(nil) }
        }
        connection.cancel()
        guard let reply else { return nil }
        let b = [UInt8](reply)
        guard b.count >= 24, Array(b[4 ..< 12]) == ident else { return nil }
        let users = b[12 ..< 16].reduce(0) { $0 << 8 | Int($1) }
        return users <= 100_000 ? users : nil
    }
}

/// Come Once, per una continuazione che restituisce un valore.
nonisolated final class OnceValue<T: Sendable>: @unchecked Sendable {
    private var cont: CheckedContinuation<T, Never>?
    private let lock = NSLock()

    init(_ cont: CheckedContinuation<T, Never>) { self.cont = cont }

    func resume(_ value: T) {
        lock.lock()
        let c = cont
        cont = nil
        lock.unlock()
        c?.resume(returning: value)
    }
}

