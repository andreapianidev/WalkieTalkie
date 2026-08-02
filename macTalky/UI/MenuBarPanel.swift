//creato da Andrea Piani - Immaginet Srl - 02/08/26 - https://www.andreapiani.com - MenuBarPanel.swift
//  macTalky
//
//  Mini-console nella menu bar: PTT hold-to-talk, stato canale/peer,
//  controlli radio e scorciatoie. L'icona di stato nella barra cambia
//  con TX (mic) / RX (speaker) e mostra il numero di peer collegati.

import SwiftUI
import AppKit

struct MenuBarPanel: View {
    @EnvironmentObject private var engine: WalkieEngine
    @EnvironmentObject private var radio: RadioManager
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var channels = PrivateChannelManager.shared

    @Environment(\.openWindow) private var openWindow

    @State private var pttPressed = false

    var body: some View {
        VStack(spacing: 12) {
            header
            pttButton
            meter
            Divider().overlay(Talky.stroke)
            radioRow
            Divider().overlay(Talky.stroke)
            footer
        }
        .padding(14)
        .frame(width: 264)
        .background(Talky.coal)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            StatusLamp(color: Talky.signal, on: engine.isNetworkActive)
            VStack(alignment: .leading, spacing: 1) {
                Text((channels.currentChannelName ?? "PUBLIC").uppercased())
                    .font(.vfd(12, weight: .heavy))
                    .kerning(1.6)
                    .foregroundStyle(Talky.amber)
                Text("\(engine.connectedPeerCount) peer\(engine.connectedPeerCount == 1 ? "" : "s") linked")
                    .font(.vfd(9))
                    .foregroundStyle(Talky.dim)
            }
            Spacer()
            if engine.isReceiving {
                Text("RX")
                    .font(.vfd(9, weight: .heavy))
                    .foregroundStyle(Talky.coal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Talky.alarm, in: Capsule())
            }
        }
    }

    // MARK: - PTT

    private var pttButton: some View {
        let active = engine.isTransmitting
        let receiving = engine.isReceiving

        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    active ? Talky.signal
                    : receiving ? Talky.alarm
                    : Talky.panelRaised
                )
                .shadow(color: active ? Talky.signal.opacity(0.5) : receiving ? Talky.alarm.opacity(0.5) : .clear,
                        radius: 10)
            HStack(spacing: 8) {
                Image(systemName: receiving ? "speaker.wave.3.fill" : "mic.fill")
                    .font(.system(size: 15, weight: .bold))
                VStack(spacing: 1) {
                    Text(active ? "ON AIR" : receiving ? "RECEIVING" : "HOLD TO TALK")
                        .font(.vfd(12, weight: .heavy))
                        .kerning(1.8)
                    if active {
                        Text(String(format: "%04.1f s", engine.transmitElapsed))
                            .font(.vfd(9))
                            .opacity(0.7)
                    }
                }
            }
            .foregroundStyle(active || receiving ? Talky.coal : Talky.text)
        }
        .frame(height: 52)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(pttPressed ? 0.98 : 1)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pttPressed else { return }
                    pttPressed = true
                    engine.startTransmitting()
                }
                .onEnded { _ in
                    pttPressed = false
                    engine.stopTransmitting()
                }
        )
        .animation(.easeOut(duration: 0.15), value: active)
        .animation(.easeOut(duration: 0.15), value: receiving)
    }

    private var meter: some View {
        SegmentedMeter(level: engine.inputLevel, segments: 22)
    }

    // MARK: - Radio

    private var radioRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                if let station = radio.currentStation {
                    Text("\(station.flagEmoji) \(station.name)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Talky.text)
                        .lineLimit(1)
                    Text(radio.isBuffering ? "TUNING…" : station.genre.uppercased())
                        .font(.vfd(8))
                        .kerning(1.2)
                        .foregroundStyle(Talky.dim)
                } else {
                    Text("Radio standby")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Talky.dim)
                    Text("\(radio.radioStations.count) STATIONS")
                        .font(.vfd(8))
                        .kerning(1.2)
                        .foregroundStyle(Talky.dim.opacity(0.7))
                }
            }
            Spacer()
            Button { radio.previousStation() } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Talky.dim)
            Button {
                if radio.isPlaying {
                    radio.pauseRadio()
                } else if radio.currentStation != nil {
                    radio.resumeRadio()
                } else {
                    radio.playStation(radio.resumeStation)
                }
            } label: {
                Image(systemName: radio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Talky.amber)
            }
            .buttonStyle(.plain)
            Button { radio.nextStation() } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Talky.dim)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("OPEN CONSOLE") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(ChipButtonStyle(accent: Talky.amber))

            Spacer()

            SettingsLink {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Talky.dim)
            }
            .buttonStyle(.plain)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Talky.dim)
            }
            .buttonStyle(.plain)
            .help("Quit macTalky")
        }
    }
}

// MARK: - Icona di stato

/// Label dinamica per la MenuBarExtra: simbolo che riflette TX/RX/link.
/// Osserva il singleton direttamente: la closure `label:` della MenuBarExtra
/// non riceve gli environment object in modo affidabile.
struct MenuBarLabel: View {
    @ObservedObject private var engine = WalkieEngine.shared

    var body: some View {
        let symbol: String
        if engine.isTransmitting {
            symbol = "mic.fill"
        } else if engine.isReceiving {
            symbol = "speaker.wave.3.fill"
        } else if engine.connectedPeerCount > 0 {
            symbol = "dot.radiowaves.left.and.right"
        } else {
            symbol = "wave.3.right"
        }
        return Image(systemName: symbol)
    }
}
