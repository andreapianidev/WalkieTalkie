//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - RadioView.swift
//  macTalky
//
//  Modulo radio: browser delle 343 stazioni (ricerca, filtri, preferiti,
//  recenti) + barra "now playing" con visualizer Metal e controlli.

import SwiftUI

enum RadioFilter: String, CaseIterable, Identifiable {
    case all, free, pro, favorites, recents

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "ALL"
        case .free: return "FREE"
        case .pro: return "PRO"
        case .favorites: return "FAVORITES"
        case .recents: return "RECENTS"
        }
    }
}

struct RadioView: View {
    @EnvironmentObject private var radio: RadioManager
    @EnvironmentObject private var iap: IAPManager
    @EnvironmentObject private var settings: SettingsManager

    @Binding var showPaywall: Bool

    @State private var search = ""
    @State private var filter: RadioFilter = .all

    var body: some View {
        VStack(spacing: 16) {
            header
            stationList
            nowPlayingBar
        }
        .padding(24)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PanelLabel("World band receiver")
                Spacer()
                Text("\(radio.radioStations.count) STATIONS")
                    .font(.vfd(10, weight: .bold))
                    .kerning(1.4)
                    .foregroundStyle(Talky.dim)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Talky.dim)
                    TextField("Search station, country or genre…", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Talky.text)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Talky.panelRaised.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Talky.stroke, lineWidth: 1))

                ForEach(RadioFilter.allCases) { f in
                    Button(f.label) {
                        withAnimation(.easeOut(duration: 0.15)) { filter = f }
                    }
                    .buttonStyle(ChipButtonStyle(
                        accent: filter == f ? Talky.amber : Talky.dim,
                        filled: filter == f
                    ))
                }
            }
        }
    }

    // MARK: - Station list

    private var filteredStations: [RadioStation] {
        let base: [RadioStation]
        switch filter {
        case .all: base = radio.radioStations
        case .free: base = radio.freeStations
        case .pro: base = radio.proStations
        case .favorites: base = radio.favoriteStations
        case .recents: base = radio.recentStations
        }

        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(query)
                || $0.country.lowercased().contains(query)
                || $0.genre.lowercased().contains(query)
        }
    }

    private var groupedStations: [(country: String, stations: [RadioStation])] {
        let local = radio.deviceCountry
        let grouped = Dictionary(grouping: filteredStations) { $0.country }
        return grouped
            .map { (country: $0.key, stations: $0.value.sorted { $0.name < $1.name }) }
            .sorted { a, b in
                if a.country == local { return true }
                if b.country == local { return false }
                return a.country < b.country
            }
    }

    private var stationList: some View {
        ConsolePanel(padding: 0) {
            Group {
                if filteredStations.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "radio")
                            .font(.system(size: 30))
                            .foregroundStyle(Talky.dim.opacity(0.5))
                        Text(emptyMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(Talky.dim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
                            ForEach(groupedStations, id: \.country) { group in
                                Section {
                                    ForEach(group.stations) { station in
                                        stationRow(station)
                                    }
                                } header: {
                                    HStack {
                                        Text("\(group.stations.first?.flagEmoji ?? "🌍")  \(group.country.uppercased())")
                                            .font(.vfd(10, weight: .bold))
                                            .kerning(1.8)
                                            .foregroundStyle(Talky.dim)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Talky.panel.opacity(0.95))
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyMessage: String {
        switch filter {
        case .favorites: return "No favorites yet — click the star on any station."
        case .recents: return "Stations you play will appear here."
        default: return "No station matches your search."
        }
    }

    private func stationRow(_ station: RadioStation) -> some View {
        let isCurrent = radio.currentStation?.id == station.id
        let locked = station.isPro && !iap.isProUser

        return Button {
            radio.playStation(station)
        } label: {
            HStack(spacing: 12) {
                Text(station.flagEmoji)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.system(size: 13, weight: isCurrent ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isCurrent ? Talky.amber : Talky.text)
                        .lineLimit(1)
                    Text("\(station.displayLabel) · \(station.quality.rawValue)")
                        .font(.vfd(9))
                        .kerning(0.8)
                        .foregroundStyle(Talky.dim)
                }

                Spacer()

                if isCurrent {
                    Image(systemName: radio.isBuffering ? "ellipsis" : "waveform")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Talky.amber)
                        .symbolEffect(.variableColor.iterative, isActive: radio.isPlaying)
                }

                if locked { ProBadge() }

                Button {
                    radio.toggleFavorite(station)
                } label: {
                    Image(systemName: radio.isFavorite(station) ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(radio.isFavorite(station) ? Talky.amber : Talky.dim.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isCurrent ? Talky.amber.opacity(0.08) : .clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Now playing

    private var nowPlayingBar: some View {
        ConsolePanel(padding: 14) {
            HStack(spacing: 16) {
                // Display stazione
                VStack(alignment: .leading, spacing: 3) {
                    if let station = radio.currentStation {
                        Text("\(station.flagEmoji) \(station.name)")
                            .font(.vfd(15, weight: .bold))
                            .foregroundStyle(Talky.amber)
                            .shadow(color: Talky.amberDeep.opacity(0.6), radius: 6)
                            .lineLimit(1)
                        Text(radio.isBuffering
                             ? "TUNING…"
                             : "\(station.genre.uppercased()) · \(station.country.uppercased())")
                            .font(.vfd(9))
                            .kerning(1.4)
                            .foregroundStyle(Talky.dim)
                    } else {
                        Text("— STANDBY —")
                            .font(.vfd(15, weight: .bold))
                            .foregroundStyle(Talky.dim)
                        Text(radio.lastError ?? "SELECT A STATION")
                            .font(.vfd(9))
                            .kerning(1.4)
                            .foregroundStyle(radio.lastError == nil ? Talky.dim : Talky.alarm)
                            .lineLimit(1)
                    }
                }
                .frame(width: 230, alignment: .leading)

                // Visualizer Metal
                VUWave(level: radio.isPlaying ? 0.55 : 0, playing: radio.isPlaying && !radio.isBuffering)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)

                // Transport
                HStack(spacing: 10) {
                    Button { radio.previousStation() } label: {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Talky.text)

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
                            .font(.system(size: 34))
                            .foregroundStyle(Talky.amber)
                            .shadow(color: Talky.amberDeep.opacity(0.6), radius: 8)
                    }
                    .buttonStyle(.plain)

                    Button { radio.nextStation() } label: {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Talky.text)

                    Button { radio.stopRadio() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(radio.currentStation == nil ? Talky.dim.opacity(0.4) : Talky.alarm)
                    .disabled(radio.currentStation == nil)
                }
                .font(.system(size: 15))

                // Volume
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Talky.dim)
                    Slider(
                        value: Binding(
                            get: { Double(settings.radioVolume) },
                            set: { settings.radioVolume = Float($0) }
                        ),
                        in: 0...1
                    )
                    .controlSize(.small)
                    .frame(width: 110)
                    .tint(Talky.amber)
                }
            }
        }
    }
}
