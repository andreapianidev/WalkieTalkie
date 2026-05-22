//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - PaywallView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

/// Paywall fullscreen per Talky Pro.
/// Da presentare via `.fullScreenCover(isPresented:)` passando un trigger per analytics.
struct PaywallView: View {
    // MARK: - Input

    /// Identifica da dove è stato aperto il paywall (es. "settings", "ad_limit", "feature_lock").
    let trigger: String

    // MARK: - Env

    @Environment(\.dismiss) private var dismiss
    @StateObject private var iap = IAPManager.shared

    // MARK: - State

    @State private var selectedProductID: String = ProductID.yearly.rawValue
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isPurchasing: Bool = false

    // MARK: - Computed

    /// Colore accent giallo dell'app (matching app icon)
    private var brandYellow: Color {
        Color(red: 1.0, green: 0.8, blue: 0.0) // #FFCC00
    }

    /// Sfondo crema chiaro per la card selezionata (annuale)
    private var creamBackground: Color {
        Color(red: 1.0, green: 0.98, blue: 0.92)
    }

    private var weeklyProduct: Product? {
        iap.products.first(where: { $0.id == ProductID.weekly.rawValue })
    }

    private var yearlyProduct: Product? {
        iap.products.first(where: { $0.id == ProductID.yearly.rawValue })
    }

    private var selectedProduct: Product? {
        iap.products.first(where: { $0.id == selectedProductID })
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Sfondo gradient dark
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.12, blue: 0.12), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    closeButtonRow

                    heroSection

                    featuresList

                    priceCards

                    ctaButton

                    apppleMandatoryFooter

                    footerLinks

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Analytics.logEvent("paywall_shown", parameters: [
                "trigger": trigger
            ])
            // Carica prodotti se non già caricati
            if iap.products.isEmpty {
                Task { try? await iap.loadProducts() }
            }
        }
        .onDisappear {
            Analytics.logEvent("paywall_dismissed", parameters: [
                "trigger": trigger
            ])
        }
        .alert("paywall.error_title".localized, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Sections

    private var closeButtonRow: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .accessibilityLabel("paywall.close".localized)
        }
        .padding(.top, 8)
    }

    private var heroSection: some View {
        VStack(spacing: 14) {
            // Icona "app-like": quadrato giallo arrotondato con figure.walk
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(brandYellow)
                    .frame(width: 92, height: 92)
                    .shadow(color: brandYellow.opacity(0.4), radius: 20, y: 8)

                Image(systemName: "figure.walk")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)
            }

            Text("paywall.title".localized)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("paywall.subtitle".localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "xmark.circle.fill", text: "paywall.feature.no_ads".localized)
            featureRow(icon: "antenna.radiowaves.left.and.right", text: "paywall.feature.unlimited_stations".localized)
            featureRow(icon: "globe", text: "paywall.feature.premium_international".localized)
            featureRow(icon: "mic.circle.fill", text: "paywall.feature.record_transmissions".localized)
            featureRow(icon: "lock.shield.fill", text: "paywall.feature.private_channels".localized)
            featureRow(icon: "paintpalette.fill", text: "paywall.feature.custom_themes".localized)
            featureRow(icon: "clock.arrow.circlepath", text: "paywall.feature.history".localized)
            featureRow(icon: "moon.zzz.fill", text: "paywall.feature.sleep_timer".localized)
            featureRow(icon: "slider.horizontal.3", text: "paywall.feature.equalizer".localized)
        }
        .padding(.vertical, 8)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.green)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.green.opacity(0.15)))

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)

            Spacer()
        }
    }

    // MARK: - Price Cards

    private var priceCards: some View {
        HStack(spacing: 12) {
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
        .padding(.vertical, 8)
    }

    private func priceCard(title: String, product: Product?, periodSuffix: String, productID: String, isYearly: Bool) -> some View {
        let isSelected = selectedProductID == productID
        let priceText = product?.displayPrice ?? "—"

        return ZStack(alignment: .top) {
            // Card
            VStack(spacing: 8) {
                if isYearly {
                    // Badge "PIÙ POPOLARE" sopra
                    Text("paywall.badge.most_popular".localized)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(brandYellow))
                        .offset(y: -12)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected && isYearly ? .black : .white)
                    .padding(.top, isYearly ? 0 : 12)

                Text(priceText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(isSelected && isYearly ? .black : .white)

                Text(periodSuffix)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected && isYearly ? .black.opacity(0.7) : .white.opacity(0.6))

                if isYearly {
                    Text("paywall.badge.save".localized)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green))
                        .padding(.top, 4)
                } else {
                    // Placeholder per allineare altezze
                    Spacer().frame(height: 22)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isYearly ? creamBackground : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? brandYellow : Color.white.opacity(0.15), lineWidth: isSelected ? 2.5 : 1)
            )
            .scaleEffect(isYearly && isSelected ? 1.05 : 1.0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedProductID = productID
            }
            HapticManager.shared.lightTap()
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
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(brandYellow))
            .shadow(color: brandYellow.opacity(0.35), radius: 16, y: 6)
        }
        .disabled(isPurchasing || selectedProduct == nil)
        .padding(.top, 8)
    }

    // MARK: - Apple-Mandatory Footer

    private var apppleMandatoryFooter: some View {
        Text("paywall.apple_footer".localized)
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private var footerLinks: some View {
        HStack(spacing: 8) {
            Button {
                Task { await performRestore() }
            } label: {
                Text("paywall.link.restore".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text("·")
                .foregroundColor(.white.opacity(0.4))

            Link(destination: URL(string: "https://www.andreapiani.com/terms")!) {
                Text("paywall.link.terms".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text("·")
                .foregroundColor(.white.opacity(0.4))

            Link(destination: URL(string: "https://www.andreapiani.com/privacy")!) {
                Text("paywall.link.privacy".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
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
                // Dismiss subito dopo acquisto andato a buon fine
                dismiss()
            }
        } catch {
            // Messaggio utente-friendly invece dell'errore tecnico
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

