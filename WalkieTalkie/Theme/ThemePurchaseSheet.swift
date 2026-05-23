//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemePurchaseSheet.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

/// Sheet di acquisto del "Themes Pack" non-consumable: sblocca tutti gli 11
/// temi Pro-locked in un'unica transazione one-shot. Mostra preview del tema
/// che ha innescato il tap e due CTA: acquisto pack oppure passaggio al
/// paywall subscription completo via `onSubscribeTap`.
struct ThemePurchaseSheet: View {

    // MARK: - Input

    /// Tema che l'utente ha provato a selezionare. Usato solo come preview
    /// visuale nell'hero — l'acquisto sblocca comunque TUTTI i temi.
    let theme: Theme

    /// Callback invocata quando l'utente sceglie di sottoscrivere Talky Pro
    /// invece del pack. La sheet si chiude e il chiamante apre il paywall.
    let onSubscribeTap: () -> Void

    // MARK: - Env

    @Environment(\.dismiss) private var dismiss
    @StateObject private var iap = IAPManager.shared

    // MARK: - State

    @State private var isPurchasing: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    // MARK: - Computed

    private var brandYellow: Color {
        Color(red: 1.0, green: 0.8, blue: 0.0)
    }

    private var metadata: ThemeMetadata {
        ThemeRegistry.metadata(for: theme)
    }

    /// StoreKit product corrispondente al themes pack, se caricato.
    private var product: Product? {
        iap.products.first(where: { $0.id == ProductID.themesPackID })
    }

    /// Prezzo da mostrare: preferisce `displayPrice` da StoreKit (localizzato),
    /// fallback al prezzo nominale del pack se i prodotti non sono caricati.
    private var priceText: String {
        if let p = product { return p.displayPrice }
        return "€4,99"
    }

    private var isAnimatedTheme: Bool {
        theme == .blackHole || theme == .galaxy
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.12, blue: 0.12), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    closeRow
                    heroPreview
                    titleSection
                    valueProps
                    purchaseButton
                    orDivider
                    subscribeButton
                    appleFooter
                    footerLinks
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Analytics.logEvent("themes_pack_sheet_shown", parameters: [
                "trigger_theme": theme.rawValue
            ])
            if iap.products.isEmpty {
                Task { try? await iap.loadProducts() }
            }
        }
        .alert("paywall.error_title".localized, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Sections

    private var closeRow: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .accessibilityLabel("paywall.close".localized)
        }
        .padding(.top, 8)
    }

    private var heroPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(metadata.accentColor)
                .frame(width: 160, height: 160)
                .overlay(
                    Group {
                        if isAnimatedTheme {
                            AnimatedThemePreview(theme: theme)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        }
                    }
                )
                .overlay(
                    Image(systemName: metadata.iconName)
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: isAnimatedTheme ? .black.opacity(0.55) : .clear, radius: 6)
                )
                .shadow(color: metadata.accentColor.opacity(0.4), radius: 22, y: 10)
        }
        .padding(.top, 8)
    }

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("themes_pack.title".localized)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("themes_pack.subtitle".localized)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    /// 3 bullet rapidi che spiegano cosa c'è nel pack.
    private var valueProps: some View {
        VStack(alignment: .leading, spacing: 10) {
            valuePropRow(icon: "paintbrush.pointed.fill",
                         text: "themes_pack.prop.all_themes".localized)
            valuePropRow(icon: "infinity",
                         text: "themes_pack.prop.forever".localized)
            valuePropRow(icon: "checkmark.seal.fill",
                         text: "themes_pack.prop.one_time".localized)
        }
        .padding(.horizontal, 8)
    }

    private func valuePropRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(brandYellow)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
    }

    /// CTA principale: acquisto del themes pack.
    private var purchaseButton: some View {
        Button {
            Task { await performPurchase() }
        } label: {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                } else {
                    Text("themes_pack.cta_buy".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("·")
                        .foregroundColor(.black.opacity(0.5))
                    Text(priceText)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(brandYellow))
            .shadow(color: brandYellow.opacity(0.35), radius: 16, y: 6)
        }
        .disabled(isPurchasing || product == nil)
        .padding(.top, 8)
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
            Text("theme_purchase.or".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    private var subscribeButton: some View {
        Button {
            Analytics.logEvent("themes_pack_subscribe_tap", parameters: [
                "trigger_theme": theme.rawValue
            ])
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onSubscribeTap()
            }
        } label: {
            VStack(spacing: 4) {
                Text("theme_purchase.subscribe_title".localized)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("theme_purchase.subscribe_subtitle".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(brandYellow.opacity(0.5), lineWidth: 1.5)
            )
        }
    }

    private var appleFooter: some View {
        Text("theme_purchase.apple_footer".localized)
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 4)
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
            .disabled(isPurchasing)

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
    }

    // MARK: - Actions

    private func performPurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let success = try await iap.purchaseThemesPack()
            if success {
                // Applica subito il tema che ha triggherato il paywall — best UX.
                _ = ThemeManager.shared.setTheme(theme)
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
            if ThemeManager.shared.canAccess(theme: theme) {
                _ = ThemeManager.shared.setTheme(theme)
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

// MARK: - Preview

#if DEBUG
struct ThemePurchaseSheet_Previews: PreviewProvider {
    static var previews: some View {
        ThemePurchaseSheet(theme: .galaxy, onSubscribeTap: {})
    }
}
#endif
