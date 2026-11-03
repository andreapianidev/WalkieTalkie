//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - RadioScopeDeck.swift
//  WalkieTalkie
//
//  La radio non trasmette: al posto del tasto per parlare, lo schermo con la
//  forma d'onda della stazione che suona e le letture dello stream.

import SwiftUI

struct RadioScopeDeck: View {
    @ObservedObject var radio: RadioManager
    @ObservedObject private var sleep = SleepTimerManager.shared
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            RadioScopeScreen(radio: radio)
                .frame(height: compact ? 132 : 185)
                .padding(.horizontal, 12)
            TimelineView(.periodic(from: .now, by: 2)) { _ in
                DialReadings(cells: cells, compact: compact)
            }
        }
    }

    private var cells: [DialReading] {
        let none = "--"
        let station = radio.currentStation
        let state: String
        if radio.isBuffering {
            state = "radio_state_buffering".localized
        } else {
            state = (radio.isPlaying ? "radio_state_on_air" : "radio_state_paused").localized
        }
        let sleepText = sleep.isActive
            ? String(format: "%d:%02d", Int(sleep.remainingSeconds) / 60, Int(sleep.remainingSeconds) % 60)
            : "OFF"
        return [
            DialReading(label: "radio_info_country".localized, value: station?.countryName ?? none),
            DialReading(label: "radio_info_genre".localized, value: station?.genre ?? none),
            DialReading(label: "radio_info_bitrate".localized, value: radio.streamKbps.map { "\($0) kbps" } ?? none),
            DialReading(label: "radio_info_state".localized, value: state, lit: radio.isPlaying && !radio.isBuffering),
            DialReading(label: "radio_info_volume".localized, value: "\(Int((radio.volume * 100).rounded()))%"),
            DialReading(label: "radio_info_sleep".localized, value: sleepText, lit: sleep.isActive)
        ]
    }
}

/// Il display a barre di quello che suona, con il livello degli ultimi sei
/// secondi sotto.
struct RadioScopeScreen: View {
    @ObservedObject var radio: RadioManager

    private let amber = Color(red: 1.0, green: 0.8, blue: 0.0)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !radio.isPlaying)) { _ in
            let display = RadioScope.shared.display()
            ZStack {
                Color.black
                SoundBandsView(display: display, color: amber)
                    .padding(.horizontal, 6)
                    .padding(.top, 22)
                    .padding(.bottom, 6)
                    .opacity(display.flowing ? 1 : 0.35)
                if !display.flowing {
                    Text(caption)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(amber.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                if display.flowing {
                    HStack(spacing: 5) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("ON AIR")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var caption: String {
        if radio.currentStation == nil { return "radio_scope_pick".localized }
        if !radio.isPlaying { return "radio_scope_paused".localized }
        return "radio_scope_buffering".localized
    }
}
