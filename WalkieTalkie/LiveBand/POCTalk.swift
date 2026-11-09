//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - POCTalk.swift
//  Talky
//
//  Parlare sui canali POC: il tasto da tenere premuto, le regole da
//  accettare la prima volta con il nome che vedono gli altri, e il menu per
//  silenziare o segnalare chi sta parlando. Dove il server non lascia
//  parlare chi entra senza registrarsi, il tasto non c'e' e lo si dice.

import SwiftUI

@available(iOS 16.0, *)
struct POCTalkControls: View {
    @ObservedObject var live = LiveRadio.shared
    let compact: Bool
    @State private var showRules = false
    @State private var report: (server: String, reason: String)?

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            if live.state == .online {
                if live.canTalk {
                    POCTalkButton(talking: live.isTalking, compact: compact, onPress: pressBegan, onRelease: pressEnded)
                } else {
                    Label("mumble_listen_only".localized, systemImage: "ear")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if live.micDenied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Label("mumble_mic_denied".localized, systemImage: "mic.slash")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
                HStack(spacing: 14) {
                    if let room = live.room { POCRoomBadge(room: room) }
                    moderationMenu
                }
            }
        }
        .sheet(isPresented: $showRules) { POCRulesSheet() }
        .alert("mumble_report_done".localized,
               isPresented: Binding(get: { report != nil }, set: { if !$0 { report = nil } }),
               presenting: report) { sent in
            Button("mumble_report_mail".localized) {
                if let url = MumbleManners.reportMail(server: sent.server, reason: sent.reason) {
                    UIApplication.shared.open(url)
                }
            }
            Button("ok".localized, role: .cancel) {}
        }
    }

    private var throughPushToTalk: Bool { live.room != nil && RoomPushToTalk.shared.isJoined }

    private func pressBegan() {
        guard MumbleManners.rulesAccepted else {
            showRules = true
            return
        }
        guard !live.isTalking else { return }
        if throughPushToTalk {
            RoomPushToTalk.shared.beginFromApp()
        } else {
            live.startTalking()
        }
    }

    /// Anche quando il gesto viene annullato (tasto sparito, scorrimento,
    /// avviso di sistema, app in background): il microfono non resta acceso.
    private func pressEnded() {
        live.stopTalking()
        RoomPushToTalk.shared.releaseAppPress()
    }

    /// Sempre raggiungibile mentre si e' in un canale, stanze comprese: Apple
    /// vuole che chi e' disturbato possa silenziare e segnalare senza cercare.
    /// Nella stanza, che e' su un server di Talky, la segnalazione di un
    /// server non c'entra: restano silenzia e regole.
    private var moderationMenu: some View {
        Menu {
            if let talker = live.talker {
                Button {
                    live.muteTalker()
                } label: {
                    Label(String(format: "mumble_mute_user".localized, talker), systemImage: "speaker.slash")
                }
            }
            if live.room == nil {
                Section("mumble_report".localized) {
                    ForEach(["abuse", "sexual", "spam"], id: \.self) { reason in
                        Button(role: .destructive) {
                            let server = live.currentPOC?.server.id ?? ""
                            live.reportCurrent(reason: reason)
                            report = (server, reason)
                        } label: {
                            Text("mumble_report_reason_\(reason)".localized)
                        }
                    }
                }
            }
            Button {
                showRules = true
            } label: {
                Label("mumble_rules_title".localized, systemImage: "person.text.rectangle")
            }
        } label: {
            Label("mumble_safety".localized, systemImage: "hand.raised")
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
}

/// Il tasto da tenere premuto. Lo stato del dito vive qui e non nella vista
/// che lo contiene: se il tasto sparisce a meta' pressione si riparte puliti,
/// e un gesto annullato chiude il passaggio invece di lasciarlo aperto.
@available(iOS 16.0, *)
private struct POCTalkButton: View {
    let talking: Bool
    let compact: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    @GestureState private var held = false
    @State private var pressed = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let size: CGFloat = compact ? 64 : 84
        ZStack {
            Circle()
                .fill(talking ? Color.red : Color.black)
                .frame(width: size, height: size)
            Circle()
                .fill(Color.white)
                .frame(width: size - 12, height: size - 12)
            Image(systemName: talking ? "waveform" : "mic.fill")
                .font(.system(size: compact ? 20 : 26, weight: .bold))
                .foregroundColor(talking ? .red : .black)
        }
        .contentShape(Circle())
        // Prima dello scorrimento: lo ScrollView di FitOrScroll non si prende il dito.
        .highPriorityGesture(
            DragGesture(minimumDistance: 0).updating($held) { _, state, _ in state = true }
        )
        .onChange(of: held) { isHeld in
            if isHeld {
                pressed = true
                onPress()
            } else {
                release()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { release() }
        }
        .onDisappear(perform: release)
        .overlay(alignment: .bottom) {
            Text((talking ? "mumble_talking" : "mumble_hold_to_talk").localized)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(talking ? .red : .secondary)
                .fixedSize()
                .offset(y: compact ? 16 : 20)
        }
        .padding(.bottom, compact ? 14 : 18)
        .accessibilityLabel("mumble_hold_to_talk".localized)
        .accessibilityAddTraits(.isButton)
    }

    private func release() {
        guard pressed else { return }
        pressed = false
        onRelease()
    }
}

/// Le regole del POC e il nome nei canali. Si accettano una volta.
@available(iOS 16.0, *)
struct POCRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = MumbleManners.nickname

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("mumble_rules_body".localized)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section("mumble_rules_name".localized) {
                    TextField("Talky-1234", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("mumble_rules_accept".localized) {
                        MumbleManners.nickname = nickname
                        MumbleManners.rulesAccepted = true
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("mumble_rules_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Le stanze private nella lista del POC: aprirne una, entrare con un
/// codice, rientrare nell'ultima, invitare.
@available(iOS 16.0, *)
struct POCRoomsSection: View {
    @ObservedObject var live = LiveRadio.shared
    let done: () -> Void
    @State private var typed = ""
    @State private var wrong = false

    var body: some View {
        Section {
            if let room = live.room {
                HStack {
                    Label(room.display, systemImage: "lock.fill")
                        .font(.body.monospaced())
                    Spacer()
                    ShareLink(item: POCRoomInvite.text(room)) {
                        Label("room_invite".localized, systemImage: "square.and.arrow.up")
                    }
                }
                Button("room_leave".localized, role: .destructive) { live.leaveRoom() }
            } else {
                Button {
                    // Senza Pro chiude la lista: la proposta compare sulla schermata.
                    live.createRoom()
                    done()
                } label: {
                    Label("room_create".localized, systemImage: "plus.circle")
                }
                HStack {
                    TextField("K7P2-QX9A", text: $typed)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .onSubmit(join)
                    Button("room_join".localized, action: join)
                        .disabled(typed.isEmpty)
                }
                if let last = live.lastRoom {
                    Button(String(format: "room_rejoin".localized, last.display)) {
                        live.joinRoom(last)
                        done()
                    }
                }
            }
        } header: {
            Text("room_header".localized)
        } footer: {
            Text((wrong ? "room_code_wrong" : "room_footer").localized)
                .foregroundColor(wrong ? .red : .secondary)
        }
    }

    private func join() {
        guard let room = TalkyRoom(code: typed) else {
            wrong = true
            return
        }
        wrong = false
        live.joinRoom(room)
        done()
    }
}

/// La riga della stanza sotto il tasto per parlare: codice e invito a portata.
@available(iOS 16.0, *)
struct POCRoomBadge: View {
    let room: TalkyRoom

    var body: some View {
        HStack(spacing: 10) {
            Label(room.display, systemImage: "lock.fill")
                .font(.caption.monospaced())
            ShareLink(item: POCRoomInvite.text(room)) {
                Label("room_invite".localized, systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
        }
        .foregroundColor(.secondary)
    }
}

enum POCRoomInvite {
    static let store = "https://apps.apple.com/app/id6748584483"

    @available(iOS 16.0, *)
    static func text(_ room: TalkyRoom) -> String {
        String(format: "room_invite_text".localized, room.display, room.link.absoluteString, store)
    }
}
