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

    private var manager: PTChannelManager?
    private var joined: UUID?
    private var joinedRoom: TalkyRoom?
    private var pushToken: String?
    private var registeredFor: String?
    private var watchers: Set<AnyCancellable> = []
    private var live: LiveRadio { .shared }

    /// Si e' dentro un canale di sistema: il tasto in app passa da qui.
    var isJoined: Bool { joined != nil }

    /// All'avvio, anche quando iOS rilancia Talky per una notifica: il
    /// gestore va creato subito perche' il sistema gli consegni la voce.
    func start() {
        guard manager == nil else { return }
        Task {
            manager = try? await PTChannelManager.channelManager(delegate: self, restorationDelegate: self)
            watch()
        }
    }

    // MARK: tasto in app

    func beginFromApp() {
        guard let manager, let joined else { return }
        manager.requestBeginTransmitting(channelUUID: joined)
    }

    func endFromApp() {
        guard let manager, let joined else { return }
        manager.stopTransmitting(channelUUID: joined)
    }

    // MARK: seguire la stanza

    private func watch() {
        live.$room.combineLatest(live.$state)
            .receive(on: RunLoop.main)
            .sink { [weak self] room, state in self?.follow(room: room, online: state == .online) }
            .store(in: &watchers)
        live.$talker.removeDuplicates()
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
        let id = Self.channelUUID(room)
        if joined != id {
            if let joined { manager.leaveChannel(channelUUID: joined) }
            joinedRoom = room
            manager.requestJoinChannel(channelUUID: id, descriptor: Self.descriptor(room))
            return
        }
        Task { try? await manager.setServiceStatus(online ? .ready : .connecting, channelUUID: id) }
        if online { register() }
    }

    /// Il gettone va al custode una volta per stanza e collegamento.
    private func register() {
        guard let room = joinedRoom, let pushToken, live.room == room, live.state == .online else { return }
        let key = room.code + pushToken
        guard registeredFor != key else { return }
        registeredFor = key
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        live.tellKeeper("ptt \(room.channelName) \(room.token) \(pushToken) \(env) \(MumbleManners.nickname)")
    }

    private func showSpeaker(_ talker: String?) {
        guard let manager, let joined else { return }
        let who = talker.map { PTParticipant(name: $0, image: nil) }
        Task { try? await manager.setActiveRemoteParticipant(who, channelUUID: joined) }
    }

    nonisolated static func channelUUID(_ room: TalkyRoom) -> UUID {
        // Lo stesso canale per la stessa stanza su ogni telefono e a ogni avvio.
        var b = Array(room.channelName.utf8.suffix(16))
        while b.count < 16 { b.append(0) }
        b[6] = (b[6] & 0x0F) | 0x40
        b[8] = (b[8] & 0x3F) | 0x80
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
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
            // Rilanciata da una notifica o dopo un riavvio: si rientra nella stanza.
            if self.live.room == nil, let last = self.live.lastRoom, Self.channelUUID(last) == channelUUID {
                self.joinedRoom = last
                self.live.joinRoom(last)
            }
            self.register()
        }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, didLeaveChannel channelUUID: UUID, reason: PTChannelLeaveReason) {
        Task { @MainActor in
            guard self.joined == channelUUID else { return }
            self.joined = nil
            self.joinedRoom = nil
            self.registeredFor = nil
            // Uscita dalla pillola di sistema: si esce anche dalla stanza.
            if reason == .userRequest, self.live.room != nil { self.live.leaveRoom() }
        }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
        Task { @MainActor in self.live.startTalking(waitForSession: true) }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
        Task { @MainActor in self.live.stopTalking() }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {
        let hex = pushToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            self.pushToken = hex
            self.registeredFor = nil
            self.register()
        }
    }

    nonisolated func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String: Any]) -> PTPushResult {
        let speaker = (pushPayload["activeSpeaker"] as? String) ?? "Talky"
        Task { @MainActor in
            // Talky era chiusa o lontana dalla stanza: ci si ricollega per sentire.
            if self.live.room == nil, let last = self.live.lastRoom, Self.channelUUID(last) == channelUUID {
                self.live.joinRoom(last)
            } else if self.live.room != nil, !self.live.isOn {
                self.live.start(.poc)
            }
        }
        return .activeRemoteParticipant(PTParticipant(name: speaker, image: nil))
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, didActivate audioSession: AVAudioSession) {
        Task { @MainActor in self.live.micReady() }
    }

    nonisolated func channelManager(_ channelManager: PTChannelManager, didDeactivate audioSession: AVAudioSession) {}
}

@available(iOS 16.0, *)
extension RoomPushToTalk: PTChannelRestorationDelegate {
    nonisolated func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor {
        let room = UserDefaults.standard.string(forKey: "mumble_last_room").flatMap(TalkyRoom.init(code:))
        return room.map(Self.descriptor) ?? PTChannelDescriptor(name: "Talky", image: nil)
    }
}
