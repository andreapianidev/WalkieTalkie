//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - ApproximatePlace.swift
//  Talky
//
//  La posizione approssimativa di chi usa Talky, senza permessi: serve all'app
//  per il ricevitore piu' vicino e ai widget per sapere se da li' e' giorno.

import Foundation

/// Dove si trova, piu' o meno, chi ascolta, senza chiedere la posizione:
/// il capoluogo del suo fuso orario (Atlantic/Canary e' Las Palmas, non la
/// Francia che dava la sola differenza da UTC). Serve solo a scegliere un
/// ricevitore vicino.
@available(iOS 16.0, macOS 13.0, *)
nonisolated enum ApproximatePlace {
    static var current: (latitude: Double, longitude: Double) {
        let tz = TimeZone.current
        if let spot = zoneSpots[tz.identifier] { return spot }
        // Fuso fuori tabella (GMT+3 e simili): dalla differenza da UTC e dal paese.
        let offset = Double(tz.secondsFromGMT() - Int(tz.daylightSavingTimeOffset())) / 3600
        let region = Locale.current.region?.identifier ?? ""
        let south: Set<String> = ["AU", "NZ", "BR", "AR", "CL", "ZA", "UY", "PY", "BO", "PE"]
        let tropics: Set<String> = ["IN", "ID", "TH", "VN", "PH", "MY", "SG", "NG", "KE", "MX", "CO", "VE", "EC", "GH", "SA", "AE"]
        let latitude = south.contains(region) ? -30.0 : tropics.contains(region) ? 15.0 : 45.0
        return (latitude, offset * 15)
    }

    /// TimeZoneSpots.txt: `Europe/Rome 41.90 12.48`, una riga per fuso.
    private static let zoneSpots: [String: (latitude: Double, longitude: Double)] = {
        guard let url = Bundle.main.url(forResource: "TimeZoneSpots", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var spots: [String: (latitude: Double, longitude: Double)] = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let f = line.split(separator: " ")
            guard f.count == 3, let lat = Double(f[1]), let lon = Double(f[2]) else { continue }
            spots[String(f[0])] = (lat, lon)
        }
        return spots
    }()
}
