//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - PropagationWidget.swift
//  TalkyWidgets
//
//  Talky Pro: le condizioni di tutte le bande che Talky ascolta, con i numeri
//  del sole e, nel formato grande, il Kp delle ultime 24 ore.

import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct PropagationProvider: TimelineProvider {
    func placeholder(in context: Context) -> BandConditions { .preview }

    func getSnapshot(in context: Context, completion: @escaping (BandConditions) -> Void) {
        completion(.preview)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BandConditions>) -> Void) {
        Task { completion(await bandTimeline(proOnly: true)) }
    }
}

@available(iOS 17.0, *)
struct PropagationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BandConditions

    var body: some View {
        if family == .systemSmall {
            small
                .modifier(ProLock(locked: !entry.hasPro))
                .widgetURL(entry.hasPro ? URL(string: "talky://live/hf") : URL(string: "talky://pro"))
                .containerBackground(.black, for: .widget)
        } else {
            full
        }
    }

    /// Il piccolo: il Kp in grande, flusso e brillamento, le quattro bande a pallini.
    private var small: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(String(localized: "w_prop_title"))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(TalkyDial.amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Image(systemName: entry.sunUp ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(entry.sunUp ? TalkyDial.amber : .white.opacity(0.8))
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Kp")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Text(entry.report.map { String(format: "%.1f", $0.kp) } ?? "--")
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle((entry.report?.kp ?? 0) >= 5 ? TalkyDial.color(.closed) : .white)
            }
            Text("SFI \(entry.report.map { "\($0.solarFlux)" } ?? "--")  X \(entry.report?.flareClass ?? "--")")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 4) {
                ForEach(ShortwaveBand.allCases, id: \.self) { band in
                    HStack(spacing: 4) {
                        Circle().fill(TalkyDial.color(entry.outlook(band))).frame(width: 7, height: 7)
                        Text(band == .m11 ? "11 m" : band.name)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var full: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
            header
            figures
            VStack(spacing: family == .systemLarge ? 7 : 4) {
                ForEach(ShortwaveBand.allCases, id: \.self) { band in
                    row(band)
                }
            }
            if family == .systemLarge {
                kpChart
                Spacer(minLength: 0)
                Text(String(format: String(localized: "w_source"), entry.date.formatted(date: .omitted, time: .shortened)))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .modifier(ProLock(locked: !entry.hasPro))
        .widgetURL(entry.hasPro ? URL(string: "talky://live/hf") : URL(string: "talky://pro"))
        .containerBackground(.black, for: .widget)
    }

    private var header: some View {
        HStack {
            Text(String(localized: "w_prop_title"))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(TalkyDial.amber)
            Spacer()
            Image(systemName: entry.sunUp ? "sun.max.fill" : "moon.stars.fill")
                .font(.system(size: 11))
                .foregroundStyle(entry.sunUp ? TalkyDial.amber : .white.opacity(0.8))
            Text(String(localized: entry.sunUp ? "w_day" : "w_night"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var figures: some View {
        HStack(spacing: 12) {
            figure("SFI", entry.report.map { "\($0.solarFlux)" })
            figure("Kp", entry.report.map { String(format: "%.1f", $0.kp) }, alarm: (entry.report?.kp ?? 0) >= 5)
            figure("R", entry.report.map { "\($0.blackout)" }, alarm: (entry.report?.blackout ?? 0) >= 2)
            figure("G", entry.report.map { "\($0.storm)" }, alarm: (entry.report?.storm ?? 0) >= 2)
            if family == .systemLarge {
                figure("X", entry.report?.flareClass, alarm: (entry.report?.xray ?? 0) >= 1e-5)
            }
            Spacer(minLength: 0)
        }
    }

    private func figure(_ name: String, _ value: String?, alarm: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(name)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            Text(value ?? "--")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(alarm ? TalkyDial.color(.closed) : .white)
        }
    }

    private func row(_ band: ShortwaveBand) -> some View {
        let outlook = entry.outlook(band)
        return HStack(spacing: 8) {
            Text(band.name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 62, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(TalkyDial.color(outlook))
                        .frame(width: geo.size.width * CGFloat((outlook?.rawValue ?? -1) + 1) / 3)
                }
            }
            .frame(height: 6)
            Text(TalkyDial.text(outlook))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TalkyDial.color(outlook))
                .frame(width: 56, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// Il Kp a tre ore delle ultime 24 e la previsione NOAA delle prossime 24,
    /// piu' tenue: verde quieto, arancio agitato, rosso tempesta.
    private var kpChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "w_kp_day"))
                Spacer()
                Text(String(localized: "w_kp_next"))
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.55))
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array((entry.report?.kpDay ?? []).enumerated()), id: \.offset) { _, kp in
                    kpBar(kp, forecast: false)
                }
                Rectangle().fill(.white.opacity(0.5)).frame(width: 1, height: 46)
                ForEach(Array((entry.report?.kpNext ?? []).enumerated()), id: \.offset) { _, kp in
                    kpBar(kp, forecast: true)
                }
            }
            .frame(height: 46, alignment: .bottom)
        }
    }

    private func kpBar(_ kp: Double, forecast: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(kp >= 5 ? TalkyDial.color(.closed) : kp >= 4 ? TalkyDial.color(.weak) : TalkyDial.color(.open))
            .opacity(forecast ? 0.45 : 1)
            .frame(height: max(3, CGFloat(kp) / 9 * 46))
            .frame(maxWidth: .infinity)
    }
}

@available(iOS 17.0, *)
struct PropagationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TalkyPropagation", provider: PropagationProvider()) { entry in
            PropagationView(entry: entry)
        }
        .configurationDisplayName("w_prop_name")
        .description("w_prop_about")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Schermata di blocco

@available(iOS 17.0, *)
struct BandLockView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BandConditions

    var body: some View {
        Group {
            if !entry.hasPro {
                Label("Talky Pro", systemImage: "lock.fill")
                    .widgetURL(URL(string: "talky://pro"))
            } else {
                switch family {
                case .accessoryCircular:
                    Gauge(value: min(9, entry.report?.kp ?? 0), in: 0 ... 9) {
                        Text("Kp")
                    } currentValueLabel: {
                        Text(entry.report.map { String(format: "%.0f", $0.kp) } ?? "-")
                    }
                    .gaugeStyle(.accessoryCircular)
                case .accessoryInline:
                    Text("11 m \(TalkyDial.text(entry.outlook(.m11))) · SFI \(entry.report.map { "\($0.solarFlux)" } ?? "--")")
                default:
                    VStack(alignment: .leading, spacing: 1) {
                        Text("11 m CB · \(TalkyDial.text(entry.outlook(.m11)))")
                            .font(.headline)
                            .widgetAccentable()
                        Text("20 m \(TalkyDial.text(entry.outlook(.m20))) · 40 m \(TalkyDial.text(entry.outlook(.m40)))")
                            .font(.caption)
                        Text("SFI \(entry.report.map { "\($0.solarFlux)" } ?? "--") · Kp \(entry.report.map { String(format: "%.1f", $0.kp) } ?? "--")")
                            .font(.caption2)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

@available(iOS 17.0, *)
struct BandLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TalkyBandLock", provider: PropagationProvider()) { entry in
            BandLockView(entry: entry)
        }
        .configurationDisplayName("w_lock_name")
        .description("w_lock_about")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
