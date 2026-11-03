//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - StreamTap.swift
//  Talky (iOS e Mac)
//
//  Il player della radio (AVPlayer) non da' i campioni degli stream dal vivo:
//  il tap di MediaToolbox sugli stream Icecast e HLS non riceve niente
//  (misurato il 03/11/2026 su 20 stazioni, funziona solo sui file). Per
//  disegnare quello che si sente si legge lo stesso stream una seconda volta
//  e lo si decodifica con CompressedAudioStream. Gira solo mentre la radio
//  suona con l'app in primo piano: in background non consuma dati.

import AudioToolbox
import Foundation

nonisolated final class StreamTap: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let url: URL
    private let bands: SoundBands
    private let queue = OperationQueue()
    private var session: URLSession?
    private var decoder: CompressedAudioStream?
    /// Il decoder lo usano il thread della rete e quello degli HLS.
    private let lock = NSLock()
    private var hlsTask: Task<Void, Never>?
    private var demux = TransportStreamAudio()

    init(url: URL, bands: SoundBands) {
        self.url = url
        self.bands = bands
        queue.maxConcurrentOperationCount = 1
        super.init()
    }

    var isHLS: Bool {
        let s = url.absoluteString.lowercased()
        return s.contains(".m3u8") || s.contains("/playlist")
    }

    func start() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["User-Agent": "Talky", "Icy-MetaData": "0"]
        let session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
        self.session = session
        if isHLS {
            hlsTask = Task { [weak self] in await self?.followPlaylist(session) }
        } else {
            session.dataTask(with: url).resume()
        }
    }

    func stop() {
        hlsTask?.cancel()
        hlsTask = nil
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: stream continui (Icecast, Shoutcast)

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Una pagina HTML (blocco per paese, errore del server) non e' audio.
        guard dataTask.originalRequest?.url == url, Self.isAudio(response.mimeType) else {
            completionHandler(dataTask.originalRequest?.url == url ? .cancel : .allow)
            return
        }
        lock.lock()
        decoder = CompressedAudioStream(type: Self.fileType(mime: response.mimeType, url: response.url ?? url))
        lock.unlock()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard dataTask.originalRequest?.url == url else { return }
        feed(data)
    }

    private func feed(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard let decoder else { return }
        let samples = decoder.decode(data)
        if !samples.isEmpty { bands.ingest(samples, rate: decoder.sampleRate) }
    }

    static func isAudio(_ mime: String?) -> Bool {
        guard let m = mime?.lowercased() else { return true }
        return !(m.hasPrefix("text/") || m.contains("html") || m.contains("json") || m.contains("xml"))
    }

    static func fileType(mime: String?, url: URL) -> AudioFileTypeID {
        let m = (mime ?? "").lowercased()
        let path = url.path.lowercased()
        if m.contains("aac") || m.contains("mp4a") || path.hasSuffix(".aac") || path.contains("aac") { return kAudioFileAAC_ADTSType }
        return kAudioFileMP3Type
    }

    // MARK: HLS

    /// Si scaricano i segmenti come fa il player: dal terzo dalla fine in poi,
    /// che e' dove AVPlayer comincia a suonare un HLS dal vivo.
    private func followPlaylist(_ session: URLSession) async {
        guard var media = await mediaPlaylist(session, url) else { return }
        var done = Set<String>()
        var first = true
        while !Task.isCancelled {
            guard let (text, base) = await fetchText(session, media) else {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                continue
            }
            let segments = Self.segments(text, base: base)
            let start = first ? max(0, segments.count - 3) : 0
            first = false
            for segment in segments[start...] where !done.contains(segment.absoluteString) {
                guard !Task.isCancelled else { return }
                done.insert(segment.absoluteString)
                guard let (data, response) = try? await session.data(from: segment) else { continue }
                decodeSegment(data, mime: response.mimeType, url: segment)
            }
            if done.count > 200 { done = Set(segments.map(\.absoluteString)) }
            let target = Self.targetDuration(text)
            try? await Task.sleep(nanoseconds: UInt64(max(2, target / 2) * 1_000_000_000))
            media = base
        }
    }

    private func decodeSegment(_ data: Data, mime: String?, url: URL) {
        guard Self.isAudio(mime) || mime?.contains("mp2t") == true else { return }
        let bytes = [UInt8](data.prefix(4))
        let payload: Data
        let type: AudioFileTypeID
        if bytes.first == 0x47 {
            // MPEG-TS: si tiene solo l'audio (ADTS o MP3) dei pacchetti PES.
            payload = demux.audio(from: data)
            type = demux.isMP3 ? kAudioFileMP3Type : kAudioFileAAC_ADTSType
        } else {
            payload = data
            type = Self.fileType(mime: mime, url: url)
        }
        lock.lock()
        if decoder == nil { decoder = CompressedAudioStream(type: type) }
        lock.unlock()
        feed(payload)
    }

    /// Una playlist master porta alle varianti: si prende la prima.
    private func mediaPlaylist(_ session: URLSession, _ url: URL) async -> URL? {
        guard let (text, base) = await fetchText(session, url) else { return nil }
        guard text.contains("#EXT-X-STREAM-INF") else { return base }
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let first = lines.first(where: { !$0.hasPrefix("#") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return nil }
        return URL(string: first, relativeTo: base)?.absoluteURL
    }

    private func fetchText(_ session: URLSession, _ url: URL) async -> (String, URL)? {
        guard let (data, response) = try? await session.data(from: url) else { return nil }
        return (String(decoding: data, as: UTF8.self), response.url ?? url)
    }

    static func segments(_ text: String, base: URL) -> [URL] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .compactMap { URL(string: $0, relativeTo: base)?.absoluteURL }
    }

    static func targetDuration(_ text: String) -> Double {
        for line in text.split(whereSeparator: \.isNewline) where line.hasPrefix("#EXT-X-TARGETDURATION:") {
            return Double(line.dropFirst("#EXT-X-TARGETDURATION:".count)) ?? 6
        }
        return 6
    }
}

/// Estrae l'audio dai pacchetti MPEG-TS di un segmento HLS: il PID con i PES
/// audio (stream id da 0xC0 a 0xDF), senza le intestazioni PES.
nonisolated struct TransportStreamAudio {
    private var audioPID: Int?
    private(set) var isMP3 = false

    mutating func audio(from data: Data) -> Data {
        var out = Data()
        let bytes = [UInt8](data)
        var i = 0
        while i + 188 <= bytes.count {
            defer { i += 188 }
            guard bytes[i] == 0x47 else {
                // Fuori passo: si cerca il prossimo byte di sincronia.
                i -= 187
                continue
            }
            let pid = Int(bytes[i + 1] & 0x1F) << 8 | Int(bytes[i + 2])
            let start = bytes[i + 1] & 0x40 != 0
            let adaptation = (bytes[i + 3] >> 4) & 0x3
            var p = i + 4
            if adaptation == 2 { continue }
            if adaptation == 3 { p += 1 + Int(bytes[i + 4]) }
            guard p < i + 188 else { continue }
            if start, p + 9 <= i + 188, bytes[p] == 0, bytes[p + 1] == 0, bytes[p + 2] == 1 {
                let streamID = bytes[p + 3]
                guard (0xC0 ... 0xDF).contains(streamID) else { continue }
                if audioPID == nil { audioPID = pid }
                guard pid == audioPID else { continue }
                p += 9 + Int(bytes[p + 8])
                guard p < i + 188 else { continue }
                if out.isEmpty, p + 1 < i + 188 {
                    // ADTS ha 0xFFF1/0xFFF9; MP3 0xFFFB/0xFFF3/0xFFE3.
                    isMP3 = bytes[p] == 0xFF && (bytes[p + 1] & 0x06) != 0
                }
                out.append(contentsOf: bytes[p ..< i + 188])
            } else if pid == audioPID {
                out.append(contentsOf: bytes[p ..< i + 188])
            }
        }
        return out
    }
}
