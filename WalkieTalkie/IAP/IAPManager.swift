//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - IAPManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import StoreKit
import Combine
import FirebaseAnalytics

/// Gestisce gli acquisti in-app (StoreKit 2) per Talky Pro e per il themes pack.
/// Singleton @MainActor che espone lo stato dell'abbonamento e del pack temi
/// via @Published properties.
///
/// Modello di unlock dei temi Pro-locked:
/// - Utente con subscription Talky Pro → accede a TUTTI i temi.
/// - Utente con themes pack (non-consumable one-shot) → accede a TUTTI i temi.
/// - Utente senza né l'uno né l'altro → solo temi free.
@MainActor
final class IAPManager: ObservableObject {
    static let shared = IAPManager()

    // MARK: - Published State

    @Published var products: [Product] = []
    @Published var isProUser: Bool = false
    @Published var activeSubscription: Product? = nil
    @Published var isLoading: Bool = false

    /// True se l'utente ha acquistato il themes pack non-consumable.
    /// Le View possono osservarlo per aggiornare l'UI dei badge "PRO" sui temi.
    @Published var hasThemesPack: Bool = false

    // MARK: - Private

    private let logger = Logger.shared
    private var transactionListenerTask: Task<Void, Never>? = nil

    /// Bridge fast-boot per `isProUser`: altre feature leggono questa chiave
    /// per evitare di attendere updateEntitlements() all'avvio.
    private static let fastBootKey = "fastboot_isProUser"

    /// Bridge fast-boot per il themes pack. ThemeManager legge questa chiave
    /// per validare l'accesso senza importare IAPManager.
    private static let fastBootThemesPackKey = "fastboot_hasThemesPack"

    #if DEBUG && targetEnvironment(simulator)
    private var debugSimulatedProOverride: Bool? = nil
    #endif

    // MARK: - Lifecycle

    private init() {
        self.isProUser = UserDefaults.standard.bool(forKey: Self.fastBootKey)
        self.hasThemesPack = UserDefaults.standard.bool(forKey: Self.fastBootThemesPackKey)

        self.transactionListenerTask = Task { [weak self] in
            await self?.listenForTransactions()
        }

        logger.logInfo("IAPManager inizializzato (fast-boot isProUser=\(isProUser), hasThemesPack=\(hasThemesPack))")
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        self.isProUser = UserDefaults.standard.bool(forKey: Self.fastBootKey)
        self.hasThemesPack = UserDefaults.standard.bool(forKey: Self.fastBootThemesPackKey)

        do {
            try await loadProducts()
        } catch {
            logger.logError(error, context: "IAPManager.bootstrap loadProducts")
        }
        await updateEntitlements()
    }

    // MARK: - Products

    func loadProducts() async throws {
        isLoading = true
        defer { isLoading = false }

        let requested = ProductID.allIDs
        let storeProducts = try await Product.products(for: requested)
        self.products = storeProducts.sorted { lhs, rhs in
            return lhs.price < rhs.price
        }
        logger.logInfo("IAPManager: caricati \(self.products.count)/\(requested.count) prodotti")

        if self.products.count < requested.count {
            let returnedIDs = Set(storeProducts.map(\.id))
            let missing = requested.filter { !returnedIDs.contains($0) }
            logger.logWarning("""
            IAPManager: \(missing.count) prodotti mancanti dallo Store. Verifica:
              1. Gli ID corrispondono ESATTAMENTE a quelli in App Store Connect (case-sensitive)
              2. I prodotti sono "Pronto per la revisione" o approvati (non "Metadati mancanti")
              3. L'app è firmata con lo stesso bundle ID del record ASC (com.immaginet.talky)
              4. Per testing locale: collega WalkieTalkie/IAP/Talky.storekit allo scheme
                 (Edit Scheme → Run → Options → StoreKit Configuration)
            Mancanti: \(missing.joined(separator: ", "))
            """)
        }
    }

    // MARK: - Purchase

    /// Avvia l'acquisto di una subscription. Ritorna `true` se l'acquisto
    /// si conclude con successo (verificato), `false` se cancellato o pending.
    func purchase(_ product: Product) async throws -> Bool {
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
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updateEntitlements()

                    Analytics.logEvent("purchase_completed", parameters: [
                        "product_id": product.id,
                        "revenue": NSDecimalNumber(decimal: product.price).doubleValue
                    ])
                    logger.logInfo("IAPManager: purchase_completed \(product.id)")
                    return true

                case .unverified(_, let error):
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

    /// Avvia l'acquisto del themes pack (non-consumable one-shot).
    /// Stesso flusso di `purchase(_:)` ma logga eventi Firebase dedicati
    /// (`themes_pack_*`) e su successo flagga `hasThemesPack = true`.
    ///
    /// - Returns: `true` se acquisto verificato; `false` se cancellato/pending.
    /// - Throws: errore se il prodotto non è disponibile o non verificato.
    func purchaseThemesPack() async throws -> Bool {
        guard let product = products.first(where: { $0.id == ProductID.themesPackID }) else {
            let error = NSError(
                domain: "IAPManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Themes pack product not loaded"]
            )
            Analytics.logEvent("themes_pack_purchase_failed", parameters: [
                "error": "product_not_loaded"
            ])
            logger.logError(error, context: "IAPManager.purchaseThemesPack: product not loaded")
            throw error
        }

        Analytics.logEvent("themes_pack_purchase_initiated", parameters: [
            "product_id": product.id
        ])
        logger.logInfo("IAPManager: themes_pack_purchase_initiated")

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    self.hasThemesPack = true
                    UserDefaults.standard.set(true, forKey: Self.fastBootThemesPackKey)
                    await updateEntitlements()

                    Analytics.logEvent("themes_pack_purchase_completed", parameters: [
                        "product_id": product.id,
                        "revenue": NSDecimalNumber(decimal: product.price).doubleValue
                    ])
                    logger.logInfo("IAPManager: themes_pack_purchase_completed")
                    return true

                case .unverified(_, let error):
                    Analytics.logEvent("themes_pack_purchase_failed", parameters: [
                        "error": "unverified: \(error.localizedDescription)"
                    ])
                    logger.logError(error, context: "IAPManager.purchaseThemesPack: unverified")
                    throw error
                }

            case .userCancelled:
                logger.logInfo("IAPManager: utente ha annullato l'acquisto themes pack")
                return false

            case .pending:
                logger.logInfo("IAPManager: themes pack purchase pending")
                return false

            @unknown default:
                logger.logWarning("IAPManager: themes pack purchase result sconosciuto")
                return false
            }
        } catch {
            Analytics.logEvent("themes_pack_purchase_failed", parameters: [
                "error": error.localizedDescription
            ])
            logger.logError(error, context: "IAPManager.purchaseThemesPack")
            throw error
        }
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        try await AppStore.sync()
        await updateEntitlements()

        if let active = activeSubscription {
            Analytics.logEvent("subscription_restored", parameters: [
                "product_id": active.id
            ])
            logger.logInfo("IAPManager: subscription_restored \(active.id)")
        } else {
            logger.logInfo("IAPManager: restorePurchases completato (nessun abbonamento attivo)")
        }

        if hasThemesPack {
            Analytics.logEvent("themes_pack_restored", parameters: [:])
            logger.logInfo("IAPManager: themes pack ripristinato")
        }
    }

    // MARK: - Entitlements

    /// Itera le entitlement correnti, salta le non verificate, e aggiorna
    /// sia lo stato subscription sia il flag `hasThemesPack`. Persiste i bridge.
    func updateEntitlements() async {
        var foundActiveProduct: Product? = nil
        var isPro = false
        var packOwned = false

        for await result in Transaction.currentEntitlements {
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

            // Caso B: themes pack non-consumable
            if ProductID.isThemesPack(transaction.productID) {
                if transaction.revocationDate == nil {
                    packOwned = true
                }
                continue
            }
        }

        self.isProUser = isPro
        self.activeSubscription = foundActiveProduct
        self.hasThemesPack = packOwned

        UserDefaults.standard.set(isPro, forKey: Self.fastBootKey)
        UserDefaults.standard.set(packOwned, forKey: Self.fastBootThemesPackKey)

        logger.logInfo("IAPManager: updateEntitlements isProUser=\(isPro) product=\(foundActiveProduct?.id ?? "nil") hasThemesPack=\(packOwned)")

        #if DEBUG && targetEnvironment(simulator)
        if let override = debugSimulatedProOverride {
            self.isProUser = override
            UserDefaults.standard.set(override, forKey: Self.fastBootKey)
            logger.logInfo("IAPManager: DEBUG override applicato in updateEntitlements → isProUser=\(override)")
        }
        #endif
    }

    /// Alias di compatibilità: mantiene l'API precedente al refactor entitlements.
    func updateSubscriptionStatus() async {
        await updateEntitlements()
    }

    #if DEBUG && targetEnvironment(simulator)
    func applyDebugSimulatedTier(isPro: Bool) {
        debugSimulatedProOverride = isPro
        self.isProUser = isPro
        UserDefaults.standard.set(isPro, forKey: Self.fastBootKey)
        logger.logInfo("IAPManager DEBUG override: simulazione tier=\(isPro ? "PRO" : "FREE")")
    }
    #endif

    // MARK: - Transaction Listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }

            await transaction.finish()
            await updateEntitlements()

            logger.logInfo("IAPManager: transaction update ricevuto per \(transaction.productID)")
        }
    }
}
