//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - IAPProducts.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation

/// Identifica i prodotti IAP configurati su App Store Connect.
/// I due `case` qui sotto appartengono allo stesso subscription group "Talky Pro".
/// I temi singoli (non-consumable) sono gestiti come stringhe statiche separate
/// per non mescolare semantica subscription vs. acquisto una tantum.
enum ProductID: String, CaseIterable {
    // Gli ID devono corrispondere ESATTAMENTE ai prodotti registrati su
    // App Store Connect (vedi "Acquisti In-App" → "Abbonamenti").
    // Non aggiungere prefissi reverse-DNS: ASC li accetta come stringhe libere.
    case weekly = "ProWeeklyWT"
    case yearly = "ProAnnualWT"

    /// Tutti gli identificatori prodotto (subscription + tema) come stringhe
    /// per `Product.products(for:)`. Include subscription Talky Pro e i temi
    /// singoli (Identity Pack + Animated Pack).
    static var allIDs: [String] {
        return ProductID.allCases.map { $0.rawValue } + allThemeProducts
    }

    /// Solo gli ID delle subscription auto-rinnovabili (Talky Pro).
    static var subscriptionIDs: [String] {
        return ProductID.allCases.map { $0.rawValue }
    }

    /// True se il prodotto è l'abbonamento annuale
    var isYearly: Bool {
        return self == .yearly
    }

    /// True se il prodotto è l'abbonamento settimanale
    var isWeekly: Bool {
        return self == .weekly
    }

    // MARK: - Theme Products (Non-Consumable)

    /// 9 temi Identity Pack — €0,99 cad. (priceTier `.iap099`).
    /// Gli ID seguono il pattern `app.immaginet.talky.theme.<rawValue>` e
    /// devono essere registrati come "Non-Consumable" su App Store Connect.
    static let themeIdentityProducts: [String] = [
        "app.immaginet.talky.theme.military",
        "app.immaginet.talky.theme.retro80s",
        "app.immaginet.talky.theme.vintageRadio",
        "app.immaginet.talky.theme.cyberpunk",
        "app.immaginet.talky.theme.stealth",
        "app.immaginet.talky.theme.aurora",
        "app.immaginet.talky.theme.submarine",
        "app.immaginet.talky.theme.hamRadio",
        "app.immaginet.talky.theme.festival"
    ]

    /// 2 temi Animated Pack — €1,99 cad. (priceTier `.iap199`).
    static let themeAnimatedProducts: [String] = [
        "app.immaginet.talky.theme.blackHole",
        "app.immaginet.talky.theme.galaxy"
    ]

    /// Tutti i product ID dei temi (Identity + Animated). Used by IAPManager
    /// per filtrare le entitlement non-consumable.
    static var allThemeProducts: [String] {
        return themeIdentityProducts + themeAnimatedProducts
    }

    /// True se la stringa fornita è un product ID di un tema singolo.
    static func isThemeProduct(_ id: String) -> Bool {
        return allThemeProducts.contains(id)
    }
}
