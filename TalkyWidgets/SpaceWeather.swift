//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - SpaceWeather.swift
//  TalkyWidgets
//
//  Il meteo spaziale che decide se una banda HF e' aperta: flusso solare a
//  10,7 cm, indice Kp e blackout radio, dai dati pubblici della NOAA (Space
//  Weather Prediction Center), senza chiavi. Da questi e dall'altezza del
//  sole dove si trova chi guarda, una stima banda per banda.

import Foundation

struct SpaceReport: Sendable {
    /// Flusso solare a 10,7 cm (SFI): sopra 120 le bande alte si aprono di giorno.
    var solarFlux: Int
    /// Indice Kp planetario piu' recente, 0...9: oltre 5 c'e' tempesta geomagnetica.
    var kp: Double
    /// Gli ultimi otto Kp a tre ore: le ultime 24 ore.
    var kpDay: [Double]
    /// Scala R dei blackout radio, 0...5.
    var blackout: Int
    var issued: Date

    static let sample = SpaceReport(solarFlux: 128, kp: 2.3, kpDay: [1.7, 2.0, 2.3, 1.3, 1.0, 2.0, 2.7, 2.3],
                                    blackout: 0, issued: .now)

    private static let base = "https://services.swpc.noaa.gov/products/"

    static func fetch() async -> SpaceReport? {
        async let flux = json("summary/10cm-flux.json")
        async let kpRows = json("noaa-planetary-k-index.json")
        async let scales = json("noaa-scales.json")

        guard let fluxRow = (await flux as? [[String: Any]])?.last,
              let sfi = (fluxRow["flux"] as? NSNumber)?.intValue ?? Int(fluxRow["flux"] as? String ?? ""),
              let rows = await kpRows as? [[String: Any]] else { return nil }
        let kps = rows.compactMap { ($0["Kp"] as? NSNumber)?.doubleValue }
        guard let latest = kps.last else { return nil }

        var blackout = 0
        if let now = (await scales as? [String: Any])?["0"] as? [String: Any],
           let r = now["R"] as? [String: Any], let scale = r["Scale"] as? String {
            blackout = Int(scale) ?? 0
        }
        return SpaceReport(solarFlux: sfi, kp: latest, kpDay: Array(kps.suffix(8)), blackout: blackout, issued: .now)
    }

    private static func json(_ path: String) async -> Any? {
        guard let url = URL(string: base + path) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Talky", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}

/// Come si sente una banda adesso.
enum BandOutlook: Int, Comparable, Sendable {
    case closed, weak, open

    static func < (a: BandOutlook, b: BandOutlook) -> Bool { a.rawValue < b.rawValue }

    var lower: BandOutlook { BandOutlook(rawValue: max(0, rawValue - 1)) ?? .closed }

    var labelKey: String {
        switch self {
        case .open: "w_open"
        case .weak: "w_weak"
        case .closed: "w_closed"
        }
    }
}

/// Le bande che Talky ascolta, dalla piu' alta: la CB sta a 11 m, accanto ai 10 m.
enum ShortwaveBand: String, CaseIterable, Sendable {
    case m11, m20, m40, m80

    var name: String {
        switch self {
        case .m11: "11 m CB"
        case .m20: "20 m"
        case .m40: "40 m"
        case .m80: "80 m"
        }
    }

    /// Regole da manuale del radioascolto, non una previsione: lo strato F2
    /// regge le bande alte solo di giorno e con il sole attivo, le basse si
    /// aprono la notte quando lo strato D sparisce. Una tempesta (Kp alto) e un
    /// blackout di giorno abbassano tutto.
    func outlook(_ report: SpaceReport, sunUp: Bool, month: Int, southern: Bool) -> BandOutlook {
        let sfi = report.solarFlux
        var state: BandOutlook
        switch self {
        case .m11:
            if sunUp {
                state = sfi >= 120 ? .open : sfi >= 95 ? .weak : .closed
                // Strato E sporadico d'estate: aperture brevi anche col sole quieto.
                let esSeason = southern ? [11, 12, 1, 2].contains(month) : (5 ... 8).contains(month)
                if esSeason, state == .closed { state = .weak }
            } else {
                state = .closed
            }
        case .m20:
            state = sunUp ? (sfi >= 75 ? .open : .weak) : (sfi >= 130 ? .weak : .closed)
        case .m40:
            // Di giorno si sente vicino, di notte arriva da lontano.
            state = sunUp ? .weak : .open
        case .m80:
            state = sunUp ? .closed : .open
        }
        if report.kp >= 7 { return .closed }
        if report.kp >= 5 { state = state.lower }
        if report.blackout >= 2, sunUp, self != .m80 { state = state.lower }
        return state
    }
}

/// Altezza del sole sull'orizzonte, in gradi (formule della NOAA, abbastanza
/// per dire giorno o notte).
enum SunPosition {
    static func elevation(latitude: Double, longitude: Double, at date: Date) -> Double {
        let n = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0
        let rad = Double.pi / 180
        let meanLongitude = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let anomaly = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360) * rad
        let eclipticLongitude = (meanLongitude + 1.915 * sin(anomaly) + 0.020 * sin(2 * anomaly)) * rad
        let obliquity = (23.439 - 0.0000004 * n) * rad
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let ascension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))
        let sidereal = (280.46061837 + 360.98564736629 * n).truncatingRemainder(dividingBy: 360)
        let hourAngle = (sidereal + longitude) * rad - ascension
        let lat = latitude * rad
        return asin(sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)) / rad
    }
}
