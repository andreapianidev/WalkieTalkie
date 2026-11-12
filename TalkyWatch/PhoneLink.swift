//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - PhoneLink.swift
//  TalkyWatch
//
//  L'altro capo di WristLink: dall'iPhone arrivano stazioni, preferite,
//  Talky Pro e stato del walkie; verso l'iPhone va il PTT. Il contesto
//  ricevuto lo conserva watchOS, quindi al riavvio le stazioni ci sono gia'
//  anche con l'iPhone lontano.

import Foundation
import WatchConnectivity

final class PhoneLink: NSObject, ObservableObject {
    static let shared = PhoneLink()

    @Published private(set) var stations: [WristStation] = []
    @Published private(set) var favorites: [WristStation] = []
    @Published private(set) var phonePro = false
    @Published private(set) var peers = 0
    @Published private(set) var channel = ""

    enum Push: Equatable {
        case sent(peers: Int)
        case phoneAway
    }

    func start() {
        #if DEBUG
        if ShotMode.on {
            stations = ShotMode.stations
            favorites = Array(stations.prefix(3))
            phonePro = true
            peers = 2
            return
        }
        #endif
        guard WCSession.isSupported(), WCSession.default.delegate == nil else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Premuto (true) o lasciato (false) il tasto PTT del Watch.
    func ptt(_ down: Bool) async -> Push {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return .phoneAway }
        return await withCheckedContinuation { cont in
            session.sendMessage([WristKey.ptt: down], replyHandler: { reply in
                cont.resume(returning: .sent(peers: reply[WristKey.peers] as? Int ?? 0))
            }, errorHandler: { _ in
                cont.resume(returning: .phoneAway)
            })
        }
    }

    private func apply(_ context: [String: Any]) {
        if let data = context[WristKey.catalog] as? Data,
           let list = try? JSONDecoder().decode([WristStation].self, from: data) {
            stations = list
        }
        let ids = context[WristKey.favorites] as? [Int] ?? []
        favorites = ids.compactMap { id in stations.first { $0.id == id } }
        phonePro = context[WristKey.pro] as? Bool ?? false
        peers = context[WristKey.peers] as? Int ?? 0
        channel = context[WristKey.channel] as? String ?? ""
    }
}

extension PhoneLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let saved = session.receivedApplicationContext
        Task { @MainActor in self.apply(saved) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        Task { @MainActor in self.apply(context) }
    }
}
