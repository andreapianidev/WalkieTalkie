//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - StationBrowserSheet.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Full-screen browser per le 135 stazioni radio.
/// Sostituisce la navigazione prev/next con ricerca, preferiti, recenti e raggruppamenti.
struct StationBrowserSheet: View {
    @StateObject private var radioManager = RadioManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var selectedTab: BrowserTab = .all
    @State private var showPaywall: Bool = false

    private enum BrowserTab: Int, CaseIterable, Identifiable {
        case all, favorites, recents, nearby
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .all: return "all_stations".localized
            case .favorites: return "favorites".localized
            case .recents: return "recents".localized
            case .nearby: return "nearby".localized
            }
        }
    }

    // Pro flag letto da UserDefaults: stesso meccanismo usato in RadioManager.playStation.
    private var isProUser: Bool {
        UserDefaults.standard.bool(forKey: "fastboot_isProUser")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                upsellBanner
                tabPicker
                content
            }
            .background(Color("BackgroundColor").ignoresSafeArea())
            .navigationTitle("browse_stations".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) { dismiss() }
                        .foregroundColor(Color("PrimaryTextColor"))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: radioManager.blockedByPaywall) { blocked in
            if blocked { showPaywall = true }
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: {
            radioManager.blockedByPaywall = false
        }) {
            PaywallView(trigger: "station_browser")
        }
    }

    // MARK: - Upsell banner

    /// Banner Pro discreto sopra la lista stazioni. Si auto-nasconde se Pro o
    /// se l'utente l'ha dismissato negli ultimi 7 giorni (cooldown gestito
    /// internamente da `ProUpsellBanner`).
    private var upsellBanner: some View {
        ProUpsellBanner(placement: .stationBrowser) {
            showPaywall = true
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("search_stations".localized, text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("SurfaceColor"))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Tabs

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(BrowserTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        if !searchText.isEmpty {
            flatList(stations: filteredBySearch(radioManager.radioStations),
                     emptyMessage: String(format: "no_search_results".localized, searchText))
        } else {
            switch selectedTab {
            case .all:
                groupedAllView
            case .favorites:
                flatList(stations: radioManager.favoriteStations,
                         emptyMessage: "no_favorites_hint".localized)
            case .recents:
                flatList(stations: radioManager.recentStations,
                         emptyMessage: "no_recents".localized)
            case .nearby:
                flatList(stations: radioManager.localStations,
                         emptyMessage: "no_search_results".localized)
            }
        }
    }

    // MARK: - Grouped "Tutte" view (only when search empty)

    private var groupedAllView: some View {
        List {
            if !radioManager.favoriteStations.isEmpty {
                DisclosureGroup {
                    ForEach(radioManager.favoriteStations) { station in
                        stationRow(station)
                    }
                } label: {
                    sectionHeader("⭐ \("favorites".localized) (\(radioManager.favoriteStations.count))")
                }
            }

            if !radioManager.recentStations.isEmpty {
                DisclosureGroup {
                    ForEach(radioManager.recentStations) { station in
                        stationRow(station)
                    }
                } label: {
                    sectionHeader("🕘 \("recents".localized) (\(radioManager.recentStations.count))")
                }
            }

            if !radioManager.localStations.isEmpty {
                DisclosureGroup {
                    ForEach(radioManager.localStations) { station in
                        stationRow(station)
                    }
                } label: {
                    sectionHeader("📍 \("nearby".localized) — \(radioManager.deviceCountry) (\(radioManager.localStations.count))")
                }
            }

            DisclosureGroup {
                ForEach(radioManager.stationsGroupedByCountry, id: \.country) { entry in
                    DisclosureGroup {
                        ForEach(entry.stations) { station in
                            stationRow(station)
                        }
                    } label: {
                        Text("\(flag(forCountry: entry.country)) \(entry.country) (\(entry.stations.count))")
                            .font(.subheadline)
                            .foregroundColor(Color("PrimaryTextColor"))
                    }
                }
            } label: {
                sectionHeader("🌍 \("by_country".localized)")
            }

            DisclosureGroup {
                ForEach(radioManager.stationsGroupedByGenre, id: \.genre) { entry in
                    DisclosureGroup {
                        ForEach(entry.stations) { station in
                            stationRow(station)
                        }
                    } label: {
                        Text("\(entry.genre) (\(entry.stations.count))")
                            .font(.subheadline)
                            .foregroundColor(Color("PrimaryTextColor"))
                    }
                }
            } label: {
                sectionHeader("🎵 \("by_genre".localized)")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Flat list (search results / single tab)

    @ViewBuilder
    private func flatList(stations: [RadioStation], emptyMessage: String) -> some View {
        if stations.isEmpty {
            emptyState(emptyMessage)
        } else {
            List {
                ForEach(stations) { station in
                    stationRow(station)
                }
            }
            .listStyle(.plain)
            }
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(Color("PrimaryTextColor"))
    }

    // MARK: - Station row

    private func stationRow(_ station: RadioStation) -> some View {
        let isLocked = station.isPro && !isProUser
        let isCurrent = radioManager.currentStation?.id == station.id

        return Button {
            radioManager.playStation(station)
            if !isLocked {
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                flagWithProPill(station: station, isLocked: isLocked)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(station.name)
                            .font(.headline)
                            .foregroundColor(isLocked ? .secondary : Color("PrimaryTextColor"))
                            .lineLimit(1)
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("\(station.country) · \(station.genre)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    if isCurrent {
                        Text("now_playing_short".localized)
                            .font(.caption2.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.yellow))
                    }
                    HStack(spacing: 6) {
                        if station.quality != .unknown {
                            Text(station.quality.rawValue)
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                                )
                        }

                        Button {
                            HapticManager.shared.lightTap()
                            radioManager.toggleFavorite(station)
                        } label: {
                            Image(systemName: radioManager.isFavorite(station) ? "star.fill" : "star")
                                .foregroundColor(radioManager.isFavorite(station) ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .opacity(isLocked ? 0.65 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.4) {
            HapticManager.shared.lightTap()
            radioManager.toggleFavorite(station)
        }
    }

    private func flagWithProPill(station: RadioStation, isLocked: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(station.flagEmoji)
                .font(.title2)
                .frame(width: 36, height: 36)
            if isLocked {
                Text("pro_badge".localized)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.yellow))
                    .offset(x: 4, y: -2)
            }
        }
    }

    // MARK: - Helpers

    private func filteredBySearch(_ stations: [RadioStation]) -> [RadioStation] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return stations }
        return stations.filter {
            $0.name.lowercased().contains(query) ||
            $0.country.lowercased().contains(query) ||
            $0.genre.lowercased().contains(query)
        }
    }

    // Restituisce la bandiera per un paese leggendo direttamente da una RadioStation di quel paese.
    // Evita di duplicare la flagMap privata di RadioStation.
    private func flag(forCountry country: String) -> String {
        radioManager.radioStations.first { $0.country == country }?.flagEmoji ?? "🌍"
    }
}

#if DEBUG
struct StationBrowserSheet_Previews: PreviewProvider {
    static var previews: some View {
        StationBrowserSheet()
    }
}
#endif
