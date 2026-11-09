//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - OnAirWidget.swift
//  TalkyWidgets
//
//  Gratuito: la stazione in onda e il brano che sta mandando, con lo stop.
//  A radio spenta resta l'ultima stazione ascoltata, con il play per
//  riaccenderla. Il titolo c'e' solo se lo stream lo trasmette.

import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 17.0, macOS 14.0, *)
struct OnAirView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShelfEntry

    var body: some View {
        Group {
            if let onAir = entry.onAir {
                #if os(iOS)
                if family == .accessoryRectangular {
                    lockScreen(onAir)
                } else {
                    home(onAir)
                }
                #else
                home(onAir)
                #endif
            } else {
                never
            }
        }
        .containerBackground(family == .systemSmall || family == .systemMedium ? Color.black : Color.clear, for: .widget)
    }

    private func locked(_ onAir: OnAirCard) -> Bool {
        !onAir.playing && onAir.station.locked(hasPro: entry.hasPro, at: entry.date)
    }

    private func status(_ onAir: OnAirCard) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(onAir.playing ? TalkyDial.color(.open) : .gray)
                .frame(width: 7, height: 7)
            Text(String(localized: onAir.playing ? "w_onair_live" : "w_onair_off"))
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(TalkyDial.amber)
                .lineLimit(1)
        }
    }

    /// Il brano se c'e'; se la stazione non lo manda lo si dice, e a radio
    /// spenta si ricorda che e' l'ultima ascoltata.
    private func caption(_ onAir: OnAirCard) -> Text {
        if let title = onAir.title, onAir.playing {
            return Text(title).foregroundStyle(.white)
        }
        return Text(String(localized: onAir.playing ? "w_onair_no_title" : "w_onair_last"))
            .foregroundStyle(.white.opacity(0.55))
    }

    private func home(_ onAir: OnAirCard) -> some View {
        let medium = family == .systemMedium
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                status(onAir)
                Spacer(minLength: 0)
                Text("\(onAir.station.flag) \(onAir.station.name)")
                    .font(.system(size: medium ? 15 : 13, weight: .semibold))
                    .foregroundStyle(TalkyDial.amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                caption(onAir)
                    .font(.system(size: medium ? 17 : 14, weight: .bold, design: .rounded))
                    .lineLimit(medium ? 3 : 2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if !medium {
                    HStack {
                        Text(onAir.station.dial)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        RadioKey(card: onAir.station, playing: onAir.playing, locked: locked(onAir), size: 32)
                    }
                } else {
                    Text(onAir.station.dial)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            if medium {
                RadioKey(card: onAir.station, playing: onAir.playing, locked: locked(onAir), size: 54)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Nel piccolo i Link non arrivano: il lucchetto passa dal tocco sul widget.
        .widgetURL(URL(string: locked(onAir) ? "talky://pro" : "talky://radio"))
    }

    #if os(iOS)
    private func lockScreen(_ onAir: OnAirCard) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(Image(systemName: onAir.playing ? "dot.radiowaves.left.and.right" : "radio")) \(onAir.station.name)")
                .font(.headline)
                .widgetAccentable()
            caption(onAir)
                .font(.caption)
                .lineLimit(2)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "talky://radio"))
    }
    #endif

    private var never: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "w_onair_off"))
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(TalkyDial.amber)
            Spacer(minLength: 0)
            Text(String(localized: "w_onair_never"))
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
struct OnAirWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RadioShelf.onAirKind, provider: ShelfProvider()) { entry in
            OnAirView(entry: entry)
        }
        .configurationDisplayName("w_onair_name")
        .description("w_onair_about")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}
