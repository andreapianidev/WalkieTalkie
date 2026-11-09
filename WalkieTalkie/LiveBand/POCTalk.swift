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
    @State private var reported = false

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            if live.state == .online {
                if live.canTalk {
                    talkButton
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
                if let room = live.room {
                    POCRoomBadge(room: room)
                } else {
                    moderationMenu
                }
            }
        }
        .sheet(isPresented: $showRules) { POCRulesSheet() }
        .alert("mumble_report_done".localized, isPresented: $reported) {
            Button("ok".localized, role: .cancel) {}
        }
    }

    private var talkButton: some View {
        let size: CGFloat = compact ? 64 : 84
        return ZStack {
            Circle()
                .fill(live.isTalking ? Color.red : Color.black)
                .frame(width: size, height: size)
            Circle()
                .fill(Color.white)
                .frame(width: size - 12, height: size - 12)
            Image(systemName: live.isTalking ? "waveform" : "mic.fill")
                .font(.system(size: compact ? 20 : 26, weight: .bold))
                .foregroundColor(live.isTalking ? .red : .black)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !live.isTalking else { return }
                    guard MumbleManners.rulesAccepted else {
                        showRules = true
                        return
                    }
                    live.startTalking()
                }
                .onEnded { _ in live.stopTalking() }
        )
        .overlay(alignment: .bottom) {
            Text((live.isTalking ? "mumble_talking" : "mumble_hold_to_talk").localized)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(live.isTalking ? .red : .secondary)
                .fixedSize()
                .offset(y: compact ? 16 : 20)
        }
        .padding(.bottom, compact ? 14 : 18)
        .accessibilityLabel("mumble_hold_to_talk".localized)
        .accessibilityAddTraits(.isButton)
    }

    /// Sempre raggiungibile mentre si e' in un canale: Apple vuole che chi
    /// e' disturbato possa silenziare e segnalare senza cercare.
    private var moderationMenu: some View {
        Menu {
            if let talker = live.talker {
                Button {
                    live.muteTalker()
                } label: {
                    Label(String(format: "mumble_mute_user".localized, talker), systemImage: "speaker.slash")
                }
            }
            Section("mumble_report".localized) {
                ForEach(["abuse", "sexual", "spam"], id: \.self) { reason in
                    Button(role: .destructive) {
                        live.reportCurrent(reason: reason)
                        reported = true
                    } label: {
                        Text("mumble_report_reason_\(reason)".localized)
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
