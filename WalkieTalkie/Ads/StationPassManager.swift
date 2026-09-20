//  StationPassManager.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani

import Foundation
import Combine

/// Pass temporanei sulle stazioni Pro, guadagnati guardando un rewarded.
///
/// Esiste per dare al rewarded (`walkiepremio`) un premio che l'utente vuole
/// davvero. Fino a qui l'unico premio era "un'ora senza pubblicita'", che si
/// offre a chi la pubblicita' ha appena finito di vederla: il risultato sono
/// 589 impression al mese su un formato che rende 15,97 EUR ogni mille, il
/// triplo di qualunque altro formato dell'app. Sbloccare per 24 ore la
/// stazione che l'utente ha appena provato ad aprire e' invece un premio
/// chiesto nel momento esatto in cui serve.
///
/// Non e' un aggiramento del paywall: il pass dura 24 ore, vale una stazione
/// sola e non tocca nessuna delle altre funzioni Pro (registrazione, temi,
/// sleep timer, canali privati).
///
/// Volutamente NON e' `@MainActor`: il gate di riproduzione vive in
/// `RadioManager.playStation`, che non e' isolato. Lo stato sta in
/// UserDefaults e si rilegge a ogni chiamata, quindi la lettura e' sicura da
/// qualunque contesto; l'unica cosa che passa dal main actor e' la notifica
/// a SwiftUI.
final class StationPassManager: ObservableObject {

    static let shared = StationPassManager()

    /// Durata di un pass. Ventiquattro ore e non un'ora: il pass deve valere
    /// abbastanza da far guardare il video, e una stazione radio si riascolta
    /// il giorno dopo, non entro l'ora.
    static let passDuration: TimeInterval = 24 * 3600

    /// `[stationID come stringa: scadenza in epoch]`.
    private static let storageKey = "fastboot_stationPasses"

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pruneExpired()
    }

    // MARK: - Lettura

    /// Vero se la stazione ha un pass ancora valido in questo istante.
    func isUnlocked(_ stationID: Int) -> Bool {
        guard let expiry = expiry(for: stationID) else { return false }
        return expiry > Date()
    }

    func expiry(for stationID: Int) -> Date? {
        guard let raw = storedPasses()[String(stationID)] else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    /// Tempo che resta, o nil se il pass non c'e' o e' scaduto. Serve alla UI
    /// per scrivere "ancora 7 h" sulla riga della stazione.
    func remaining(for stationID: Int) -> TimeInterval? {
        guard let expiry = expiry(for: stationID), expiry > Date() else { return nil }
        return expiry.timeIntervalSinceNow
    }

    /// Descrizione compatta del tempo residuo: "23 h" oppure "45 min".
    func remainingShortDescription(for stationID: Int) -> String? {
        guard let remaining = remaining(for: stationID) else { return nil }
        if remaining >= 3600 {
            return "\(Int(remaining / 3600)) h"
        }
        return "\(max(1, Int(remaining / 60))) min"
    }

    /// Numero di pass attivi. Usato dal banner riassuntivo nel browser.
    var activePassCount: Int {
        let now = Date().timeIntervalSince1970
        return storedPasses().values.filter { $0 > now }.count
    }

    // MARK: - Scrittura

    /// Concede 24 ore sulla stazione. Se un pass c'e' gia' e non e' scaduto la
    /// scadenza viene estesa a partire da adesso, non sommata: guardare due
    /// video di fila non deve poter accumulare giorni.
    func grantPass(for stationID: Int) {
        var passes = storedPasses()
        passes[String(stationID)] = Date().addingTimeInterval(Self.passDuration).timeIntervalSince1970
        write(passes)
    }

    /// Elimina i pass scaduti. Chiamata all'avvio: senza, il dizionario cresce
    /// di una voce per ogni stazione mai sbloccata e non si svuota mai.
    func pruneExpired() {
        let now = Date().timeIntervalSince1970
        let passes = storedPasses()
        let alive = passes.filter { $0.value > now }
        guard alive.count != passes.count else { return }
        write(alive)
    }

    // MARK: - Storage

    private func storedPasses() -> [String: Double] {
        defaults.dictionary(forKey: Self.storageKey) as? [String: Double] ?? [:]
    }

    private func write(_ passes: [String: Double]) {
        defaults.set(passes, forKey: Self.storageKey)
        // SwiftUI osserva questo oggetto per ridisegnare le righe del browser.
        // La notifica va sul main actor anche quando la scrittura arriva da
        // altrove.
        if Thread.isMainThread {
            objectWillChange.send()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
}
