//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - WalkiePage.swift
//  TalkyWatch
//
//  Il PTT sul polso: finche' il dito resta sul tasto l'iPhone trasmette con
//  il suo microfono, sullo stesso canale e agli stessi dispositivi del
//  walkie. Utile con il telefono sul cruscotto o nello zaino.

import SwiftUI
import WatchKit

struct WalkiePage: View {
    @EnvironmentObject private var phone: PhoneLink
    @State private var pressed = false
    @State private var away = false

    var body: some View {
        VStack(spacing: 8) {
            Text(phone.channel.isEmpty ? "WALKIE" : phone.channel.uppercased())
                .font(.system(.caption, design: .monospaced).weight(.heavy))
                .foregroundStyle(TalkyDial.amber)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Circle()
                .fill(pressed ? TalkyDial.amber : Color.white.opacity(0.12))
                .overlay(Circle().stroke(TalkyDial.amber, lineWidth: 3))
                .overlay {
                    VStack(spacing: 2) {
                        Image(systemName: "mic.fill").font(.title2)
                        Text(pressed ? "wr_talking".wrist : "PTT")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                    }
                    .foregroundStyle(pressed ? .black : .white)
                }
                .frame(maxWidth: 110, maxHeight: 110)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !pressed { press(true) } }
                        .onEnded { _ in press(false) }
                )
                .accessibilityLabel("wr_hold".wrist)
                .accessibilityAddTraits(.isButton)

            Text(status)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(away || phone.peers == 0 ? TalkyDial.color(.closed) : .secondary)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
    }

    private var status: String {
        if away { return "wr_phone_away".wrist }
        if phone.peers == 0 { return "wr_nobody".wrist }
        if pressed { return "wr_phone_mic".wrist }
        return String(format: "wr_peers".wrist, phone.peers)
    }

    private func press(_ down: Bool) {
        pressed = down
        WKInterfaceDevice.current().play(down ? .start : .stop)
        Task {
            let result = await phone.ptt(down)
            away = result == .phoneAway
            // Nessuno dall'altra parte: lo si sente subito, senza guardare.
            if down, result == .phoneAway || result == .sent(peers: 0) {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
