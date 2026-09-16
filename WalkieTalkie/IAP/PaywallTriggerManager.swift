//creato da Andrea Piani - 07/08/26 - https://www.andreapiani.com - PaywallTriggerManager.swift
//  WalkieTalkie
//

import Foundation
import Combine
import os
import FirebaseAnalytics

/// Log del percorso consenso, ATT e paywall, leggibile da Console.app sul
/// dispositivo filtrando per categoria `PaywallFlow`. Messaggi pubblici: con
/// `os_log("%@")` in Release comparirebbero come `<private>`, cioe' inutili
/// proprio sulla build in cui serve capire cosa e' successo.
enum PaywallFlowLog {
    private static let logger = os.Logger(subsystem: "com.andreapiani.walkietalkie", category: "PaywallFlow")

    static func log(_ message: String) {
        logger.notice("[PaywallFlow] \(message, privacy: .public)")
    }
}

/// Decide QUANDO mostrare il paywall, e soprattutto quando tacere.
///
/// Perché esiste: fino alla 2.44 il paywall si apriva solo se l'utente andava a
/// cercarselo in Impostazioni. Con una conversione dello 0,3% su ~3.500 nuovi
/// utenti al mese, il problema non era la schermata — che c'è ed è curata — ma
/// il fatto che quasi nessuno la vedeva mai.
///
/// Il criterio è lo stesso di `ReviewPromptManager`, ed è deliberato: **chiedere
/// solo dopo che l'app ha dimostrato di servire a qualcosa**. Mai al primo
/// avvio, mai mentre si sta parlando, mai due volte nello stesso paio di giorni.
/// Un walkie-talkie interrotto da un paywall mentre l'utente preme PTT è il modo
/// più rapido per prendere l'ennesima stella singola.
///
/// Non è un `ObservableObject` per scelta: la richiesta di apertura viaggia su
/// `NotificationCenter`, così i punti che la generano (manager, non viste) non
/// devono conoscere la gerarchia SwiftUI né tenere un binding.
@MainActor
final class PaywallTriggerManager {

    static let shared = PaywallTriggerManager()

    /// Notifica osservata da ContentView per presentare il paywall.
    /// `userInfo["trigger"]` contiene il `Trigger.rawValue`.
    static let presentRequest = Notification.Name("talky.paywall.present")

    /// Notifica di presentazione fallita: ContentView rimette a posto il proprio
    /// stato, altrimenti `showPaywall` resterebbe `true` senza paywall a schermo
    /// e bloccherebbe ogni apertura successiva della sessione.
    static let presentFailed = Notification.Name("talky.paywall.presentFailed")

    // MARK: - Trigger

    enum Trigger: String, CaseIterable {
        /// Apertura della seconda sessione: la prima si lascia libera, serve a
        /// capire cos'è l'app.
        case secondSession = "second_session"
        /// Tentativo di usare i canali privati. Lo spec parlava di "secondo
        /// canale privato", ipotizzando un canale gratuito: nell'app di oggi i
        /// canali privati sono interamente Pro, quindi il trigger scatta al
        /// primo tentativo. Se un giorno si concedesse un canale free, cambia
        /// solo il punto di chiamata, non questo enum.
        case privateChannelAttempt = "private_channel_attempt"
        /// Tentativo di registrare una trasmissione.
        case recordingAttempt = "recording_attempt"
        /// Ventesima trasmissione riuscita: qui l'utente usa Talky sul serio.
        case twentiethTransmission = "twentieth_transmission"

        /// I trigger legati a un traguardo scattano una volta sola nella vita
        /// dell'app. Quelli legati a un'azione bloccata possono ripresentarsi,
        /// perché l'utente sta chiedendo attivamente quella funzione.
        var isOneShot: Bool {
            switch self {
            case .secondSession, .twentiethTransmission: return true
            case .privateChannelAttempt, .recordingAttempt: return false
            }
        }

        /// Vero quando è l'app a interrompere l'utente, falso quando è l'utente
        /// a chiedere una funzione Pro.
        ///
        /// La distinzione decide chi rispetta la distanza minima di 48 ore. Solo
        /// i trigger proattivi la rispettano: applicarla anche a un tocco
        /// esplicito su una funzione bloccata produrrebbe un bottone che non fa
        /// niente per due giorni, che l'utente legge come app rotta — e una
        /// recensione da una stella costa più di un paywall in più.
        var isProactive: Bool { isOneShot }
    }

    // MARK: - Soglie

    /// Distanza minima fra due paywall, qualunque sia il trigger.
    private let minimumInterval: TimeInterval = 48 * 60 * 60

    /// Trasmissioni riuscite oltre le quali si può proporre Pro.
    private let transmissionMilestone = 20

    // MARK: - Storage

    private enum Keys {
        static let sessionCount = "paywall_session_count"
        static let lastShown = "paywall_last_shown_date"
        /// `_v2` dalla 2.46. Fino alla 2.45 il one-shot veniva segnato alla
        /// RICHIESTA, non alla comparsa: chi aveva un foglio aperto, il modulo
        /// di consenso o l'alert ATT a schermo in quel momento si e' visto
        /// bruciare il trigger senza mai vedere il paywall. La vecchia chiave
        /// non distingue i due casi, quindi si riparte da zero: chi il paywall
        /// l'ha visto davvero lo rivede una volta sola, gli altri finalmente
        /// lo vedono.
        static let firedOneShots = "paywall_fired_oneshots_v2"
        static let transmissions = "paywall_transmission_count"
        // Strumentazione (fase 3.4)
        static let shownTotal = "paywall_metric_shown_total"
        static let shownByTrigger = "paywall_metric_shown_by_trigger"
        static let dismissedNoPurchase = "paywall_metric_dismissed_no_purchase"
        static let lastDismissedProduct = "paywall_metric_last_dismissed_product"
    }

    private let defaults = UserDefaults.standard

    /// Vero mentre una trasmissione è in corso: in quel momento il paywall non
    /// si apre per nessun motivo. Lo aggiorna `MultipeerManager`.
    var isConversationActive = false

    /// Il trigger proattivo richiesto e non ancora confermato da `PaywallView`.
    /// Finche' non arriva la conferma il trigger NON e' consumato.
    private var awaitingConfirmation: Trigger?

    /// Tempo concesso alla vista per comparire dopo la richiesta. `onAppear`
    /// arriva in meno di mezzo secondo: 4 s sono un margine largo.
    private let confirmationTimeout: UInt64 = 4_000_000_000

    /// Nuovi tentativi nella stessa sessione dopo una presentazione fallita.
    /// Oltre, si riprova alla sessione successiva.
    private let maxRetriesPerSession = 2
    private var retriesThisSession = 0

    private init() {}

    // MARK: - Stato Pro

    /// Si legge il bridge fast-boot invece di `IAPManager.shared.isProUser`
    /// perché i trigger possono scattare prima che `updateEntitlements()` abbia
    /// finito, e mostrare il paywall a un abbonato è il peggior errore possibile.
    private var isPro: Bool {
        defaults.bool(forKey: "fastboot_isProUser")
            || defaults.bool(forKey: "fastboot_hasLifetime")
    }

    // MARK: - Eventi in ingresso

    /// Da chiamare a ogni avvio a freddo dell'app, PRIMA di `AdManager.bootstrap()`.
    func registerSession() {
        let count = defaults.integer(forKey: Keys.sessionCount) + 1
        defaults.set(count, forKey: Keys.sessionCount)
        // `>= 2` e non `== 2`: con l'uguaglianza una presentazione fallita al
        // secondo avvio non si recuperava piu'. Il one-shot, segnato solo a
        // paywall comparso, impedisce che si ripeta.
        guard count >= 2, canPresent(.secondSession) else { return }

        // Deciso adesso, prima che il bootstrap annunci arrivi a caricare
        // l'app-open: in questa sessione l'annuncio di apertura non parte.
        AdManager.shared.appOpenBlockedThisSession = true
        PaywallFlowLog.log("sessione \(count): paywall second_session in programma, app-open spento per questa sessione")

        scheduleAfterPrivacyFlow(.secondSession, settleDelay: 1_500_000_000)
    }

    /// Richiede il paywall solo quando consenso e ATT sono chiusi.
    ///
    /// Il modulo UMP e l'alert ATT stanno a schermo per un tempo che dipende
    /// dalla rete e dall'utente: il vecchio ritardo fisso di 2,5 s cadeva spesso
    /// nel mezzo, e un `fullScreenCover` presentato sopra di loro fallisce senza
    /// errori. Il margine dopo la chiusura lascia finire la transizione di scena
    /// che l'alert ATT provoca uscendo.
    private func scheduleAfterPrivacyFlow(_ trigger: Trigger, settleDelay: UInt64) {
        Task { @MainActor in
            await AdManager.shared.waitUntilPrivacyFlowClosed()
            try? await Task.sleep(nanoseconds: settleDelay)
            request(trigger)
        }
    }

    /// Trasmissione conclusa con almeno un peer connesso.
    func registerTransmission(connectedPeerCount: Int) {
        guard connectedPeerCount > 0 else { return }
        let count = defaults.integer(forKey: Keys.transmissions) + 1
        defaults.set(count, forKey: Keys.transmissions)
        // `>=` per lo stesso motivo di `registerSession`: se alla ventesima il
        // paywall non riesce ad aprirsi, si riprova alla ventunesima.
        guard count >= transmissionMilestone else { return }
        request(.twentiethTransmission)
    }

    /// L'utente ha provato a usare un canale privato.
    /// Ritorna `true` se il paywall è stato presentato, così il chiamante sa che
    /// l'azione è stata intercettata.
    @discardableResult
    func requestForPrivateChannel() -> Bool { request(.privateChannelAttempt) }

    /// L'utente ha provato a registrare una trasmissione.
    @discardableResult
    func requestForRecording() -> Bool { request(.recordingAttempt) }

    // MARK: - Decisione

    /// Chiede a ContentView di aprire il paywall. Ritorna `true` se la richiesta
    /// e' partita, che NON vuol dire che il paywall sia comparso: il trigger si
    /// consuma solo in `paywallDidAppear`.
    @discardableResult
    private func request(_ trigger: Trigger) -> Bool {
        guard canPresent(trigger) else { return false }
        guard awaitingConfirmation == nil else {
            PaywallFlowLog.log("paywall \(trigger.rawValue) non richiesto: un'altra richiesta attende conferma")
            return false
        }

        PaywallFlowLog.log("paywall richiesto (trigger=\(trigger.rawValue))")
        awaitingConfirmation = trigger

        // Il paywall sta per aprirsi: l'app-open non deve infilarsi nel mezzo.
        // Si alza solo `suppressNextResume`, che si consuma da sé al primo
        // rientro: `isPaywallVisible` resta di proprietà della vista, l'unica
        // che sa anche spegnerlo.
        AdManager.shared.appOpen.suppressNextResume = true

        NotificationCenter.default.post(
            name: Self.presentRequest, object: nil,
            userInfo: ["trigger": trigger.rawValue])

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: confirmationTimeout)
            guard awaitingConfirmation == trigger else { return }
            presentationFailed(trigger)
        }
        return true
    }

    /// Chiamato da `PaywallView.onAppear`: e' l'unico punto in cui un paywall
    /// risulta mostrato davvero, quindi l'unico in cui il trigger si consuma.
    func paywallDidAppear(trigger: String) {
        PaywallFlowLog.log("paywall mostrato (trigger=\(trigger))")
        guard let pending = awaitingConfirmation, pending.rawValue == trigger else { return }
        awaitingConfirmation = nil

        if pending.isOneShot {
            var fired = Set(defaults.stringArray(forKey: Keys.firedOneShots) ?? [])
            fired.insert(pending.rawValue)
            defaults.set(Array(fired), forKey: Keys.firedOneShots)
        }
        defaults.set(Date(), forKey: Keys.lastShown)
        recordShown(pending)
    }

    /// La vista non e' comparsa entro il tempo concesso. Il trigger resta
    /// disponibile: si riprova in questa sessione, e se anche questo va male
    /// alla prossima.
    private func presentationFailed(_ trigger: Trigger) {
        awaitingConfirmation = nil
        PaywallFlowLog.log("paywall fallito (trigger=\(trigger.rawValue)): nessuna comparsa entro 4 s, trigger ancora disponibile")
        Analytics.logEvent("paywall_present_failed", parameters: ["trigger": trigger.rawValue])
        NotificationCenter.default.post(
            name: Self.presentFailed, object: nil,
            userInfo: ["trigger": trigger.rawValue])

        guard trigger.isProactive, retriesThisSession < maxRetriesPerSession else { return }
        retriesThisSession += 1
        PaywallFlowLog.log("nuovo tentativo \(retriesThisSession)/\(maxRetriesPerSession) per \(trigger.rawValue) fra 5 s")
        scheduleAfterPrivacyFlow(trigger, settleDelay: 5_000_000_000)
    }

    private func canPresent(_ trigger: Trigger) -> Bool {
        if isPro { return false }
        if isConversationActive {
            PaywallFlowLog.log("paywall \(trigger.rawValue) rimandato: conversazione in corso")
            return false
        }

        if trigger.isOneShot {
            let fired = defaults.stringArray(forKey: Keys.firedOneShots) ?? []
            if fired.contains(trigger.rawValue) { return false }
        }

        if trigger.isProactive,
           let last = defaults.object(forKey: Keys.lastShown) as? Date,
           Date().timeIntervalSince(last) < minimumInterval {
            return false
        }
        return true
    }

    // MARK: - Strumentazione (fase 3.4)
    //
    // Quattro numeri e basta: quante volte il paywall è comparso, da quale
    // trigger, quante volte è stato chiuso senza comprare e quale prodotto era
    // selezionato in quel momento. Senza il quarto non si distingue "il prezzo
    // non convince" da "non ha capito cosa stava comprando", e ogni modifica
    // successiva sarebbe fatta a caso. Restano in locale e vanno anche a
    // Firebase, dove sono leggibili senza avere il dispositivo in mano.

    /// Registra un paywall che la vista ha presentato da sé (tocco su funzione
    /// bloccata). Non decide niente — la decisione l'ha già presa l'utente
    /// toccando — ma tiene i contatori in un posto solo, altrimenti metà delle
    /// aperture non comparirebbe nei numeri.
    func noteReactivePresentation(_ trigger: String) {
        defaults.set(defaults.integer(forKey: Keys.shownTotal) + 1, forKey: Keys.shownTotal)
        var byTrigger = defaults.dictionary(forKey: Keys.shownByTrigger) as? [String: Int] ?? [:]
        byTrigger[trigger, default: 0] += 1
        defaults.set(byTrigger, forKey: Keys.shownByTrigger)
        Analytics.logEvent("paywall_triggered", parameters: [
            "trigger": trigger,
            "shown_total": defaults.integer(forKey: Keys.shownTotal),
        ])
    }

    private func recordShown(_ trigger: Trigger) {
        defaults.set(defaults.integer(forKey: Keys.shownTotal) + 1, forKey: Keys.shownTotal)
        var byTrigger = defaults.dictionary(forKey: Keys.shownByTrigger) as? [String: Int] ?? [:]
        byTrigger[trigger.rawValue, default: 0] += 1
        defaults.set(byTrigger, forKey: Keys.shownByTrigger)

        Analytics.logEvent("paywall_triggered", parameters: [
            "trigger": trigger.rawValue,
            "shown_total": defaults.integer(forKey: Keys.shownTotal),
        ])
    }

    /// Da chiamare quando il paywall viene chiuso senza acquisto.
    func recordDismissedWithoutPurchase(trigger: String, selectedProductID: String) {
        let count = defaults.integer(forKey: Keys.dismissedNoPurchase) + 1
        defaults.set(count, forKey: Keys.dismissedNoPurchase)
        defaults.set(selectedProductID, forKey: Keys.lastDismissedProduct)

        Analytics.logEvent("paywall_dismissed_no_purchase", parameters: [
            "trigger": trigger,
            "selected_product": selectedProductID,
            "dismissed_total": count,
        ])
    }

    /// Fotografia dei contatori, per la voce diagnostica in Impostazioni.
    var metrics: (shown: Int, dismissed: Int, byTrigger: [String: Int], lastProduct: String?) {
        (defaults.integer(forKey: Keys.shownTotal),
         defaults.integer(forKey: Keys.dismissedNoPurchase),
         defaults.dictionary(forKey: Keys.shownByTrigger) as? [String: Int] ?? [:],
         defaults.string(forKey: Keys.lastDismissedProduct))
    }

    /// Azzera contatori e traguardi, chiamato da "Ripristina impostazioni".
    func reset() {
        [Keys.sessionCount, Keys.lastShown, Keys.firedOneShots, Keys.transmissions,
         Keys.shownTotal, Keys.shownByTrigger, Keys.dismissedNoPurchase,
         Keys.lastDismissedProduct].forEach(defaults.removeObject(forKey:))
    }
}
