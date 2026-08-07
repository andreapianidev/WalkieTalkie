//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - WalkieView.swift
//  macTalky
//
//  Modulo walkie: PTT circolare (mouse o barra spaziatrice), VU meter,
//  canale corrente (pubblico/privato) e roster dei peer TALKY1.

import SwiftUI
import AppKit

struct WalkieView: View {
    @EnvironmentObject private var engine: WalkieEngine
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var iap: IAPManager
    @StateObject private var channels = PrivateChannelManager.shared

    @Binding var showPaywall: Bool

    @State private var pttPressed = false
    @State private var showChannelSheet = false
    @State private var keyMonitor: Any?

    var body: some View {
        HStack(spacing: 20) {
            // Colonna centrale: PTT
            VStack(spacing: 22) {
                Spacer(minLength: 20)

                channelDisplay

                pttButton

                VStack(spacing: 8) {
                    SegmentedMeter(level: engine.inputLevel)
                        .frame(width: 260)
                    Text(pttHint)
                        .font(.vfd(10))
                        .kerning(1.2)
                        .foregroundStyle(Talky.dim)
                }

                Spacer(minLength: 20)

                statusStrip
            }
            .frame(maxWidth: .infinity)

            // Colonna destra: roster peer
            peerRoster
                .frame(width: 264)
        }
        .padding(24)
        .sheet(isPresented: $showChannelSheet) {
            ChannelSheet(showPaywall: $showPaywall)
        }
        .onAppear(perform: installKeyMonitor)
        .onDisappear(perform: removeKeyMonitor)
    }

    // MARK: - Channel display

    private var channelDisplay: some View {
        Button {
            showChannelSheet = true
        } label: {
            ConsolePanel(padding: 14) {
                VStack(spacing: 4) {
                    PanelLabel("Channel")
                    HStack(spacing: 8) {
                        Image(systemName: channels.currentChannelName == nil ? "globe" : "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Talky.amber)
                        Text((channels.currentChannelName ?? "PUBLIC").uppercased())
                            .font(.vfd(20, weight: .heavy))
                            .kerning(2.5)
                            .foregroundStyle(Talky.amber)
                            .shadow(color: Talky.amberDeep.opacity(0.7), radius: 7)
                    }
                    Text("click to change")
                        .font(.vfd(8))
                        .kerning(1.6)
                        .foregroundStyle(Talky.dim.opacity(0.7))
                }
                .frame(minWidth: 220)
                .crtDisplay(strength: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - PTT

    private var transmitProgress: Double {
        min(engine.transmitElapsed / 10.0, 1.0)
    }

    private var pttButton: some View {
        let active = engine.isTransmitting
        let receiving = engine.isReceiving

        return ZStack {
            // Anelli radio Metal in espansione durante TX/RX
            PulseField(mode: active ? 1 : receiving ? 2 : 0)
                .frame(width: 340, height: 340)

            // Anello progresso trasmissione (max 10s)
            Circle()
                .stroke(Talky.stroke, lineWidth: 5)
                .frame(width: 236, height: 236)
            Circle()
                .trim(from: 0, to: active ? transmitProgress : 0)
                .stroke(Talky.signal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 236, height: 236)
                .animation(.linear(duration: 0.1), value: transmitProgress)

            // Corpo del tasto
            Circle()
                .fill(
                    RadialGradient(
                        colors: active
                            ? [Talky.signal.opacity(0.85), Talky.signal.opacity(0.35)]
                            : receiving
                                ? [Talky.alarm.opacity(0.8), Talky.alarm.opacity(0.3)]
                                : [Talky.panelRaised, Talky.panel],
                        center: .center,
                        startRadius: 10,
                        endRadius: 130
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    Circle().strokeBorder(
                        active ? Talky.signal : receiving ? Talky.alarm : Talky.stroke,
                        lineWidth: 2
                    )
                )
                .shadow(
                    color: active ? Talky.signal.opacity(0.55) : receiving ? Talky.alarm.opacity(0.5) : .black.opacity(0.5),
                    radius: active || receiving ? 34 : 18
                )
                .scaleEffect(pttPressed ? 0.96 : 1)

            VStack(spacing: 6) {
                Image(systemName: receiving ? "speaker.wave.3.fill" : "mic.fill")
                    .font(.system(size: 42, weight: .bold))
                Text(active ? "ON AIR" : receiving ? "RECEIVING" : "TALK")
                    .font(.vfd(15, weight: .heavy))
                    .kerning(3)
                if active {
                    Text(String(format: "%04.1f s", engine.transmitElapsed))
                        .font(.vfd(11))
                        .foregroundStyle(Talky.coal.opacity(0.7))
                }
            }
            .foregroundStyle(active || receiving ? Talky.coal : Talky.text)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Half-duplex: mentre un peer parla il tasto non arma il mic.
                    guard !pttPressed, !receiving else { return }
                    pttPressed = true
                    engine.startTransmitting()
                }
                .onEnded { _ in
                    pttPressed = false
                    engine.stopTransmitting()
                }
        )
        .opacity(receiving ? 0.9 : 1)
        .animation(.easeOut(duration: 0.18), value: active)
        .animation(.easeOut(duration: 0.18), value: receiving)
    }

    private var pttHint: String {
        if !engine.hasMicPermission { return "CLICK TO GRANT MICROPHONE ACCESS" }
        if engine.connectedPeerCount == 0 { return "WAITING FOR PEERS ON THE LOCAL NETWORK" }
        if engine.isReceiving { return "CHANNEL BUSY — WAIT FOR THE PEER TO FINISH" }
        return settings.spacebarPTT ? "HOLD THE BUTTON OR THE SPACE BAR TO TALK" : "HOLD THE BUTTON TO TALK"
    }

    // MARK: - Status strip

    private var statusStrip: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                StatusLamp(color: Talky.signal, on: engine.isTransmitting)
                Text("TX").font(.vfd(10, weight: .bold)).foregroundStyle(Talky.dim)
            }
            HStack(spacing: 6) {
                StatusLamp(color: Talky.alarm, on: engine.isReceiving)
                Text("RX").font(.vfd(10, weight: .bold)).foregroundStyle(Talky.dim)
            }
            HStack(spacing: 6) {
                StatusLamp(color: Talky.teal, on: engine.isNetworkActive)
                Text("NET").font(.vfd(10, weight: .bold)).foregroundStyle(Talky.dim)
            }

            if engine.isNetworkActive {
                Button("STOP LINK") { engine.stop() }
                    .buttonStyle(ChipButtonStyle(accent: Talky.alarm))
            } else {
                Button("START LINK") { engine.start() }
                    .buttonStyle(ChipButtonStyle(accent: Talky.signal))
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Peer roster

    private var peerRoster: some View {
        ConsolePanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelLabel("Peers on channel")
                    Spacer()
                    Text("\(engine.connectedPeerCount)")
                        .font(.vfd(12, weight: .bold))
                        .foregroundStyle(Talky.signal)
                }

                if engine.peers.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 26))
                            .foregroundStyle(Talky.dim.opacity(0.6))
                        Text("Scanning for Talky devices…\niPhone, Android and Mac on the same Wi-Fi appear here.")
                            .font(.system(size: 11))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Talky.dim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(engine.peers) { peer in
                                peerRow(peer)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                // Guideline 5.1.1(iv): niente etichette che spingono a concedere
                // il permesso. E se l'utente ha gia' negato, un bottone che
                // "chiede" non fa nulla — macOS mostra il prompt una volta sola —
                // quindi in quel caso si rimanda alle Impostazioni di Sistema,
                // che e' il rimedio suggerito da Apple.
                if !engine.hasMicPermission {
                    VStack(spacing: 6) {
                        Text("Push-to-talk needs the microphone. The Radio module works without it.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Talky.dim)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if engine.micPermissionDenied {
                            Button("Open System Settings") { openMicrophoneSettings() }
                                .buttonStyle(ChipButtonStyle(accent: Talky.dim, filled: true))
                        } else {
                            Button("Continue") { engine.requestMicPermission() }
                                .buttonStyle(ChipButtonStyle(accent: Talky.dim, filled: true))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// Apre Impostazioni di Sistema > Privacy e sicurezza > Microfono. È l'unica
    /// strada quando il permesso è già stato negato: il prompt non ritorna.
    private func openMicrophoneSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func peerRow(_ peer: WalkieEngine.Peer) -> some View {
        let connected = engine.connectedPeerIDs.contains(peer.id)
        return HStack(spacing: 10) {
            StatusLamp(color: Talky.signal, on: connected)
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Talky.text)
                    .lineLimit(1)
                Text(connected ? "linked" : "discovered")
                    .font(.vfd(9))
                    .foregroundStyle(Talky.dim)
            }
            Spacer()
        }
        .padding(10)
        .background(Talky.panelRaised.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
    }

    // MARK: - Spacebar PTT

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            // Singleton diretti: la closure sopravvive al body della view,
            // gli @EnvironmentObject non sono affidabili qui.
            let engine = WalkieEngine.shared
            guard SettingsManager.shared.spacebarPTT,
                  event.keyCode == 49, // space
                  !(NSApp.keyWindow?.firstResponder is NSTextView) else {
                return event
            }
            if event.type == .keyDown {
                if !event.isARepeat, !engine.isTransmitting, !engine.isReceiving {
                    pttPressed = true
                    engine.startTransmitting()
                }
            } else {
                pttPressed = false
                engine.stopTransmitting()
            }
            return nil // consumato: niente beep di sistema
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if engine.isTransmitting {
            engine.stopTransmitting()
        }
    }
}

// MARK: - Channel sheet

struct ChannelSheet: View {
    @EnvironmentObject private var iap: IAPManager
    @StateObject private var channels = PrivateChannelManager.shared
    @Environment(\.dismiss) private var dismiss

    @Binding var showPaywall: Bool

    @State private var name = ""
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                PanelLabel("Private channel")
                Spacer()
                if !iap.isProUser { ProBadge() }
            }

            Text("Devices that share the same channel password can hear each other — everyone else stays on PUBLIC. Works across iPhone, Android and Mac.")
                .font(.system(size: 12))
                .foregroundStyle(Talky.dim)
                .fixedSize(horizontal: false, vertical: true)

            if channels.currentChannelName != nil {
                ConsolePanel(padding: 12) {
                    HStack {
                        Image(systemName: "lock.fill").foregroundStyle(Talky.amber)
                        Text(channels.currentChannelName ?? "")
                            .font(.vfd(14, weight: .bold))
                            .foregroundStyle(Talky.text)
                        Spacer()
                        Button("LEAVE") {
                            channels.leaveChannel()
                            dismiss()
                        }
                        .buttonStyle(ChipButtonStyle(accent: Talky.alarm))
                    }
                }
            }

            TextField("Channel name", text: $name)
                .textFieldStyle(.roundedBorder)
            SecureField("Password (min 4 characters)", text: $password)
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Talky.alarm)
            }

            HStack {
                Button("CANCEL") { dismiss() }
                    .buttonStyle(ChipButtonStyle(accent: Talky.dim))
                Spacer()
                Button("JOIN CHANNEL") {
                    guard iap.isProUser else {
                        dismiss()
                        showPaywall = true
                        return
                    }
                    if channels.joinChannel(name: name, password: password) {
                        dismiss()
                    } else {
                        error = "Check name and password (min \(PrivateChannelManager.minPasswordLength) characters)."
                    }
                }
                .buttonStyle(ChipButtonStyle(filled: true))
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Talky.panel)
    }
}
