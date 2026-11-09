//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - LiveTalkPanel.swift
//  macTalky
//
//  Parlare sul POC dal Mac: tasto da tenere premuto col mouse, regole e nome
//  la prima volta, Sicurezza per silenziare o segnalare, e le stanze private
//  in cima alla lista dei canali. Lo stesso motore dell'iPhone (LiveRadio).

import AppKit
import SwiftUI

struct LiveTalkPanel: View {
    @ObservedObject private var live = LiveRadio.shared
    @State private var showRules = false
    @State private var reported = false

    var body: some View {
        HStack(spacing: 14) {
            if live.canTalk {
                talkButton
            } else {
                Label(MacString.talkListenOnly.text, systemImage: "ear")
                    .font(.system(size: 11))
                    .foregroundStyle(Talky.dim)
            }
            VStack(alignment: .leading, spacing: 6) {
                if let room = live.room {
                    LiveRoomBadge(room: room)
                } else {
                    safetyMenu
                }
                if live.micDenied {
                    Button {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                    } label: {
                        Label(MacString.talkMicDenied.text, systemImage: "mic.slash")
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                }
            }
            Spacer()
        }
        .opacity(live.state == .online ? 1 : 0.4)
        .disabled(live.state != .online)
        .sheet(isPresented: $showRules) { LiveRulesSheet() }
        .alert(MacString.reportDone.text, isPresented: $reported) {
            Button("OK", role: .cancel) {}
        }
    }

    private var talkButton: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(live.isTalking ? Talky.signal : Talky.panel)
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(Talky.amber.opacity(0.6), lineWidth: 1))
                Image(systemName: live.isTalking ? "waveform" : "mic.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(live.isTalking ? .white : Talky.amber)
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
            Text(live.isTalking ? MacString.talkOnAir.text : MacString.talkHold.text)
                .font(.vfd(11, weight: .bold))
                .foregroundStyle(live.isTalking ? Talky.signal : Talky.dim)
        }
        .accessibilityLabel(MacString.talkHold.text)
    }

    private var safetyMenu: some View {
        Menu {
            if let talker = live.talker {
                Button(MacString.talkMute.format(talker)) { live.muteTalker() }
            }
            Section(MacString.talkReport.text) {
                Button(MacString.reportAbuse.text) { report("abuse") }
                Button(MacString.reportSexual.text) { report("sexual") }
                Button(MacString.reportSpam.text) { report("spam") }
            }
            Button(MacString.rulesTitle.text) { showRules = true }
        } label: {
            Label(MacString.talkSafety.text, systemImage: "hand.raised")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .font(.system(size: 11))
    }

    private func report(_ reason: String) {
        live.reportCurrent(reason: reason)
        reported = true
    }
}

/// Le regole del POC e il nome nei canali, accettate una volta.
struct LiveRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = MumbleManners.nickname

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(MacString.rulesTitle.text)
                .font(.title3.bold())
            Text(MacString.rulesBody.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(MacString.rulesName.text)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Talky-1234", text: $nickname)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(MacString.cancel.text) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(MacString.rulesAccept.text) {
                    MumbleManners.nickname = nickname
                    MumbleManners.rulesAccepted = true
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440)
    }
}

/// Stanze private in cima alla lista del POC.
struct LiveRoomsList: View {
    @ObservedObject private var live = LiveRadio.shared
    @Binding var showPaywall: Bool
    @State private var typed = ""
    @State private var wrong = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(MacString.roomHeader.text.uppercased(with: MacString.locale))
                .font(.vfd(10, weight: .bold))
                .foregroundStyle(Talky.dim)
            if let room = live.room {
                LiveRoomBadge(room: room)
                Button(MacString.roomLeave.text) { live.leaveRoom() }
                    .buttonStyle(ChipButtonStyle())
            } else {
                Button {
                    live.createRoom()
                    if live.proPrompt == .room {
                        live.proPrompt = nil
                        showPaywall = true
                    }
                } label: {
                    Label(MacString.roomCreate.text, systemImage: "plus.circle")
                }
                .buttonStyle(ChipButtonStyle(accent: Talky.teal))
                HStack(spacing: 6) {
                    TextField("K7P2-QX9A", text: $typed)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit(join)
                    Button(MacString.roomJoin.text, action: join)
                        .buttonStyle(ChipButtonStyle())
                        .disabled(typed.isEmpty)
                }
                if let last = live.lastRoom {
                    Button(MacString.roomRejoin.format(last.display)) { live.joinRoom(last) }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }
            Text(wrong ? MacString.roomCodeWrong.text : MacString.roomFooter.text)
                .font(.system(size: 10))
                .foregroundStyle(wrong ? Talky.signal : Talky.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
    }

    private func join() {
        guard let room = TalkyRoom(code: typed) else {
            wrong = true
            return
        }
        wrong = false
        live.joinRoom(room)
    }
}

/// Codice della stanza e invito.
struct LiveRoomBadge: View {
    let room: TalkyRoom

    var body: some View {
        HStack(spacing: 8) {
            Label(room.display, systemImage: "lock.fill")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Talky.amber)
            ShareLink(item: MacString.roomInviteText.format(room.display, room.link.absoluteString,
                                                             "https://apps.apple.com/app/id6748584483")) {
                Label(MacString.roomInvite.text, systemImage: "square.and.arrow.up")
            }
            .font(.system(size: 11))
        }
    }
}
