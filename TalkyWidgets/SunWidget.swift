//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - SunWidget.swift
//  TalkyWidgets
//
//  Talky Pro: alba e tramonto dove si trova chi ascolta, che sono quello che
//  apre e chiude le bande, e quale banda va meglio adesso e dopo il prossimo
//  cambio. Il sole dal fuso orario (ApproximatePlace), le bande dalla NOAA.

import SwiftUI
import WidgetKit

@available(iOS 17.0, macOS 14.0, *)
struct SunView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BandConditions

    var body: some View {
        Group {
            #if os(iOS)
            if family == .accessoryRectangular {
                lockScreen
            } else {
                home
            }
            #else
            home
            #endif
        }
        .widgetURL(entry.hasPro ? URL(string: "talky://live/hf") : URL(string: "talky://pro"))
    }

    /// Il prossimo cambio: il tramonto di giorno, l'alba di notte.
    private var nextChange: Date? { entry.sunUp ? entry.sunset : entry.sunrise }

    private var home: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: entry.sunUp ? "sunset.fill" : "sunrise.fill")
                        .foregroundStyle(TalkyDial.amber)
                    Text(String(localized: entry.sunUp ? "w_sunset" : "w_sunrise"))
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(TalkyDial.amber)
                        .lineLimit(1)
                }
                Text(nextChange.map { $0.formatted(date: .omitted, time: .shortened) } ?? "--")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let nextChange {
                    Text(nextChange, style: .relative)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(String(localized: "w_best_now"))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                bandLine(entry.bestBand, outlook: entry.bestBand.flatMap { entry.outlook($0) })
            }
            if family == .systemMedium {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: entry.sunUp ? "w_after_sunset" : "w_after_sunrise"))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    ForEach(ShortwaveBand.allCases, id: \.self) { band in
                        bandLine(band, outlook: entry.outlookAfterSwitch(band))
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 10) {
                        sunTime("sunrise", entry.sunrise)
                        sunTime("sunset", entry.sunset)
                    }
                }
            }
        }
        .modifier(ProLock(locked: !entry.hasPro))
        .containerBackground(.black, for: .widget)
    }

    private func bandLine(_ band: ShortwaveBand?, outlook: BandOutlook?) -> some View {
        HStack(spacing: 5) {
            Circle().fill(TalkyDial.color(outlook)).frame(width: 7, height: 7)
            Text(band?.name ?? "--")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text(TalkyDial.text(outlook))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TalkyDial.color(outlook))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func sunTime(_ symbol: String, _ date: Date?) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9))
                .foregroundStyle(TalkyDial.amber)
            Text(date.map { $0.formatted(date: .omitted, time: .shortened) } ?? "--")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    #if os(iOS)
    private var lockScreen: some View {
        Group {
            if entry.hasPro {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(Image(systemName: entry.sunUp ? "sunset.fill" : "sunrise.fill")) \(nextChange.map { $0.formatted(date: .omitted, time: .shortened) } ?? "--")")
                        .font(.headline)
                        .widgetAccentable()
                    Text("\(String(localized: "w_best_now")): \(entry.bestBand?.name ?? "--")")
                        .font(.caption)
                    Text("\(String(localized: entry.sunUp ? "w_after_sunset" : "w_after_sunrise")): \(ShortwaveBand.allCases.first { entry.outlookAfterSwitch($0) == .open }?.name ?? "--")")
                        .font(.caption2)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            } else {
                Label("Talky Pro", systemImage: "lock.fill")
            }
        }
        .containerBackground(.clear, for: .widget)
    }
    #endif
}

@available(iOS 17.0, macOS 14.0, *)
struct SunWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TalkySun", provider: PropagationProvider()) { entry in
            SunView(entry: entry)
        }
        .configurationDisplayName("w_sun_name")
        .description("w_sun_about")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}
