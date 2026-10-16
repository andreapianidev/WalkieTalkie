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
