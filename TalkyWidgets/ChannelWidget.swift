//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - ChannelWidget.swift
//  TalkyWidgets
//
//  Widget gratuito: il canale preferito sul display del walkie, con la
//  banda aperta o chiusa adesso. Un tocco apre Talky gia' sintonizzato.

import AppIntents
import SwiftUI
import WidgetKit

/// I canali che si possono mettere sul widget.
@available(iOS 17.0, *)
enum FavoriteChannel: String, AppEnum {
    case cb19, cb9, dx27555, shannonVolmet, ham40, ham20, wwv10

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "w_channel_param"
    static let caseDisplayRepresentations: [FavoriteChannel: DisplayRepresentation] = [
        .cb19: "CB 19",
        .cb9: "CB 9",
        .dx27555: "DX 27.555",
        .shannonVolmet: "Shannon VOLMET",
        .ham40: "40 m SSB",
        .ham20: "20 m SSB",
        .wwv10: "WWV 10 MHz"
    ]

    var band: String {
        switch self {
        case .cb19, .cb9, .dx27555: "CB"
        default: "HF"
        }
    }

    /// Quello che il display mostra in grande.
    var dial: String {
        switch self {
        case .cb19: "CH 19"
        case .cb9: "CH 9"
        case .dx27555: "27.555"
        case .shannonVolmet: "5.505"
        case .ham40: "7.150"
        case .ham20: "14.250"
        case .wwv10: "10.000"
        }
    }

    var detail: String {
        switch self {
        case .cb19: "27.185 AM"
        case .cb9: "27.065 AM"
        case .dx27555: "MHz USB · DX"
        case .shannonVolmet: "MHz USB · VOLMET"
        case .ham40: "MHz LSB"
        case .ham20: "MHz USB"
        case .wwv10: "MHz AM · WWV"
        }
    }

    var shortwave: ShortwaveBand {
        switch self {
        case .cb19, .cb9, .dx27555: .m11
        case .ham20: .m20
        case .ham40: .m40
        // VOLMET a 5,5 MHz e WWV a 10 MHz si comportano come le bande vicine.
        case .shannonVolmet: .m80
        case .wwv10: .m40
        }
    }

    /// Il collegamento che l'app capisce: banda e frequenza o canale HF.
    var link: URL? {
        switch self {
        case .cb19: URL(string: "talky://live/cb?hz=27185000")
        case .cb9: URL(string: "talky://live/cb?hz=27065000")
        case .dx27555: URL(string: "talky://live/cb?hz=27555000")
        case .shannonVolmet: URL(string: "talky://live/hf?id=shannon-volmet")
        case .ham40: URL(string: "talky://live/hf?id=ham-40")
        case .ham20: URL(string: "talky://live/hf?id=ham-20")
        case .wwv10: URL(string: "talky://live/hf?id=wwv-10")
        }
    }
}

@available(iOS 17.0, *)
struct ChannelChoice: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "w_channel_name"
    static let description = IntentDescription("w_channel_about")

    @Parameter(title: "w_channel_param", default: .cb19)
    var channel: FavoriteChannel
}

@available(iOS 17.0, *)
struct ChannelEntry: TimelineEntry {
    let date: Date
    let channel: FavoriteChannel
    let conditions: BandConditions
}

@available(iOS 17.0, *)
struct ChannelProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ChannelEntry {
        ChannelEntry(date: .now, channel: .cb19, conditions: .preview)
    }

    func snapshot(for configuration: ChannelChoice, in context: Context) async -> ChannelEntry {
        ChannelEntry(date: .now, channel: configuration.channel, conditions: .preview)
    }

    func timeline(for configuration: ChannelChoice, in context: Context) async -> Timeline<ChannelEntry> {
        let base = await bandTimeline(proOnly: false)
        let entries = base.entries.map { ChannelEntry(date: $0.date, channel: configuration.channel, conditions: $0) }
        return Timeline(entries: entries, policy: base.policy)
    }
}

@available(iOS 17.0, *)
struct ChannelWidgetView: View {
    let entry: ChannelEntry

    var body: some View {
        let outlook = entry.conditions.outlook(entry.channel.shortwave)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.channel.band)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(TalkyDial.amber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(TalkyDial.amber, lineWidth: 1))
                Spacer()
                Text("RX")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
            Text(entry.channel.dial)
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundStyle(TalkyDial.amber)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(entry.channel.detail)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(TalkyDial.amber.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Circle()
                    .fill(TalkyDial.color(outlook))
                    .frame(width: 7, height: 7)
                Text(TalkyDial.text(outlook))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text(entry.channel.shortwave.name)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .widgetURL(entry.channel.link)
        .containerBackground(.black, for: .widget)
    }
}

@available(iOS 17.0, *)
struct ChannelWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TalkyChannel", intent: ChannelChoice.self, provider: ChannelProvider()) { entry in
            ChannelWidgetView(entry: entry)
        }
        .configurationDisplayName("w_channel_name")
        .description("w_channel_about")
        .supportedFamilies([.systemSmall])
    }
}
