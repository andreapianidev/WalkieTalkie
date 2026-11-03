//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - BandConditions.swift
//  TalkyWidgets
//
//  Il dato che tutti i widget di Talky mostrano: le condizioni delle bande
//  adesso, da dove si trova chi guarda. Si aggiorna ogni ora; la NOAA
//  pubblica il Kp ogni tre ore e il flusso solare tre volte al giorno.

import StoreKit
import SwiftUI
import WidgetKit

struct BandConditions: TimelineEntry {
    let date: Date
    /// Nil quando la NOAA non ha risposto: il widget lo dice invece di inventare.
    let report: SpaceReport?
    let sunUp: Bool
    let month: Int
    let southern: Bool
    let hasPro: Bool
    /// Prossima alba e prossimo tramonto dove si trova chi guarda.
    let sunrise: Date?
    let sunset: Date?

    func outlook(_ band: ShortwaveBand) -> BandOutlook? {
        report.map { band.outlook($0, sunUp: sunUp, month: month, southern: southern) }
    }

    static func make(report: SpaceReport?, hasPro: Bool, at date: Date = .now) -> BandConditions {
        let place = ApproximatePlace.current
        let sun = SunPosition.elevation(latitude: place.latitude, longitude: place.longitude, at: date)
        let events = SunPosition.nextEvents(latitude: place.latitude, longitude: place.longitude, after: date)
        return BandConditions(date: date, report: report, sunUp: sun > -3,
                              month: Calendar.current.component(.month, from: date),
                              southern: place.latitude < 0, hasPro: hasPro,
                              sunrise: events.rise, sunset: events.set)
    }

    /// La banda piu' alta aperta adesso: quella dove si sente piu' lontano.
    var bestBand: ShortwaveBand? {
        ShortwaveBand.allCases.first { outlook($0) == .open } ?? ShortwaveBand.allCases.first { outlook($0) == .weak }
    }

    /// Come staranno le bande dopo il prossimo cambio fra giorno e notte.
    func outlookAfterSwitch(_ band: ShortwaveBand) -> BandOutlook? {
        report.map { band.outlook($0, sunUp: !sunUp, month: month, southern: southern) }
    }

    static let preview = make(report: .sample, hasPro: true)
}

enum TalkyPro {
    /// Gli stessi prodotti di IAP/IAPProducts.swift nell'app: abbonamento
    /// settimanale, annuale e Talky Pro per sempre.
    private static let products: Set<String> = ["ProWeeklyWT", "ProAnnualWT", "app.immaginet.talky.pro.lifetime"]

    /// StoreKit risponde anche nell'estensione: il widget non aspetta che
    /// l'app venga aperta per sapere che l'abbonamento c'e'.
    static func isActive() async -> Bool {
        #if DEBUG
        // Come l'app in Debug: il collaudo vede i widget Pro senza acquisto.
        return true
        #else
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, products.contains(t.productID), t.revocationDate == nil {
                return true
            }
        }
        return false
        #endif
    }
}

/// Un'ora di validita' per ogni voce: abbastanza per seguire alba e tramonto.
func bandTimeline(proOnly: Bool) async -> Timeline<BandConditions> {
    async let report = SpaceReport.fetch()
    let pro = await TalkyPro.isActive()
    let now = Date()
    var fetched = (proOnly && !pro) ? nil : await report
    if let fresh = fetched { SpaceReport.save(fresh) } else if !(proOnly && !pro) { fetched = SpaceReport.saved() }
    let entries = (0 ..< 3).map { BandConditions.make(report: fetched, hasPro: pro, at: now.addingTimeInterval(Double($0) * 1200)) }
    return Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600)))
}

// MARK: aspetto comune

enum TalkyDial {
    static let amber = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let body = Color(red: 1.0, green: 0.84, blue: 0.0)

    static func color(_ outlook: BandOutlook?) -> Color {
        switch outlook {
        case .open: Color(red: 0.25, green: 0.85, blue: 0.35)
        case .weak: Color(red: 1.0, green: 0.62, blue: 0.1)
        case .closed: Color(red: 0.9, green: 0.25, blue: 0.2)
        case nil: .gray
        }
    }

    static func text(_ outlook: BandOutlook?) -> String {
        outlook.map { String(localized: String.LocalizationValue($0.labelKey)) } ?? "--"
    }
}

/// Bloccato senza Talky Pro: si vede la forma del widget, i numeri no.
struct ProLock: ViewModifier {
    let locked: Bool

    func body(content: Content) -> some View {
        if locked {
            content
                .redacted(reason: .placeholder)
                .overlay {
                    Label("Talky Pro", systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(TalkyDial.amber))
                }
                .widgetURL(URL(string: "talky://pro"))
        } else {
            content
        }
    }
}
