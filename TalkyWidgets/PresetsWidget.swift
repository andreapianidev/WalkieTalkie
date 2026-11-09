//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - PresetsWidget.swift
//  TalkyWidgets
//
//  "Le mie radio": le stazioni preferite come i tasti di memoria di
//  un'autoradio, con il play che suona dal widget senza aprire Talky.
//  Gratis una stazione nel formato piccolo; con Talky Pro quattro nel medio
//  e otto nel grande. I dati li scrive l'app (Shared/WidgetLink/RadioShelf).

import AppIntents
import SwiftUI
import WidgetKit

/// Quello che l'app ha lasciato sullo scaffale, piu' lo stato Pro letto da StoreKit.
@available(iOS 17.0, macOS 14.0, *)
struct ShelfEntry: TimelineEntry {
    let date: Date
    let presets: [PresetCard]
    let recents: Bool
    let onAir: OnAirCard?
    let hasPro: Bool

    /// La stazione che suona adesso: sul suo tasto va lo stop.
    var playingID: Int? { onAir?.playing == true ? onAir?.station.id : nil }

    static func current() async -> ShelfEntry {
        ShelfEntry(date: .now, presets: RadioShelf.presets, recents: RadioShelf.presetsAreRecents,
                   onAir: RadioShelf.onAir, hasPro: await TalkyPro.isActive())
    }

    /// Solo per la galleria dei widget, finche' l'utente non ha preferite:
    /// stazioni vere del catalogo, che il play farebbe suonare davvero.
    static let preview = ShelfEntry(date: .now, presets: [
        PresetCard(id: 1, name: "RTL 102.5", flag: "🇮🇹", dial: "102.5", isPro: false, passUntil: nil),
        PresetCard(id: 2, name: "Radio Deejay", flag: "🇮🇹", dial: "106.2", isPro: false, passUntil: nil),
        PresetCard(id: 3, name: "Rai Radio 1", flag: "🇮🇹", dial: "89.7", isPro: false, passUntil: nil),
        PresetCard(id: 10, name: "Radio Capital", flag: "🇮🇹", dial: "103.0", isPro: false, passUntil: nil),
        PresetCard(id: 11, name: "Radio Kiss Kiss", flag: "🇮🇹", dial: "97.0", isPro: false, passUntil: nil),
        PresetCard(id: 31, name: "Europe 1", flag: "🇫🇷", dial: "104.7", isPro: true, passUntil: nil),
        PresetCard(id: 32, name: "BBC Radio 6 Music", flag: "🇬🇧", dial: "ALTERNATIVE", isPro: true, passUntil: nil),
        PresetCard(id: 33, name: "Classic FM", flag: "🇬🇧", dial: "100.0", isPro: true, passUntil: nil)
    ], recents: false,
       onAir: OnAirCard(station: PresetCard(id: 1, name: "RTL 102.5", flag: "🇮🇹", dial: "102.5", isPro: false, passUntil: nil),
                        title: nil, playing: false),
       hasPro: true)
}

/// Lo stesso per "Le mie radio" e "In onda adesso": li ricarica l'app quando
/// cambia qualcosa, da soli si rinnovano solo alla scadenza di un pass.
@available(iOS 17.0, macOS 14.0, *)
struct ShelfProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShelfEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (ShelfEntry) -> Void) {
        Task {
            let entry = await ShelfEntry.current()
            completion(context.isPreview && entry.presets.isEmpty && entry.onAir == nil ? .preview : entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShelfEntry>) -> Void) {
        Task {
            let entry = await ShelfEntry.current()
            let passEnds = (entry.presets + [entry.onAir?.station].compactMap { $0 })
                .compactMap(\.passUntil)
                .filter { $0 > entry.date }
                .min()
            completion(Timeline(entries: [entry], policy: passEnds.map { .after($0) } ?? .never))
        }
    }
}

/// Il tasto tondo: play, stop sulla stazione in onda, lucchetto se serve Pro.
@available(iOS 17.0, macOS 14.0, *)
struct RadioKey: View {
    let card: PresetCard
    let playing: Bool
    let locked: Bool
    var size: CGFloat = 30

    var body: some View {
        if locked {
            Link(destination: URL(string: "talky://pro")!) { face("lock.fill") }
                .accessibilityLabel(Text("Talky Pro"))
        } else if playing {
            Button(intent: StopRadioIntent()) { face("stop.fill") }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("w_intent_stop"))
        } else {
            Button(intent: PlayPresetIntent(stationID: card.id)) { face("play.fill") }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("w_intent_play"))
        }
    }

    private func face(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .background(Circle().fill(locked ? Color.white.opacity(0.55) : TalkyDial.amber))
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct PresetsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShelfEntry

    var body: some View {
        Group {
            if entry.presets.isEmpty {
                empty
            } else if family == .systemSmall {
                small
            } else if entry.hasPro {
                grid(interactive: true)
                    .widgetURL(URL(string: "talky://radio"))
            } else {
                // Si vedono le proprie stazioni, oscurate e senza tasti.
                grid(interactive: false)
                    .modifier(ProLock(locked: true))
            }
        }
        .containerBackground(.black, for: .widget)
    }

    private var header: some View {
        Text(String(localized: entry.recents ? "w_presets_recents" : "w_presets_title"))
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(TalkyDial.amber)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    /// Gratis: la prima preferita che si puo' ascoltare, o la prima in assoluto.
    private var small: some View {
        let card = entry.presets.first { !$0.locked(hasPro: entry.hasPro, at: entry.date) } ?? entry.presets[0]
        let locked = card.locked(hasPro: entry.hasPro, at: entry.date)
        let playing = entry.playingID == card.id
        return VStack(alignment: .leading, spacing: 3) {
            header
            Spacer(minLength: 0)
            Text(card.flag)
                .font(.system(size: 24))
            Text(card.name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(card.dial)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(TalkyDial.amber.opacity(0.75))
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack {
                if playing {
                    onAirMark
                }
                Spacer(minLength: 0)
                RadioKey(card: card, playing: playing, locked: locked, size: 34)
            }
        }
        // Nel piccolo i Link non arrivano: il lucchetto passa dal tocco sul widget.
        .widgetURL(URL(string: locked ? "talky://pro" : "talky://radio"))
    }

    private var onAirMark: some View {
        HStack(spacing: 4) {
            Circle().fill(TalkyDial.color(.open)).frame(width: 6, height: 6)
            Text(String(localized: "w_onair_live"))
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    /// Pro: quattro tasti nel medio, otto nel grande, due per riga.
    private func grid(interactive: Bool) -> some View {
        let cards = Array(entry.presets.prefix(family == .systemLarge ? 8 : 4))
        let rows = stride(from: 0, to: cards.count, by: 2).map { Array(cards[$0 ..< min($0 + 2, cards.count)]) }
        return VStack(alignment: .leading, spacing: 6) {
            header
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(rows.indices, id: \.self) { index in
                    GridRow {
                        ForEach(rows[index]) { tile($0, interactive: interactive) }
                        if rows[index].count == 1 { Color.clear }
                    }
                }
            }
            // Con poche preferite i tasti restano in alto, della loro misura.
            Spacer(minLength: 0)
        }
    }

    private func tile(_ card: PresetCard, interactive: Bool) -> some View {
        let playing = entry.playingID == card.id
        return HStack(spacing: 7) {
            Text(card.flag)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 1) {
                Text(card.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(card.dial)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(TalkyDial.amber.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            if interactive {
                RadioKey(card: card, playing: playing, locked: card.locked(hasPro: entry.hasPro, at: entry.date), size: 26)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, family == .systemLarge ? 14 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(playing ? 0.14 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(TalkyDial.amber.opacity(playing ? 0.8 : 0), lineWidth: 1))
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            Image(systemName: "heart")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(TalkyDial.amber)
            Text(String(localized: "w_presets_empty"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(4)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "talky://radio"))
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct PresetsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RadioShelf.presetsKind, provider: ShelfProvider()) { entry in
            PresetsView(entry: entry)
        }
        .configurationDisplayName("w_presets_name")
        .description("w_presets_about")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
