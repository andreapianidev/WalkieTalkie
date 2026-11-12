//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - RadioPage.swift
//  TalkyWatch
//
//  Le stazioni dell'iPhone, preferite in cima. Le stazioni Pro suonano con
//  Talky Pro, come sull'iPhone; il pass di 24 ore con il video resta
//  dell'iPhone, perche' sul Watch non ci sono pubblicita'.

import SwiftUI

struct RadioPage: View {
    @EnvironmentObject private var phone: PhoneLink
    @EnvironmentObject private var radio: WristRadio
    @State private var storePro = false
    @State private var locked: WristStation?

    private var pro: Bool { phone.phonePro || storePro }

    var body: some View {
        NavigationStack {
            List {
                if let station = radio.station {
                    Section { onAir(station) }
                }
                if phone.stations.isEmpty {
                    Text("wr_no_catalog".wrist)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !phone.favorites.isEmpty {
                    Section("wr_favorites".wrist) {
                        ForEach(phone.favorites) { row($0) }
                    }
                }
                if !phone.stations.isEmpty {
                    Section("wr_all".wrist) {
                        ForEach(phone.stations) { row($0) }
                    }
                }
            }
            .navigationTitle("wr_radio".wrist)
        }
        .task { storePro = await TalkyPro.isActive() }
        .alert("Talky Pro", isPresented: Binding(get: { locked != nil }, set: { if !$0 { locked = nil } })) {
            Button("OK") { locked = nil }
        } message: {
            Text("wr_pro_station".wrist)
        }
    }

    private func onAir(_ station: WristStation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(station.name)
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(TalkyDial.amber)
                .lineLimit(2)
            switch radio.phase {
            case .connecting:
                Text("wr_connecting".wrist).font(.footnote).foregroundStyle(.secondary)
            case .failed(let why):
                Text(why).font(.footnote).foregroundStyle(TalkyDial.color(.closed))
            case .playing, .off:
                Text("\(station.flag) \(station.dial)").font(.footnote).foregroundStyle(.secondary)
            }
            Button(role: .destructive) { radio.stop() } label: {
                Label("wr_stop".wrist, systemImage: "stop.fill")
            }
        }
    }

    private func row(_ station: WristStation) -> some View {
        Button {
            if station.isPro, !pro {
                locked = station
            } else {
                Task { await radio.play(station) }
            }
        } label: {
            HStack(spacing: 8) {
                Text(station.flag)
                VStack(alignment: .leading, spacing: 1) {
                    Text(station.name).lineLimit(1)
                    Text(station.dial)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if station.isPro, !pro {
                    Image(systemName: "lock.fill").font(.caption2).foregroundStyle(TalkyDial.amber)
                } else if radio.station == station {
                    Image(systemName: "speaker.wave.2.fill").font(.caption2).foregroundStyle(TalkyDial.amber)
                }
            }
        }
    }
}
