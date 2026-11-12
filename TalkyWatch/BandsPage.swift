//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - BandsPage.swift
//  TalkyWatch
//
//  Le stesse condizioni delle bande dei widget dell'iPhone (TalkyWidgets),
//  calcolate sul Watch dai dati NOAA e dal fuso orario: Kp, flusso solare e
//  quali bande sono aperte adesso. Con Talky Pro, come sull'iPhone.

import SwiftUI

struct BandsPage: View {
    @EnvironmentObject private var phone: PhoneLink
    @State private var conditions: BandConditions?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "w_prop_title"))
                        .font(.system(.caption, design: .monospaced).weight(.heavy))
                        .foregroundStyle(TalkyDial.amber)
                    Spacer()
                    if let conditions {
                        Image(systemName: conditions.sunUp ? "sun.max.fill" : "moon.stars.fill")
                            .foregroundStyle(conditions.sunUp ? TalkyDial.amber : .white.opacity(0.8))
                    }
                }
                if let conditions {
                    if !conditions.hasPro {
                        Label("wr_pro_bands".wrist, systemImage: "lock.fill")
                            .font(.footnote)
                            .foregroundStyle(TalkyDial.amber)
                    } else if let report = conditions.report {
                        readings(report, conditions)
                    } else {
                        Text("wr_noaa".wrist).font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                }
            }
            // A destra c'e' l'indicatore delle pagine: il sole non ci va sotto.
            .padding(.leading, 6)
            .padding(.trailing, 14)
        }
        .task(id: phone.phonePro) { await load() }
    }

    private func readings(_ report: SpaceReport, _ c: BandConditions) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Kp").font(.system(.footnote, design: .monospaced)).foregroundStyle(.secondary)
                Text(String(format: "%.1f", report.kp))
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(report.kp >= 5 ? TalkyDial.color(.closed) : .white)
                Spacer()
                Text("SFI \(report.solarFlux)")
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
            }
            if let best = c.bestBand {
                // Su una riga sola: andando a capo spingeva gli 80 m fuori schermo.
                Text("\("wr_best".wrist): \(best.name)")
                    .font(.system(.footnote, design: .monospaced).weight(.bold))
                    .foregroundStyle(TalkyDial.color(.open))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            ForEach(ShortwaveBand.allCases, id: \.self) { band in
                HStack(spacing: 6) {
                    Circle().fill(TalkyDial.color(c.outlook(band))).frame(width: 8, height: 8)
                    Text(band.name).font(.system(.footnote, design: .monospaced))
                    Spacer()
                    Text(TalkyDial.text(c.outlook(band)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(String(format: String(localized: "w_source"), report.issued.formatted(date: .omitted, time: .shortened)))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func load() async {
        let pro = phone.phonePro ? true : await TalkyPro.isActive()
        var report: SpaceReport?
        if pro {
            report = await SpaceReport.fetch()
            if let report { SpaceReport.save(report) } else { report = SpaceReport.saved() }
        }
        conditions = .make(report: report, hasPro: pro)
    }
}
