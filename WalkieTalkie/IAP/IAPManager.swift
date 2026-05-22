//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - IAPManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import StoreKit
import Combine
import FirebaseAnalytics

/// Gestisce gli acquisti in-app (StoreKit 2) per Talky Pro e per i temi singoli.
/// Singleton @MainActor che espone lo stato dell'abbonamento e dei temi acquistati
/// via @Published properties.
///
/// Modello di unlock dei temi Pro-locked:
/// - Utente con subscription Talky Pro → accede a TUTTI i temi.
/// - Utente senza subscription → può comprare singoli temi (€0,99 / €1,99)
///   come non-consumable e accederà solo a quelli effettivamente acquistati.
@MainActor
final class IAPManager: ObservableObject {
    static let shared = IAPManager()

    // MARK: - Published State

    @Published var products: [Product] = []
    @Published var isProUser: Bool = false
    @Published var activeSubscription: Product? = nil
    @Published var isLoading: Bool = false

    /// Set di product ID dei temi singoli effettivamente acquistati (non-consumable).
    /// Le View possono osservarlo per aggiornare l'UI del paywall per-tema.
    @Published var ownedThemeProductIDs: Set<String> = []

    // MARK: - Private

    private let logger = Logger.shared
    private var transactionListenerTask: Task<Void, Never>? = nil

    /// Chiave UserDefaults usata come "bridge" per il fast-boot: altre feature
    /// (es. AdManager, gating premium) leggono questo flag per evitare di
    /// attendere il completamento di updateEntitlements() all'avvio.
    private static let fastBootKey = "fastboot_isProUser"

    /// Chiave UserDefaults usata come "bridge" per i temi singoli posseduti.
    /// Memorizzata come `[String]` (array di product ID). ThemeManager legge
    /// questa chiave per validare l'accesso senza importare IAPManager.
    private static let fastBootOwnedThemesKey = "fastboot_ownedThemes"

    // MARK: - Lifecycle

    private init() {
        // Carica subito lo stato pro dal fast-boot, prima ancora di interrogare StoreKit
        self.isProUser = UserDefaults.standard.bool(forKey: Self.fastBootKey)

        // Fast-boot dei temi acquistati: array di product ID salvati in UserDefaults
        if let owned = UserDefaults.standard.array(forKey: Self.fastBootOwnedThemesKey) as? [String] {
            self.ownedThemeProductIDs = Set(owned)
        }

        // Avvia il listener delle transazioni (rinnovi automatici, refund, ecc.)
        self.transactionListenerTask = Task { [weak self] in
            await self?.listenForTransactions()
        }

        logger.logInfo("IAPManager inizializzato (fast-boot isProUser=\(isProUser), ownedThemes=\(ownedThemeProductIDs.count))")
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Bootstrap

    /// Bootstrap completo: legge il fast-boot, carica i prodotti dallo Store,
    /// e aggiorna lo stato entitlements (subscription + temi singoli).
    func bootstrap() async {
        // Fast-boot: stato già caricato in init, qui ribadisco per sicurezza
        self.isProUser = UserDefaults.standard.bool(forKey: Self.fastBootKey)
        if let owned = UserDefaults.standard.array(forKey: Self.fastBootOwnedThemesKey) as? [String] {
            self.ownedThemeProductIDs = Set(owned)
        }

        // Carica prodotti + aggiorna entitlements in parallelo
        do {
            try await loadProducts()
        } catch {
            logger.logError(error, context: "IAPManager.bootstrap loadProducts")
        }
        await updateEntitlements()
    }

    // MARK: - Products

    /// Recupera i prodotti configurati su App Store Connect (subscription + temi).
    func loadProducts() async throws {
        isLoading = true
        defer { isLoading = false }

        let storeProducts = try await Product.products(for: ProductID.allIDs)
        // Ordina: settimanale prima, annuale dopo (più ergonomico per la UI)
        self.products = storeProducts.sorted { lhs, rhs in
            return lhs.price < rhs.price
        }
        logger.logInfo("IAPManager: caricati \(self.products.count) prodotti")
    }

    // MARK: - Purchase

    /// Avvia l'acquisto di un prodotto. Ritorna `true` se l'acquisto si conclude
    /// con successo (verificato), `false` se l'utente annulla o se è pending.
    /// Usato per le subscription Talky Pro.
    func purchase(_ product: Product) async throws -> Bool {
        // Analytics: inizio acquisto
        Analytics.logEvent("purchase_initiated", parameters: [
            "product_id": product.id
        ])
        logger.logInfo("IAPManager: purchase_initiated \(product.id)")

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Verifica firma Apple prima di sbloccare
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updateEntitlements()

                    // Analytics: acquisto completato
                    Analytics.logEvent("purchase_completed", parameters: [
                        "product_id": product.id,
                        "revenue": NSDecimalNumber(decimal: product.price).doubleValue
                    ])
                    logger.logInfo("IAPManager: purchase_completed \(product.id)")
                    return true

                case .unverified(_, let error):
                    // Transazione non verificata: tratto come fallimento
                    Analytics.logEvent("purchase_failed", parameters: [
                        "product_id": product.id,
                        "error": "unverified: \(error.localizedDescription)"
                    ])
                    logger.logError(error, context: "IAPManager: unverified transaction")
                    throw error
                }

            case .userCancelled:
                logger.logInfo("IAPManager: utente ha annullato l'acquisto \(product.id)")
                return false

            case .pending:
                // Acquisto in attesa di approvazione esterna (Ask to Buy, SCA, ecc.)
                logger.logInfo("IAPManager: purchase pending per \(product.id)")
                return false

            @unknown default:
                logger.logWarning("IAPManager: purchase result sconosciuto per \(product.id)")
                return false
            }
        } catch {
            Analytics.logEvent("purchase_failed", parameters: [
                "product_id": product.id,
                "error": error.localizedDescription
            ])
            logger.logError(error, context: "IAPManager.purchase")
            throw error
        }
    }

    /// Avvia l'acquisto di un singolo tema (non-consumable) by product ID.
    /// Stesso flusso di `purchase(_:)` ma aggiorna `ownedThemeProductIDs` su successo
    /// e logga eventi Firebase dedicati (`theme_purchase_*`).
    ///
    /// - Parameter productID: l'ID del prodotto tema (es. `app.immaginet.talky.theme.galaxy`).
    /// - Returns: `true` se acquisto verificato; `false` se cancellato/pending.
    /// - Throws: errore se il prodotto non è disponibile o se la transazione non è verificata.
    func purchaseTheme(productID: String) async throws -> Bool {
        // Trova il Product corrispondente tra quelli già caricati
        guard let product = products.first(where: { $0.id == productID }) else {
            let error = NSError(
                domain: "IAPManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Theme product \(productID) not loaded"]
            )
            Analytics.logEvent("theme_purchase_failed", parameters: [
                "product_id": productID,
                "error": "product_not_loaded"
            ])
            logger.logError(error, context: "IAPManager.purchaseTheme: product not loaded")
            throw error
        }

        // Analytics: inizio acquisto tema
        Analytics.logEvent("theme_purchase_initiated", parameters: [
            "product_id": productID
        ])
        logger.logInfo("IAPManager: theme_purchase_initiated \(productID)")

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    // Aggiorna immediatamente il Set e persiste, poi rinfresca da entitlements
                    self.ownedThemeProductIDs.insert(productID)
                    persistOwnedThemes()
                    await updateEntitlements()

                    Analytics.logEvent("theme_purchase_completed", parameters: [
                        "product_id": productID,
                        "revenue": NSDecimalNumber(decimal: product.price).doubleValue
                    ])
                    logger.logInfo("IAPManager: theme_purchase_completed \(productID)")
                    return true

                case .unverified(_, let error):
                    Analytics.logEvent("theme_purchase_failed", parameters: [
                        "product_id": productID,
                        "error": "unverified: \(error.localizedDescription)"
                    ])
                    logger.logError(error, context: "IAPManager.purchaseTheme: unverified transaction")
                    throw error
                }

            case .userCancelled:
                logger.logInfo("IAPManager: utente ha annullato l'acquisto tema \(productID)")
                return false

            case .pending:
                logger.logInfo("IAPManager: purchase tema pending per \(productID)")
                return false

            @unknown default:
                logger.logWarning("IAPManager: theme purchase result sconosciuto per \(productID)")
                return false
            }
        } catch {
            Analytics.logEvent("theme_purchase_failed", parameters: [
                "product_id": productID,
                "error": error.localizedDescription
            ])
            logger.logError(error, context: "IAPManager.purchaseTheme")
            throw error
        }
    }

    // MARK: - Restore

    /// Forza la sync con App Store e aggiorna lo stato entitlements
    /// (subscription + temi singoli). Da chiamare dal pulsante "Ripristina acquisti".
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        try await AppStore.sync()
        await updateEntitlements()

        // Analytics: se troviamo un abbonamento attivo, logghiamo restore success
        if let active = activeSubscription {
            Analytics.logEvent("subscription_restored", parameters: [
                "product_id": active.id
            ])
            logger.logInfo("IAPManager: subscription_restored \(active.id)")
        } else {
            logger.logInfo("IAPManager: restorePurchases completato (nessun abbonamento attivo)")
        }

        if !ownedThemeProductIDs.isEmpty {
            Analytics.logEvent("themes_restored", parameters: [
                "count": ownedThemeProductIDs.count
            ])
            logger.logInfo("IAPManager: ripristinati \(ownedThemeProductIDs.count) temi singoli")
        }
    }

    // MARK: - Entitlements

    /// Itera le entitlement correnti, salta le transazioni non verificate,
    /// e aggiorna sia lo stato subscription sia il set di temi singoli posseduti.
    /// Persiste entrambi i bridge UserDefaults.
    func updateEntitlements() async {
        var foundActiveProduct: Product? = nil
        var isPro = false
        var ownedThemes: Set<String> = []

        for await result in Transaction.currentEntitlements {
            // Salta le transazioni non verificate
            guard case .verified(let transaction) = result else { continue }

            // Caso A: subscription auto-rinnovabile (Talky Pro)
            if ProductID.subscriptionIDs.contains(transaction.productID) {
                if transaction.revocationDate == nil {
                    if let expiration = transaction.expirationDate, expiration < Date() {
                        continue
                    }
                    isPro = true
                    if let matching = products.first(where: { $0.id == transaction.productID }) {
                        foundActiveProduct = matching
                    }
                }
                continue
            }

            // Caso B: non-consumable tema singolo
            if ProductID.isThemeProduct(transaction.productID) {
                if transaction.revocationDate == nil {
                    ownedThemes.insert(transaction.productID)
                }
                continue
            }
        }

        self.isProUser = isPro
        self.activeSubscription = foundActiveProduct
        self.ownedThemeProductIDs = ownedThemes

        // Persisti bridge keys: altre feature leggono queste chiavi
        UserDefaults.standard.set(isPro, forKey: Self.fastBootKey)
        persistOwnedThemes()

        logger.logInfo("IAPManager: updateEntitlements isProUser=\(isPro) product=\(foundActiveProduct?.id ?? "nil") ownedThemes=\(ownedThemes.count)")
    }

    /// Alias di compatibilità: mantiene l'API precedente al refactor entitlements.
    func updateSubscriptionStatus() async {
        await updateEntitlements()
    }

    // MARK: - Theme Ownership Helpers

    /// True se l'utente possiede individualmente il tema con quel product ID.
    /// NOTA: non considera la subscription Pro — usare in combinazione con `isProUser`.
    func ownsTheme(productID: String) -> Bool {
        return ownedThemeProductIDs.contains(productID)
    }

    /// Persiste il Set `ownedThemeProductIDs` su UserDefaults come array di stringhe.
    /// Chiamato ad ogni mutazione del Set per mantenere il fast-boot allineato.
    private func persistOwnedThemes() {
        let arr = Array(ownedThemeProductIDs)
        UserDefaults.standard.set(arr, forKey: Self.fastBootOwnedThemesKey)
    }

    // MARK: - Transaction Listener

    /// Listener per le transaction updates: rinnovi automatici, refund, family sharing,
    /// acquisti di temi singoli, ecc.
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            // Salta non verificate
            guard case .verified(let transaction) = result else { continue }

            await transaction.finish()
            await updateEntitlements()

            logger.logInfo("IAPManager: transaction update ricevuto per \(transaction.productID)")
        }
    }
}
