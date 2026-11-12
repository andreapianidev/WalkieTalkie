//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - WristLink.swift
//  Talky
//
//  Il filo fra Talky sull'iPhone e Talky sull'Apple Watch (issue #11).
//  Al Watch va quello che da solo non sa: le stazioni con i loro stream, le
//  preferite, Talky Pro e lo stato del walkie. Dal Watch arriva il PTT:
//  tenuto premuto sul polso, l'iPhone trasmette con il suo microfono.

import Combine
import Foundation
import OSLog
import WatchConnectivity

final class WristLink: NSObject {
    static let shared = WristLink()

    /// Il Watch chiede di trasmettere (`object` true) o di smettere (false).
    /// La raccoglie ContentView, che ha il walkie e i suoi controlli.
    static let pttRequest = Notification.Name("talky.wrist.ptt")

    private let log = os.Logger(subsystem: "com.Andrea-Piani.WalkieTalkie", category: "wrist")
    private var bag: Set<AnyCancellable> = []
    private var peers = 0
    private var channel = ""
    /// L'ultimo contesto mandato: all'avvio push() arriva da piu' parti
    /// (attivazione, stato del Watch, walkie, preferite, Pro) e senza questo
    /// si rimandavano 19 KB uguali cinque volte in due secondi.
    private var sent: Snapshot?

    private struct Snapshot: Equatable {
        let catalog: Data
        let favorites: [Int]
        let pro: Bool
        let peers: Int
        let channel: String
    }

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func start() {
        guard let session, session.delegate == nil else { return }
        session.delegate = self
        session.activate()
        // receive(on:) perche' @Published avvisa prima di cambiare il valore.
        RadioManager.shared.$favoriteStationIds.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.push() }.store(in: &bag)
        IAPManager.shared.$isProUser.dropFirst().removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.push() }.store(in: &bag)
    }

    /// Dal walkie: quanti sono collegati e su che canale.
    func walkie(peers: Int, channel: String) {
        guard peers != self.peers || channel != self.channel else { return }
        self.peers = peers
        self.channel = channel
        push()
    }

    /// Il contesto sostituisce il precedente: al Watch arriva sempre l'ultimo,
    /// anche se in quel momento e' spento.
    private func push() {
        guard let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled else {
            log.notice("Watch non pronto: niente contesto")
            return
        }
        let radio = RadioManager.shared
        let stations = radio.radioStations.map {
            WristStation(id: $0.id, name: $0.name, flag: $0.flagEmoji, place: $0.countryName,
                         dial: $0.displayLabel, url: $0.streamURL, isPro: $0.isPro)
        }
        guard let catalog = try? JSONEncoder().encode(stations) else { return }
        let favorites = radio.radioStations.map(\.id).filter { radio.favoriteStationIds.contains($0) }
        let now = Snapshot(catalog: catalog, favorites: favorites, pro: IAPManager.shared.isProUser,
                           peers: peers, channel: channel)
        guard now != sent else { return }
        do {
            try session.updateApplicationContext([
                WristKey.catalog: now.catalog,
                WristKey.favorites: now.favorites,
                WristKey.pro: now.pro,
                WristKey.peers: now.peers,
                WristKey.channel: now.channel,
            ])
            sent = now
            log.notice("al Watch \(stations.count) stazioni, \(favorites.count) preferite, \(now.peers) collegati")
        } catch {
            log.error("contesto al Watch non mandato: \(error.localizedDescription)")
        }
    }
}

extension WristLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.push() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Cambio di Watch: si riattiva per quello nuovo.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard let down = message[WristKey.ptt] as? Bool else {
            replyHandler([:])
            return
        }
        Task { @MainActor in
            self.log.notice("PTT dal Watch: \(down ? "premuto" : "lasciato")")
            NotificationCenter.default.post(name: Self.pttRequest, object: down)
            replyHandler([WristKey.peers: self.peers])
        }
    }
}
