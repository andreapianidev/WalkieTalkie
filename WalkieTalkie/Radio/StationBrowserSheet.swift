//creato da Andrea Piani - 22/05/26 - https://www.andreapiani.com - StationBrowserSheet.swift
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

    /// Stazione Pro toccata da un utente Free: apre il foglio di scelta fra
    /// abbonamento e pass a 24 ore.
    @State private var lockedStation: RadioStation?

    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var stationPasses = StationPassManager.shared

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
                streamingNote
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
        .onAppear {
            // Chi sta sfogliando le stazioni incontrera' quasi certamente una
            // riga bloccata: il rewarded va caricato adesso, cosi' quando tocca
            // "ascolta 24 ore" il video parte subito.
            adManager.prepareRewardedIfNeeded()
            StationPassManager.shared.pruneExpired()
        }
        .confirmationDialog(
            lockedStation?.name ?? "",
            isPresented: Binding(
                get: { lockedStation != nil },
                set: { if !$0 { lockedStation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("station_locked.watch_video".localized) {
                unlockWithRewarded()
            }
            Button("station_locked.go_pro".localized) {
                lockedStation = nil
                showPaywall = true
            }
            Button("cancel".localized, role: .cancel) {
                lockedStation = nil
            }
        } message: {
            Text("station_locked.message".localized)
        }
    }

    // MARK: - Sblocco a 24 ore

    /// Mostra il rewarded e, a premio riscosso, fa partire subito la stazione.
    ///
    /// Se l'annuncio non e' pronto non si lascia il tocco a vuoto: si apre il
    /// paywall, che e' l'altra strada per la stessa cosa.
    private func unlockWithRewarded() {
        guard let station = lockedStation else { return }
        lockedStation = nil

        guard adManager.rewarded.isAdReady else {
            showPaywall = true
            return
        }

        adManager.presentRewardedStationPass(
            stationID: station.id,
            stationName: station.name
        ) {
            radioManager.playStation(station)
            dismiss()
        }
    }

    // MARK: - Nota streaming

    /// Una riga sola, sempre visibile dove si scelgono le stazioni: queste
    /// arrivano da internet, non dall'antenna.
    ///
    /// La stessa frase esiste nell'onboarding, ma la vede solo chi installa
    /// l'app adesso. Chi ha scritto "Fake Walkie Talkie" e "Das angebliche
    /// Radio ist ein Fake" aveva gia' finito l'onboarding mesi fa, o non lo ha
    /// mai visto, e si e' trovato una app che mostrava frequenze FM sulla
    /// schermata di blocco. Il posto dove serve dirlo e' questo.
    private var streamingNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi")
                .font(.system(size: 10, weight: .semibold))
            Text("radio.streaming_disclaimer".localized)
                .font(.caption2)
                .multilineTextAlignment(.leading)
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
        // Un pass a 24 ore vinto col rewarded apre la stazione come se fosse
        // Pro, finche' dura.
        let passRemaining = stationPasses.remainingShortDescription(for: station.id)
        let isLocked = station.isPro && !isProUser && passRemaining == nil
        let isCurrent = radioManager.currentStation?.id == station.id

        return Button {
            // Una riga bloccata non prova piu' a suonare per farsi respingere
            // dal gate: apre direttamente la scelta fra Pro e pass a 24 ore.
            guard !isLocked else {
                lockedStation = station
                return
            }
            radioManager.playStation(station)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                flagWithProPill(station: station, isLocked: isLocked, passRemaining: passRemaining)

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

    private func flagWithProPill(station: RadioStation,
                                 isLocked: Bool,
                                 passRemaining: String? = nil) -> some View {
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
            } else if let passRemaining {
                // Stazione Pro aperta da un pass: si dice quanto resta, cosi'
                // nessuno scopre il giorno dopo che si e' richiusa.
                Text(passRemaining)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.green))
                    .offset(x: 6, y: -2)
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
