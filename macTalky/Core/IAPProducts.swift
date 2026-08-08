//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - IAPProducts.swift
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
    /// (alternativa one-shot alla subscription).
    static let themesPackID = "app.immaginet.talky.themes.allpack"

    /// Acquisto una tantum che vale Pro **e** temi, per sempre.
    ///
    /// Condivide il bundle identifier con l'app iOS, quindi e' un universal
    /// purchase: comprato da Mac sblocca anche iPhone e iPad, e viceversa. Fino
    /// alla 1.1.1 macTalky non lo conosceva affatto — un utente Mac vedeva la
    /// paywall senza l'opzione "paghi una volta", pur essendo un prodotto suo a
    /// tutti gli effetti.
    static let lifetimeID = "app.immaginet.talky.pro.lifetime"

    /// Tutti gli ID prodotto (subscription + themes pack + lifetime).
    static var allIDs: [String] {
        return ProductID.allCases.map { $0.rawValue } + [themesPackID, lifetimeID]
    }

    /// True se l'ID è l'acquisto "per sempre".
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
