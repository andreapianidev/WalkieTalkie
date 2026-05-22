//
//  LiveActivityDeepLink.swift
//  Talky
//
//  Parses talky:// URLs emitted by Live Activity Link buttons on iOS 16.x
//  (where interactive App Intents are unavailable). The widget bundles
//  buttons as Link(destination: talky://radio/<action>) and the app handles
//  them in .onOpenURL → here.
//

import Foundation

enum LiveActivityDeepLink {
    static func handle(_ url: URL) {
        // Scheme è case-insensitive per RFC ma alcuni opener esterni passano
        // "Talky://": normalizziamo. Il path può finire con uno slash residuo
        // ("/playpause/") quando il sistema canonicalizza l'URL — strippiamo.
        guard let scheme = url.scheme?.lowercased(), scheme == "talky" else { return }
        let host = (url.host ?? "").lowercased()
        var path = url.path.lowercased()
        if path.hasSuffix("/") { path.removeLast() }
        Logger.shared.logInfo("Live Activity deep link: \(host)\(path)")

        switch (host, path) {
        case ("radio", "/playpause"):
            NotificationCenter.default.post(name: .talkyRadioTogglePlayPause, object: nil)
        case ("radio", "/next"):
            NotificationCenter.default.post(name: .talkyRadioNextStation, object: nil)
        case ("radio", "/prev"):
            NotificationCenter.default.post(name: .talkyRadioPreviousStation, object: nil)
        case ("radio", _), ("walkie", _):
            // Tapping the activity body (no specific action) — just opens the app.
            break
        default:
            Logger.shared.logWarning("Unrecognised Live Activity deep link: \(url)")
        }
    }
}
