//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - PaywallView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

/// Paywall fullscreen per Talky Pro.
///
/// Direzione estetica "Field Radio": pannello strumenti analogico —
/// superficie inchiostro/crema (NON gradient saas), tipografia SF Rounded
/// (richiama i display radio), card prezzo yearly che si "accende" come un
/// LED TX quando selezionata. Brand color #FFCC00 usato come accent di
/// stato, non come fondo decorativo.
///
/// Palette adattiva: la modalità scura segue ESCLUSIVAMENTE
/// `SettingsManager.isDarkModeEnabled` (preferenza dell'app), non il colorScheme
/// di sistema — coerente con il resto dell'app.
struct PaywallView: View {
    // MARK: - Input

    /// Identifica da dove è stato aperto il paywall (es. "settings", "ad_limit", "feature_lock").
    let trigger: String

    /// Repo pubblico di Talky. Linkato dalla nota "supporter" per rendere
    /// verificabile l'affermazione "il codice è pubblico" — è un link
    /// informativo, non un canale di pagamento alternativo all'IAP.
    private static let repositoryURL = "https://github.com/andreapianidev/WalkieTalkie"

    // MARK: - Env

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var iap = IAPManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var adManager = AdManager.shared
    @ObservedObject private var rewardedCoordinator = AdManager.shared.rewarded

    // MARK: - State

    @State private var selectedProductID: String = ProductID.yearly.rawValue
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isPurchasing: Bool = false
    @State private var heroAppeared: Bool = false
    @State private var didLogRewardedImpression: Bool = false

    // MARK: - Palette adattiva

    private var isAppDark: Bool { settingsManager.isDarkModeEnabled }

    private var brand: Color { Color(red: 1.0, green: 0.8, blue: 0.0) }
    private var brandDeep: Color { Color(red: 0.91, green: 0.71, blue: 0.0) }
    private var brandSoft: Color { brand.opacity(isAppDark ? 0.12 : 0.08) }

    private var bgPrimary: Color {
        isAppDark
            ? Color(red: 0.055, green: 0.051, blue: 0.043) // #0E0D0B
            : Color(red: 0.980, green: 0.969, blue: 0.941) // #FAF7F0
    }

    private var bgSubtle: Color {
        isAppDark
            ? Color(red: 0.122, green: 0.106, blue: 0.086) // #1F1B16
            : Color(red: 0.945, green: 0.925, blue: 0.871) // #F1ECDE
    }

    private var ink: Color {
        isAppDark
            ? Color(red: 0.957, green: 0.937, blue: 0.894) // #F4EFE4
            : Color(red: 0.086, green: 0.082, blue: 0.075) // #161513
    }

    private var inkSecondary: Color {
        isAppDark
            ? Color(red: 0.639, green: 0.604, blue: 0.545) // #A39A8B
            : Color(red: 0.361, green: 0.329, blue: 0.290) // #5C544A
    }

    private var hairline: Color { ink.opacity(isAppDark ? 0.10 : 0.10) }
    private var successColor: Color {
        isAppDark
            ? Color(red: 0.302, green: 0.808, blue: 0.522)
            : Color(red: 0.122, green: 0.478, blue: 0.302)
    }

    // MARK: - Computed products

    private var weeklyProduct: Product? {
        iap.products.first(where: { $0.id == ProductID.weekly.rawValue })
    }

    private var yearlyProduct: Product? {
        iap.products.first(where: { $0.id == ProductID.yearly.rawValue })
    }

    private var selectedProduct: Product? {
        iap.products.first(where: { $0.id == selectedProductID })
    }

    private var lifetimeProduct: Product? {
        iap.products.first(where: { $0.id == ProductID.lifetimeID })
    }

    // MARK: - Confronto annuale / settimanale
    //
    // Tutto calcolato dai prezzi veri di StoreKit, mai scritto a mano: la
    // percentuale di risparmio era una stringa fissa ("Save 81%") ed è rimasta
    // ferma quando il listino è cambiato, cioè ha iniziato a dire il falso a
    // schermo. Derivandola dai `Product` non può più divergere dal listino,
    // qualunque cosa si decida su App Store Connect.

    /// Quanto costerebbe un anno pagando alla settimana, nella valuta dell'utente.
    private var yearlyCostIfPaidWeekly: Decimal? {
        guard let weekly = weeklyProduct else { return nil }
        return weekly.price * 52
    }

    /// Risparmio percentuale dell'annuale rispetto al settimanale, arrotondato.
    /// `nil` se manca un prodotto o se l'annuale non conviene davvero: in quel
    /// caso il badge sparisce invece di vantare uno sconto inesistente.
    private var yearlySavingsPercent: Int? {
        guard let yearly = yearlyProduct?.price,
              let weeklyYear = yearlyCostIfPaidWeekly,
              weeklyYear > 0, yearly < weeklyYear else { return nil }
        let ratio = (weeklyYear - yearly) / weeklyYear * 100
        let percent = Int(NSDecimalNumber(decimal: ratio).doubleValue.rounded())
        return percent > 0 ? percent : nil
    }

    /// "€155,48" — il costo annuo pagando a settimana, formattato nella valuta
    /// del prodotto così da restare coerente con `displayPrice`.
    private var weeklyYearlyEquivalentText: String? {
        guard let weekly = weeklyProduct, let total = yearlyCostIfPaidWeekly else { return nil }
        return total.formatted(weekly.priceFormatStyle)
    }

    /// Durata di un periodo StoreKit espressa in giorni. Serve solo per dire
    /// "3 giorni gratis" a schermo, quindi mese = 30 e anno = 365 vanno bene:
    /// le prove gratuite di Talky si misurano in giorni, gli altri casi ci sono
    /// per non far dipendere il badge da un'assunzione sulla configurazione.
    private static func days(in period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day:   return period.value
        case .week:  return period.value * 7
        case .month: return period.value * 30
        case .year:  return period.value * 365
        @unknown default: return period.value
        }
    }

    /// Durata della prova gratuita dell'annuale, se configurata su ASC.
    /// Letta da StoreKit e non scritta nel codice: se un giorno l'offerta viene
    /// tolta o cambiata, il badge segue senza bisogno di una nuova build.
    private var yearlyIntroOffer: Product.SubscriptionOffer? {
        guard let offer = yearlyProduct?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return offer
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    topBar
                    heroSection
                    hairlineDivider
                    featuresList
                    hairlineDivider
                    supporterNote
                    priceCards
                    yearlyComparisonLine
                    freeTrialBadge
                    ctaButton
                    lifetimeOption
                    rewardedSecondaryCTA
                    appleLegalFooter
                    footerLinks
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Palette segue le preferenze dell'app, NON il colorScheme di sistema.
        .preferredColorScheme(isAppDark ? .dark : .light)
        .onAppear {
            // Blocca l'app-open finché il paywall è a schermo: un annuncio a
            // tutto schermo sopra la pagina che vende "niente pubblicità" è il
            // modo più diretto per perdere sia la vendita sia la recensione.
            adManager.isPaywallVisible = true
            adManager.appOpen.suppressNextResume = true
            Analytics.logEvent("paywall_shown", parameters: ["trigger": trigger])
            if iap.products.isEmpty {
                Task { try? await iap.loadProducts() }
            }
            // Staggered hero entrance — una sola animazione, niente loop.
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.05)) {
                heroAppeared = true
            }
        }
        .onDisappear {
            adManager.isPaywallVisible = false
            Analytics.logEvent("paywall_dismissed", parameters: ["trigger": trigger])
            // Chiuso senza comprare: si registra anche QUALE prodotto era
            // selezionato. È il numero che distingue "il prezzo non convince"
            // da "non ha capito cosa stava comprando", e senza di lui ogni
            // modifica al paywall sarebbe fatta al buio. Se nel frattempo
            // l'utente è diventato Pro, l'uscita non è un abbandono.
            if !iap.isProUser && !iap.hasLifetime {
                PaywallTriggerManager.shared.recordDismissedWithoutPurchase(
                    trigger: trigger, selectedProductID: selectedProductID)
            }
        }
        .alert("paywall.error_title".localized, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Background

    /// Un solo RadialGradient molto largo, sottilissimo brand@4% top-leading.
    /// Percettibile a livello inconscio come "warmth" del pannello, mai
    /// leggibile come "decorative gradient da landing AI".
    private var backgroundLayer: some View {
        ZStack {
            bgPrimary.ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [brand.opacity(isAppDark ? 0.07 : 0.05), .clear]),
                center: .topLeading,
                startRadius: 10,
                endRadius: 480
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Circle()
                    .fill(brand)
                    .frame(width: 6, height: 6)
                    .shadow(color: isAppDark ? brand.opacity(0.6) : .clear, radius: 4)
                Text("paywall.brand_label".localized)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(3.5)
                    .foregroundColor(ink)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ink)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(ink.opacity(isAppDark ? 0.08 : 0.05))
                    )
            }
            .accessibilityLabel("paywall.close".localized)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroIcon
                .scaleEffect(heroAppeared ? 1.0 : 0.85)
                .opacity(heroAppeared ? 1.0 : 0.0)

            VStack(alignment: .leading, spacing: 6) {
                Text("paywall.title".localized)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(ink)
                    .lineSpacing(-2)
                    .multilineTextAlignment(.leading)

                Text("paywall.subtitle".localized)
                    .font(.system(size: 15))
                    .foregroundColor(inkSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(heroAppeared ? 1.0 : 0.0)
            .offset(y: heroAppeared ? 0 : 8)
        }
        .padding(.top, 4)
    }

    private var heroIcon: some View {
        ZStack {
            // Halo: glow solo in dark, ring sottile in light.
            if isAppDark {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(brand.opacity(0.0))
                    .frame(width: 110, height: 110)
                    .shadow(color: brand.opacity(0.35), radius: 28, x: 0, y: 0)
            } else {
                Circle()
                    .stroke(brand.opacity(0.20), lineWidth: 8)
                    .blur(radius: 12)
                    .frame(width: 110, height: 110)
            }

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(brand)
                .frame(width: 88, height: 88)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.black)
        }
    }

    // MARK: - Features

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow("xmark.circle.fill", "paywall.feature.no_ads")
            featureRow("antenna.radiowaves.left.and.right", "paywall.feature.unlimited_stations")
            featureRow("globe", "paywall.feature.premium_international")
            featureRow("mic.circle.fill", "paywall.feature.record_transmissions")
            featureRow("lock.shield.fill", "paywall.feature.private_channels")
            featureRow("paintpalette.fill", "paywall.feature.custom_themes")
            featureRow("clock.arrow.circlepath", "paywall.feature.history")
            featureRow("moon.zzz.fill", "paywall.feature.sleep_timer")
            featureRow("slider.horizontal.3", "paywall.feature.equalizer")
        }
    }

    private func featureRow(_ symbol: String, _ key: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(brand)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(brandSoft)
                )

            Text(key.localized)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ink)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Supporter note

    /// Nota "chi c'è dietro l'app". Sta subito prima delle card prezzo perché
    /// è il *perché* che dà senso al *quanto*: Talky è scritta da una persona
    /// sola e il codice è pubblico, quindi Pro non è un lucchetto ma un
    /// contributo. Volutamente sobria — nessun accent giallo pieno, nessun
    /// bottone: se urla, sembra una raccolta fondi e perde credibilità.
    private var supporterNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(brand)

                Text("paywall.support.eyebrow".localized)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2.0)
                    .foregroundColor(inkSecondary)
            }

            Text("paywall.support.title".localized)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("paywall.support.body".localized)
                .font(.system(size: 13))
                .foregroundColor(inkSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Analytics.logEvent("paywall_github_tapped", parameters: ["trigger": trigger])
                if let url = URL(string: Self.repositoryURL) {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text("paywall.support.github".localized)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(ink.opacity(0.75))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(bgSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hairline, lineWidth: 1)
        )
    }

    // MARK: - Hairline divider

    private var hairlineDivider: some View {
        Rectangle()
            .frame(height: 0.5)
            .foregroundColor(hairline)
            .padding(.horizontal, -20) // estendi edge-to-edge
    }

    // MARK: - Price cards

    private var priceCards: some View {
        HStack(alignment: .top, spacing: 12) {
            priceCard(
                title: "paywall.plan.weekly".localized,
                product: weeklyProduct,
                periodSuffix: "paywall.plan.weekly_suffix".localized,
                productID: ProductID.weekly.rawValue,
                isYearly: false
            )

            priceCard(
                title: "paywall.plan.yearly".localized,
                product: yearlyProduct,
                periodSuffix: "paywall.plan.yearly_suffix".localized,
                productID: ProductID.yearly.rawValue,
                isYearly: true
            )
        }
        .padding(.top, 8)
    }

    /// Ancoraggio del prezzo: da solo "€19,99 all'anno" non dice niente, accanto
    /// a quanto costerebbe la stessa cosa pagata a settimana diventa un confronto.
    /// Compare solo se entrambi i prodotti sono caricati, così una paywall aperta
    /// offline non mostra una frase monca.
    @ViewBuilder
    private var yearlyComparisonLine: some View {
        if let equivalent = weeklyYearlyEquivalentText,
           let yearly = yearlyProduct?.displayPrice {
            HStack(spacing: 5) {
                Image(systemName: "equal.circle")
                    .font(.system(size: 11, weight: .semibold))
                Text(String(format: "paywall.compare.weekly_vs_yearly".localized,
                            yearly, equivalent))
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(inkSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, -8)
        }
    }

    /// "3 giorni gratis, poi €19,99 all'anno". La durata arriva dall'offerta
    /// StoreKit, non da una costante: l'offerta vive su App Store Connect e può
    /// cambiare senza passare da qui.
    @ViewBuilder
    private var freeTrialBadge: some View {
        if let offer = yearlyIntroOffer,
           let yearly = yearlyProduct?.displayPrice {
            let days = Self.days(in: offer.period)
            HStack(spacing: 5) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(String(format: "paywall.trial.badge".localized, days, yearly))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(successColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, -4)
        }
    }

    private func priceCard(title: String,
                           product: Product?,
                           periodSuffix: String,
                           productID: String,
                           isYearly: Bool) -> some View {
        let isSelected = selectedProductID == productID
        let priceText = product?.displayPrice ?? "—"

        return VStack(alignment: .leading, spacing: 8) {
            // Mini "PIÙ POPOLARE" tag flush-top per yearly
            if isYearly {
                Text("paywall.badge.most_popular".localized)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(brand))
            } else {
                // Placeholder per allineare l'altezza con la card yearly
                Color.clear.frame(height: 18)
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? selectedFG(isYearly: isYearly) : inkSecondary)
                .padding(.top, 4)

            Text(priceText)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(isSelected ? selectedFG(isYearly: isYearly) : ink)

            Text(periodSuffix)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected
                                 ? selectedFG(isYearly: isYearly).opacity(0.65)
                                 : inkSecondary)

            if isYearly, let percent = yearlySavingsPercent {
                Text(String(format: "paywall.badge.save".localized, percent))
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(successColor))
                    .padding(.top, 2)
            } else {
                Color.clear.frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(cardBackground(isYearly: isYearly, isSelected: isSelected))
        .overlay(cardBorder(isYearly: isYearly, isSelected: isSelected))
        .scaleEffect(isYearly && isSelected ? 1.04 : 1.0)
        .shadow(color: isSelected ? selectedShadow(isYearly: isYearly) : .clear,
                radius: isAppDark ? 18 : 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                selectedProductID = productID
            }
            HapticManager.shared.lightTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    /// Foreground color quando la card è "active". La card yearly selezionata
    /// inverte la superficie ("TX active LED"): in dark il fondo diventa brand
    /// (giallo) → testo nero; in light il fondo diventa ink (off-black) → testo
    /// crema. Le altre card mantengono il foreground neutro.
    private func selectedFG(isYearly: Bool) -> Color {
        guard isYearly else { return ink }
        return isAppDark ? .black : bgPrimary
    }

    @ViewBuilder
    private func cardBackground(isYearly: Bool, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if isYearly && isSelected {
            // "TX active": invert
            shape.fill(isAppDark ? brand : ink)
        } else {
            shape.fill(bgSubtle)
        }
    }

    @ViewBuilder
    private func cardBorder(isYearly: Bool, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if isSelected {
            shape.stroke(brand, lineWidth: 2)
        } else {
            shape.stroke(hairline, lineWidth: 1)
        }
    }

    private func selectedShadow(isYearly: Bool) -> Color {
        if isYearly {
            return brand.opacity(isAppDark ? 0.30 : 0.15)
        } else {
            return brand.opacity(isAppDark ? 0.18 : 0.08)
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            Task { await performPurchase() }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                } else {
                    Text("paywall.cta.start".localized)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    Capsule().fill(brand)
                    if isAppDark {
                        // sottile bordo brand-deep per ancorare il bottone al fondo scuro
                        Capsule().stroke(brandDeep, lineWidth: 1)
                    }
                }
            )
            .shadow(color: brand.opacity(isAppDark ? 0.35 : 0.20),
                    radius: 18, x: 0, y: 6)
        }
        .disabled(isPurchasing || selectedProduct == nil)
        .padding(.top, 12)
        .accessibilityLabel("paywall.cta.start".localized)
    }

    // MARK: - Acquisto a vita

    /// L'alternativa "paga una volta e basta". Sta SOTTO il CTA principale, non
    /// fra le card prezzo: è una scelta diversa in natura, non un terzo piano da
    /// confrontare a colpo d'occhio con settimanale e annuale. Chi arriva qui
    /// cercando l'abbonamento lo trova sopra; chi non vuole abbonarsi affatto
    /// trova questo, e per lui è l'unica riga che conta.
    ///
    /// Esiste perché l'hanno chiesto gli utenti, testualmente: "a pay once model
    /// would be appreciated", "the addition of ads and subscription ruined it".
    @ViewBuilder
    private var lifetimeOption: some View {
        if iap.hasLifetime {
            // Già comprato: niente da vendere, solo conferma.
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(successColor)
                Text("paywall.lifetime.owned".localized)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(successColor.opacity(isAppDark ? 0.14 : 0.10))
            )
            .padding(.top, 4)
        } else if let lifetime = lifetimeProduct {
            Button {
                Task { await performLifetimePurchase(lifetime) }
            } label: {
                VStack(spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "infinity")
                            .font(.system(size: 13, weight: .bold))
                        Text("paywall.lifetime.cta".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text(lifetime.displayPrice)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundColor(ink)

                    Text("paywall.lifetime.subtitle".localized)
                        .font(.system(size: 11))
                        .foregroundColor(inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ink.opacity(isAppDark ? 0.22 : 0.18), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)
            .opacity(isPurchasing ? 0.5 : 1.0)
            .padding(.top, 4)
        }
    }

    // MARK: - Rewarded fallback

    /// CTA secondario e volutamente sottotono: chi non è pronto ad abbonarsi può
    /// guardare un video e ottenere 1 ora senza pubblicità. Vive sotto il bottone
    /// principale così non gli ruba attenzione, ma intercetta ogni utente Free che
    /// arriva al paywall (da qualunque trigger: stazione Pro, banner, feature-gate).
    /// È questo il punto che porta finalmente impression sul rewarded `walkiepremio`.
    /// `source` = `trigger`, così su Firebase vediamo quale funnel converte.
    @ViewBuilder
    private var rewardedSecondaryCTA: some View {
        if !adManager.adsRemoved {
            Button {
                adManager.presentRewardedRemoveAds(source: trigger)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("watch_ad_remove_ads".localized)
                        .font(.system(size: 14, weight: .semibold))
                    if !rewardedCoordinator.isAdReady {
                        ProgressView()
                            .controlSize(.mini)
                            .padding(.leading, 2)
                    }
                }
                .foregroundColor(ink.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!rewardedCoordinator.isAdReady)
            .opacity(rewardedCoordinator.isAdReady ? 1.0 : 0.55)
            .onAppear {
                guard !didLogRewardedImpression else { return }
                didLogRewardedImpression = true
                Analytics.logEvent("rewarded_cta_shown", parameters: ["source": trigger])
            }
        }
    }

    // MARK: - Legal

    /// Footer Apple-mandatory (auto-rinnovo). Boxed in ultraThinMaterial solo
    /// in dark, plain in light per evitare l'estetica "vetrino design app".
    private var appleLegalFooter: some View {
        Text("paywall.apple_footer".localized)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(inkSecondary.opacity(0.85))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isAppDark {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(bgSubtle.opacity(0.6))
                    }
                }
            )
    }

    private var footerLinks: some View {
        HStack(spacing: 8) {
            Spacer()
            Button {
                Task { await performRestore() }
            } label: {
                Text("paywall.link.restore".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(inkSecondary)
            }

            Text("·").foregroundColor(inkSecondary.opacity(0.5))

            Link(destination: URL(string: "https://walkie-talky.vercel.app/terms")!) {
                Text("paywall.link.terms".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(inkSecondary)
            }

            Text("·").foregroundColor(inkSecondary.opacity(0.5))

            Link(destination: URL(string: "https://walkie-talky.vercel.app/privacy")!) {
                Text("paywall.link.privacy".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(inkSecondary)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func performPurchase() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let success = try await iap.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = "paywall.error.purchase_failed".localized
            showErrorAlert = true
        }
    }

    private func performLifetimePurchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        Analytics.logEvent("lifetime_purchase_initiated", parameters: ["trigger": trigger])
        do {
            if try await iap.purchase(product) {
                dismiss()
            }
        } catch {
            errorMessage = "paywall.error.purchase_failed".localized
            showErrorAlert = true
        }
    }

    private func performRestore() async {
        do {
            try await iap.restorePurchases()
            if iap.isProUser {
                dismiss()
            } else {
                errorMessage = "paywall.error.no_purchases".localized
                showErrorAlert = true
            }
        } catch {
            errorMessage = "paywall.error.restore_failed".localized
            showErrorAlert = true
        }
    }
}
