//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - TalkyWatchWidgets.swift
//  TalkyWatchWidgets
//
//  La complicazione di Talky sul quadrante: Kp e banda migliore adesso, dagli
//  stessi dati NOAA e dalle stesse regole dei widget dell'iPhone
//  (BandConditions). Talky Pro, come la propagazione sull'iPhone.

import SwiftUI
import WidgetKit

@main
struct TalkyWatchWidgets: WidgetBundle {
    var body: some Widget {
        BandComplication()
    }
}

struct WristBandProvider: TimelineProvider {
    func placeholder(in context: Context) -> BandConditions { .preview }

    func getSnapshot(in context: Context, completion: @escaping (BandConditions) -> Void) {
        completion(.preview)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BandConditions>) -> Void) {
        Task { completion(await bandTimeline(proOnly: true)) }
    }
}

struct BandComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TalkyWatchBands", provider: WristBandProvider()) { entry in
            BandFace(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName(Text("ww_name", tableName: "WatchWidgets"))
        .description(Text("ww_about", tableName: "WatchWidgets"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct BandFace: View {
    @Environment(\.widgetFamily) private var family
    let entry: BandConditions

    private var kp: Double? { entry.hasPro ? entry.report?.kp : nil }
    private var kpText: String { kp.map { String(format: "%.1f", $0) } ?? "--" }
    private var best: ShortwaveBand? { entry.hasPro ? entry.bestBand : nil }

    var body: some View {
        switch family {
        case .accessoryCircular:
            if entry.hasPro {
                Gauge(value: min(kp ?? 0, 9), in: 0 ... 9) {
                    Text("Kp")
                } currentValueLabel: {
                    Text(kpText)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(TalkyDial.color((kp ?? 0) >= 5 ? .closed : .open))
            } else {
                Image(systemName: "lock.fill")
            }
        case .accessoryCorner:
            Image(systemName: entry.hasPro ? "antenna.radiowaves.left.and.right" : "lock.fill")
                .font(.title3)
                .widgetLabel(entry.hasPro ? "Kp \(kpText) · \(best?.name ?? "--")" : "Talky Pro")
        case .accessoryInline:
            Text(entry.hasPro ? "Kp \(kpText) · \(best?.name ?? "--")" : "Talky Pro")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "w_prop_title"))
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(TalkyDial.amber)
                if entry.hasPro {
                    Text("Kp \(kpText) · SFI \(entry.report.map { "\($0.solarFlux)" } ?? "--")")
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                    Text("\(String(localized: "w_best_now")): \(best?.name ?? "--")")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(TalkyDial.color(best.flatMap { entry.outlook($0) }))
                } else {
                    Label("Talky Pro", systemImage: "lock.fill")
                        .font(.footnote)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
