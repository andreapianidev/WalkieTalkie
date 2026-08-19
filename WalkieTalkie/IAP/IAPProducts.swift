//creato da Andrea Piani - 22/05/26 - https://www.andreapiani.com - IAPProducts.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation

/// Identifica i prodotti IAP configurati su App Store Connect.
/// Due subscription (settimanale + annuale) nello stesso group "Talky Pro" +
/// un singolo non-consumable "All Themes Pack" che sblocca tutti gli 11 temi
/// (Identity + Animated) in un colpo solo.
enum ProductID: String, CaseIterable {
    // Gli ID devono corrispondere ESATTAMENTE ai prodotti registrati su
    // App Store Connect (vedi "Acquisti In-App" → "Abbonamenti").
    case weekly = "ProWeeklyWT"
    case yearly = "ProAnnualWT"

    /// Singolo non-consumable che sblocca tutti i temi Pro-locked
    /// (alternativa one-shot alla subscription). Prezzo target €4,99.
    static let themesPackID = "app.immaginet.talky.themes.allpack"

    /// Non-consumable che sblocca **tutto Talky Pro per sempre**, temi inclusi.
    ///
    /// Esiste perché tre recensioni App Store hanno chiesto esplicitamente di
    /// poter pagare una volta sola invece di abbonarsi ("a pay once model would
    /// be appreciated", "the addition of ads and subscription ruined it"). Su
    /// un'app scritta da una persona sola, l'abbonamento settimanale è la forma
    /// sbagliata del messaggio "dammi un contributo".
    ///
    /// €14,99 in area euro (≈ $12,99 USA). Il prezzo è ancorato al mercato:
    /// myTuner Radio Pro chiede $10 una tantum per la sola radio, Voxer e
    /// Walkie Talkie Intercom ~$30 **all'anno** per il solo push-to-talk.
    static let lifetimeID = "app.immaginet.talky.pro.lifetime"

    /// Tutti gli ID prodotto (subscription + non-consumable) per `Product.products(for:)`.
    static var allIDs: [String] {
        return ProductID.allCases.map { $0.rawValue } + [themesPackID, lifetimeID]
    }

    /// True se l'ID è l'acquisto una tantum "per sempre".
    static func isLifetime(_ id: String) -> Bool {
        return id == lifetimeID
    }

    /// Solo gli ID delle subscription auto-rinnovabili (Talky Pro).
    static var subscriptionIDs: [String] {
        return ProductID.allCases.map { $0.rawValue }
    }

    /// True se l'ID è il themes pack non-consumable.
    static func isThemesPack(_ id: String) -> Bool {
        return id == themesPackID
    }

    /// True se il prodotto è l'abbonamento annuale.
    var isYearly: Bool {
        return self == .yearly
    }

    /// True se il prodotto è l'abbonamento settimanale.
    var isWeekly: Bool {
        return self == .weekly
    }
}
