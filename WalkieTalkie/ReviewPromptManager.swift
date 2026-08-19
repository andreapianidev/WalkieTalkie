//creato da Andrea Piani - 05/08/26 - https://www.andreapiani.com - ReviewPromptManager.swift
//  WalkieTalkie
//

import Foundation
import StoreKit
import UIKit
import FirebaseAnalytics

/// Decide QUANDO chiedere la recensione, e soprattutto quando non chiederla.
///
/// Perché esiste: al 5 agosto 2026 Talky aveva 18 recensioni totali e 2,11 di
/// media, con 9 recensioni da una stella. Un campione così piccolo è dominato da
/// chi si è arrabbiato, perché chi è contento non recensisce mai spontaneamente.
/// Non c'era alcun punto nell'app in cui la recensione venisse chiesta: l'unica
/// voce che arrivava allo Store era quella di chi aveva un problema.
///
/// Il criterio è uno solo: **chiedere solo dopo che l'app ha dimostrato di
/// funzionare**. Non al lancio, non a tempo, non dopo N aperture — dopo una
/// conversazione vera, cioè almeno `minimumSuccessfulTransmissions` trasmissioni
/// completate mentre almeno un peer era connesso. Se il walkie non ha mai
/// funzionato per quell'utente, il prompt non parte: sarebbe un invito a
/// lasciare la stella che già ci manca.
///
/// Apple limita comunque il prompt a 3 volte per 365 giorni e può ignorarlo
/// del tutto; questo manager aggiunge i propri limiti sopra, non sotto.
/// Nessun `ObservableObject`: non c'è UI che lo osservi, e la conformance sotto
/// `@MainActor` richiederebbe un `objectWillChange` nonisolated per niente.
@MainActor
final class ReviewPromptManager {

    static let shared = ReviewPromptManager()

    // MARK: - Soglie

    /// Trasmissioni riuscite (con almeno un peer connesso) prima di poter chiedere.
    /// Tre e non una: la prima può essere fortunata, tre significano che la
    /// coppia di device si è trovata e ha retto.
    private let minimumSuccessfulTransmissions = 3

    /// Distanza minima fra due richieste, anche fra versioni diverse. Apple ne
    /// concede 3 all'anno: chiederle tutte a distanza di giorni le sprecherebbe.
    private let minimumIntervalBetweenPrompts: TimeInterval = 120 * 24 * 60 * 60

    // MARK: - Storage

    private enum Keys {
        static let successfulTransmissions = "review_successful_transmissions"
        static let lastPromptDate = "review_last_prompt_date"
        static let lastPromptVersion = "review_last_prompt_version"
    }

    private let defaults = UserDefaults.standard

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private init() {}

    // MARK: - Eventi

    /// Da chiamare quando una trasmissione si chiude AVENDO avuto almeno un peer
    /// connesso. `connectedPeerCount` a zero significa che l'utente ha premuto PTT
    /// nel vuoto: non è un successo e non deve contare.
    func recordTransmission(connectedPeerCount: Int) {
        guard connectedPeerCount > 0 else { return }
        let count = defaults.integer(forKey: Keys.successfulTransmissions) + 1
        defaults.set(count, forKey: Keys.successfulTransmissions)
        Logger.shared.logInfo("Trasmissioni riuscite con almeno un peer: \(count)")
        requestReviewIfAppropriate()
    }

    // MARK: - Decisione

    private var isAppropriate: Bool {
        guard defaults.integer(forKey: Keys.successfulTransmissions) >= minimumSuccessfulTransmissions else {
            return false
        }
        // Mai due volte sulla stessa versione: se l'utente ha già visto il
        // prompt e non ha recensito, riproporglielo sulla stessa build è solo
        // fastidio.
        if defaults.string(forKey: Keys.lastPromptVersion) == currentVersion { return false }
        if let last = defaults.object(forKey: Keys.lastPromptDate) as? Date,
           Date().timeIntervalSince(last) < minimumIntervalBetweenPrompts {
            return false
        }
        return true
    }

    private func requestReviewIfAppropriate() {
        guard isAppropriate else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        // Segna PRIMA di chiedere: se il sistema decide di non mostrare nulla
        // (quota Apple esaurita) non dobbiamo riprovare al PTT successivo.
        defaults.set(Date(), forKey: Keys.lastPromptDate)
        defaults.set(currentVersion, forKey: Keys.lastPromptVersion)

        // Mezzo secondo di ritardo: il prompt arriva a PTT rilasciato, non
        // sopra il gesto dell'utente.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if #available(iOS 16.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
            Analytics.logEvent("review_prompt_shown", parameters: [
                "successful_transmissions": self.defaults.integer(forKey: Keys.successfulTransmissions)
            ])
        }
    }

    // MARK: - Reset

    /// Azzera il conteggio delle trasmissioni, chiamato da "Ripristina impostazioni".
    ///
    /// Volutamente NON tocca `lastPromptDate` / `lastPromptVersion`: se l'utente
    /// ha già visto il prompt, resettare le preferenze non deve diventare il modo
    /// per farglielo rivedere. Il ripristino riporta indietro le sue impostazioni,
    /// non la nostra quota di richieste.
    func resetTransmissionCount() {
        defaults.removeObject(forKey: Keys.successfulTransmissions)
    }
}
