//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - PresetIntents+App.swift
//  WalkieTalkie
//
//  Cosa fanno sull'iPhone i tasti dei widget radio dichiarati in
//  Shared/WidgetLink/PresetIntents.swift. Girano qui, nel processo dell'app,
//  anche quando il sistema la lancia in background per l'occasione.

import AppIntents

@available(iOS 17.0, *)
extension PlayPresetIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        let radio = RadioManager.shared
        // Il catalogo intero e non le sole stazioni attive: se una preferita
        // e' a riposo dopo un errore, chi la tocca dal widget vuole riprovarla.
        if let station = radio.catalog.first(where: { $0.id == stationID }) {
            radio.playFromWidget(station)
        }
        return .result()
    }
}

@available(iOS 17.0, *)
extension StopRadioIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        RadioManager.shared.stopRadio()
        return .result()
    }
}

@available(iOS 17.0, *)
extension PlayFavoriteRadioIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        guard UserDefaults.standard.bool(forKey: "fastboot_isProUser") else {
            // Senza Pro: l'app viene avanti sulla paywall. Se il controllo
            // mostrava ancora la radio, era indietro sullo stato Pro e si ricarica.
            RadioShelf.reloadEverything()
            let openPaywall = { @MainActor in
                if let pro = URL(string: "talky://pro") { LiveActivityDeepLink.handle(pro) }
            }
            if #available(iOS 26.0, *) {
                try await continueInForeground(alwaysConfirm: false)
                openPaywall()
            } else {
                throw needsToContinueInForegroundError(continuation: openPaywall)
            }
            return .result()
        }
        let radio = RadioManager.shared
        radio.playFromWidget(radio.presetStations.first ?? radio.resumeStation)
        return .result()
    }
}

// Prima di iOS 26 l'unico modo di portare avanti l'app da un intent: serve al
// tocco senza Pro, che deve arrivare alla paywall invece di non fare niente.
// Solo qui, nell'app: alle estensioni il protocollo non e' concesso.
@available(iOS 17.0, *)
extension PlayFavoriteRadioIntent: ForegroundContinuableIntent {}
