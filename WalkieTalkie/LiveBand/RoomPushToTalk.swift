//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - RoomPushToTalk.swift
//  Talky
//
//  Le stanze private con il Push to Talk di Apple (Talky Pro): la stanza
//  diventa un canale di sistema, con la pillola blu, i comandi sulla
//  schermata di blocco e la voce che arriva anche con Talky chiusa.
//
//  Come arriva la voce ad app chiusa: Talky lascia al custode del server
//  (scripts/server/talky_rooms.py) il gettone APNs del canale; quando
//  qualcuno comincia a parlare il custode manda una notifica pushtotalk,
//  iOS sveglia Talky, che rientra nella stanza su Mumble e suona. I primi
//  istanti del passaggio si perdono nel tempo del collegamento.

import AVFoundation
import Combine
import Foundation
import PushToTalk

@available(iOS 16.0, *)
final class RoomPushToTalk: NSObject {
    static let shared = RoomPushToTalk()

    /// Dopo una notifica, quanto si aspetta la voce vera prima di togliere
    /// "chi parla" dalla pillola: un remoto rimasto attivo non lascia trasmettere.
    private static let pushedSpeakerHold: Duration = .seconds(4)

    private var manager: PTChannelManager?
    private var creating = false
    private var joined: UUID?
    /// Richiesta di ingresso partita e non ancora confermata.
    private var joining: UUID?
    private var joinedRoom: TalkyRoom?
    private var pushToken: String?
    private var watchers: Set<AnyCancellable> = []
    private var live: LiveRadio { .shared }
    /// Il tasto in app e' premuto: un passaggio aperto dall'app quando il
    /// dito non c'e' piu' (risposta del sistema arrivata tardi) si richiude.
    private var appHolding = false
    /// La pillola mostra un partecipante remoto, messo da noi o dalla notifica.
    private var remoteShown = false
    private var speakerReset: Task<Void, Never>?

    /// Si e' dentro un canale di sistema: il tasto in app passa da qui.
    var isJoined: Bool { joined != nil }

    /// All'avvio dell'app, in didFinishLaunching: anche quando iOS rilancia
    /// Talky in background per una notifica, il sistema consegna la voce
    /// solo a un gestore gia' creato.
    func start() {
        guard manager == nil, !creating else { return }
        creating = true
        live.endSystemTransmission = { [weak self] in self?.endFromApp() }
        Task {
            manager = try? await PTChannelManager.channelManager(delegate: self, restorationDelegate: self)
            creating = false
            watch()
        }
    }

    // MARK: tasto in app

    func beginFromApp() {
        guard let manager, let joined else { return }
        appHolding = true
        manager.requestBeginTransmitting(channelUUID: joined)
    }

    /// Il dito si e' alzato dal tasto in app: se la richiesta era partita e il
    /// passaggio non e' ancora cominciato, la si ritira.
    func releaseAppPress() {
        guard appHolding else { return }
        endFromApp()
    }

    func endFromApp() {
        appHolding = false
        guard let manager, let joined else { return }
        manager.stopTransmitting(channelUUID: joined)
    }

    // MARK: seguire la stanza

    private func watch() {
        // Un attimo di pausa: joinRoom cambia stanza e banda una dopo
        // l'altra, e senza la pausa si uscirebbe e rientrerebbe nel canale.
        live.$room.combineLatest(live.$state, live.$band)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] room, state, band in
                self?.follow(room: band == .poc ? room : nil, online: state == .online)
            }
            .store(in: &watchers)
        live.$inRoom
            .receive(on: RunLoop.main)
            .sink { [weak self] inside in if inside { self?.register() } }
            .store(in: &watchers)
        live.$talker
            .receive(on: RunLoop.main)
            .sink { [weak self] talker in self?.showSpeaker(talker) }
            .store(in: &watchers)
    }

    private func follow(room: TalkyRoom?, online: Bool) {
        guard let manager else { return }
        guard let room, live.proGate() else {
            if let joined { manager.leaveChannel(channelUUID: joined) }
            return
        }
        let id = room.pushToTalkID
        if joined != id {
            guard joining != id else { return }
            if let joined { manager.leaveChannel(channelUUID: joined) }
            joining = id
            joinedRoom = room
            manager.requestJoinChannel(channelUUID: id, descriptor: Self.descriptor(room))
            return
        }
        Task { try? await manager.setServiceStatus(online ? .ready : .connecting, channelUUID: id) }
    }

    /// Il gettone al custode a ogni ingresso nella stanza: lo stato del
    /// custode puo' averlo perso (stanza tolta e rifatta, server rifatto).
    private func register() {
        guard let room = joinedRoom, let pushToken, live.room == room, live.inRoom else { return }
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        Task { _ = await live.registerPushToTalk(token: pushToken, environment: env) }
    }

    private func showSpeaker(_ talker: String?) {
        guard let manager, let joined else { return }
        if talker != nil { speakerReset?.cancel() }
        guard talker != nil || remoteShown else { return }
        remoteShown = talker != nil
        let who = talker.map { PTParticipant(name: $0, image: nil) }
        Task { try? await manager.setActiveRemoteParticipant(who, channelUUID: joined) }
    }

    /// La notifica ha messo un remoto nella pillola. Se la voce vera non
    /// arriva (passaggio gia' finito mentre ci si ricollegava), lo si toglie.
    private func clearPushedSpeaker(_ channelUUID: UUID) {
        remoteShown = true
        speakerReset?.cancel()
        speakerReset = Task { [weak self] in
            // Prima il collegamento, poi un attimo per la voce.
            for _ in 0 ..< 60 {
                guard let self, !Task.isCancelled else { return }
                if self.live.state == .online { break }
                try? await Task.sleep(for: .milliseconds(250))
            }
            try? await Task.sleep(for: Self.pushedSpeakerHold)
            guard let self, !Task.isCancelled, self.live.talker == nil, let manager = self.manager else { return }
            self.remoteShown = false
            try? await manager.setActiveRemoteParticipant(nil, channelUUID: channelUUID)
        }
    }

    nonisolated static func descriptor(_ room: TalkyRoom) -> PTChannelDescriptor {
        PTChannelDescriptor(name: "Talky " + room.display, image: nil)
    }
}

@available(iOS 16.0, *)
extension RoomPushToTalk: PTChannelManagerDelegate {
    nonisolated func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {
        Task { @MainActor in
            self.joined = channelUUID
            if self.joining == channelUUID { self.joining = nil }
            // Rilanciata da una notifica o dopo un riavvio: si rientra nella stanza.
            if self.live.room == nil, let last = self.live.lastRoom, last.pushToTalkID == channelUUID {
                self.joinedRoom = last
                self.live.joinRoom(last)
            }
            self.register()
        }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, failedToJoinChannel channelUUID: UUID, error: Error) {
        Task { @MainActor in
            if self.joining == channelUUID { self.joining = nil }
            self.joinedRoom = nil
        }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, didLeaveChannel channelUUID: UUID, reason: PTChannelLeaveReason) {
        Task { @MainActor in
            guard self.joined == channelUUID else { return }
            self.joined = nil
            self.joinedRoom = nil
            self.remoteShown = false
            self.speakerReset?.cancel()
            // Uscita dalla pillola di sistema: si esce anche dalla stanza.
            if reason == .userRequest, self.live.room != nil { self.live.leaveRoom() }
        }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
        Task { @MainActor in
            // Chiesto dal tasto in app, ma il dito si e' gia' alzato.
            if source == .developerRequest, !self.appHolding {
                channelManager.stopTransmitting(channelUUID: channelUUID)
                return
            }
            self.live.startTalking(bySystem: true)
        }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
        Task { @MainActor in
            self.appHolding = false
            self.live.stopTalking()
        }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, failedToBeginTransmittingInChannel channelUUID: UUID, error: Error) {
        Task { @MainActor in self.appHolding = false }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {
        let hex = pushToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            self.pushToken = hex
            self.register()
        }
    }

    nonisolated func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String: Any]) -> PTPushResult {
        let speaker = (pushPayload["activeSpeaker"] as? String) ?? "Talky"
        Task { @MainActor in
            // Talky era chiusa o lontana dalla stanza: ci si ricollega per sentire.
            if let last = self.live.lastRoom, last.pushToTalkID == channelUUID,
               self.live.room != last || self.live.band != .poc {
                self.live.joinRoom(last)
            } else if self.live.room != nil, !self.live.isOn {
                self.live.start(.poc)
            }
            self.clearPushedSpeaker(channelUUID)
        }
        return .activeRemoteParticipant(PTParticipant(name: speaker, image: nil))
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, didActivate audioSession: AVAudioSession) {
        Task { @MainActor in self.live.systemAudioActivated() }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, didDeactivate audioSession: AVAudioSession) {
        Task { @MainActor in self.live.systemAudioDeactivated() }
    }
}

@available(iOS 16.0, *)
extension RoomPushToTalk: PTChannelRestorationDelegate {
    nonisolated func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor {
        let room = UserDefaults.standard.string(forKey: "mumble_last_room").flatMap(TalkyRoom.init(code:))
        return room.map(Self.descriptor) ?? PTChannelDescriptor(name: "Talky", image: nil)
    }
}
