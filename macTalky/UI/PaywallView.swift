//creato da Andrea Piani - 01/08/26 - https://www.andreapiani.com - PaywallView.swift
//  macTalky
//
//  Paywall Talky Pro. Stessi prodotti App Store dell'app iOS (universal
//  purchase: stesso bundle ID → un acquisto vale su iPhone, iPad e Mac):
//  - ProWeeklyWT / ProAnnualWT (subscription "Talky Pro")
//  - app.immaginet.talky.themes.allpack (non-consumable temi)

import SwiftUI
import StoreKit
import AppKit

struct PaywallView: View {
    @EnvironmentObject private var iap: IAPManager
    @Environment(\.dismiss) private var dismiss

    @State private var purchasing = false
    @State private var errorMessage: String?
    /// Altezza del contenuto che scorre, misurata: la sheet non e' piu' alta
    /// del necessario e non supera lo schermo.
    @State private var contentHeight: CGFloat = 0

    private var scrollHeight: CGFloat {
        // Tasti, link legali e barra del titolo stanno fuori dallo scroll.
        let room = (NSScreen.main?.visibleFrame.height ?? 800) - 200
        return min(contentHeight > 0 ? contentHeight : 640, max(room, 320))
    }

    private var weekly: Product? { iap.products.first { $0.id == ProductID.weekly.rawValue } }
    private var yearly: Product? { iap.products.first { $0.id == ProductID.yearly.rawValue } }
    private var themesPack: Product? { iap.products.first { $0.id == ProductID.themesPackID } }
    private var lifetime: Product? { iap.products.first { $0.id == ProductID.lifetimeID } }

    var body: some View {
        VStack(spacing: 0) {
            // Scorre il contenuto, non i tasti e i link legali: Terms e
            // Privacy (3.1.2) restano visibili anche su uno schermo basso,
            // ora che i piani sono tre e la sheet e' cresciuta.
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Text("TALKY PRO")
                            .font(.vfd(26, weight: .heavy))
                            .kerning(4)
                            .foregroundStyle(Talky.amber)
                            .shadow(color: Talky.amberDeep.opacity(0.7), radius: 10)
                        Text(MacString.onePurchase.text)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Talky.dim)
                    }
                    .padding(.top, 26)

                    // Cosa comprende il Pro: la stessa lista della paywall iOS e di
                    // "il tuo Talky Pro". Chi e' gia' Pro vede anche cosa fa ogni voce
                    // e dove si trova, cosi' la paywall diventa la pagina del suo Pro.
                    ConsolePanel(padding: 14) {
                        VStack(alignment: .leading, spacing: iap.isProUser ? 12 : 9) {
                            if iap.isProUser {
                                Text(Tour.text("tour.yourpro.title").uppercased())
                                    .font(.vfd(11, weight: .bold))
                                    .kerning(1.6)
                                    .foregroundStyle(Talky.amber)
                            }
                            ForEach(ProPerk.here) { perk in
                                feature(perk, detailed: iap.isProUser)
                            }
                        }
                    }
                    .frame(width: 380)

                    if !iap.isProUser {
                        supporterNote
                            .frame(width: 380)
                    }

                    if iap.isProUser {
                        // La nota del developer qui non serve: il grazie e' questo, e
                        // ogni riga in piu' allunga la sheet.
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Talky.signal)
                            Text(Tour.text("tour.yourpro.thanks"))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Talky.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 380, alignment: .leading)
                    } else if iap.products.isEmpty {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text(MacString.loadingProducts.text)
                                .font(.system(size: 11))
                                .foregroundStyle(Talky.dim)
                            // Prima qui c'era una nota per lo sviluppatore (App Store Connect):
                            // a chi compra serve sapere cosa fare, non come si configura lo Store.
                            Text(MacString.loadingHint.text)
                                .font(.system(size: 10))
                                .foregroundStyle(Talky.dim.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 340)
                        .padding(.vertical, 10)
                    } else {
                        // Il per sempre e' il terzo piano, accanto agli altri e con lo
                        // stesso disegno: sotto, in piccolo, non lo vedeva nessuno, ed e'
                        // quello che vende appena lo si vede. In evidenza resta l'annuale.
                        HStack(spacing: 10) {
                            if let weekly {
                                planCard(weekly, title: MacString.weekly.text, highlight: false)
                            }
                            if let yearly {
                                planCard(yearly, title: MacString.yearly.text, highlight: true)
                            }
                            if let lifetime, !iap.hasLifetime {
                                planCard(lifetime, title: MacString.lifetimeCaps.text, highlight: false)
                            }
                        }
                        .frame(width: 380)

                        if let lifetime, !iap.hasLifetime {
                            VStack(spacing: 2) {
                                Text(MacString.lifetimePitch.text)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Talky.text)
                                if let yearly {
                                    // Prezzi da StoreKit, nella valuta di chi compra.
                                    Text(MacString.lifetimeVsYearly.format(lifetime.displayPrice, yearly.displayPrice))
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundStyle(Talky.dim)
                                }
                            }
                            .multilineTextAlignment(.center)
                            .frame(width: 380)
                        }

                        if let themesPack {
                            Button {
                                buy { try await iap.purchaseThemesPack() }
                            } label: {
                                Text(MacString.themesPackOneTime.format(themesPack.displayPrice))
                            }
                            .buttonStyle(ChipButtonStyle(accent: Talky.teal))
                            .disabled(purchasing)
                        }
                    }

                    if iap.hasLifetime {
                        Text(MacString.yoursForever.text)
                            .font(.vfd(10, weight: .bold))
                            .kerning(1.4)
                            .foregroundStyle(Talky.signal)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(Talky.alarm)
                            .frame(width: 360)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.bottom, 16)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: PaywallContentHeight.self, value: proxy.size.height)
                })
            }
            .frame(height: scrollHeight)
            .onPreferenceChange(PaywallContentHeight.self) { contentHeight = $0 }

            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Button(MacString.restoreCaps.text) {
                        buy { try await iap.restorePurchases(); return true }
                    }
                    .buttonStyle(ChipButtonStyle(accent: Talky.dim))
                    .disabled(purchasing)

                    Button(MacString.close.text) { dismiss() }
                        .buttonStyle(ChipButtonStyle(accent: Talky.dim))
                }

                // Guideline 3.1.2: un'app con abbonamenti auto-rinnovabili deve
                // esporre Terms of Use e Privacy Policy raggiungibili *dalla paywall*,
                // non solo nella descrizione su App Store — ed e' esattamente il link
                // mancante che ha fatto respingere la 1.1.1 lato metadati. Fuori
                // dallo scroll, cosi' si vedono sempre; 10pt per stare in poco.
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Link(MacString.terms.text,
                             destination: LegalPage.terms.url)
                        Text("·").foregroundStyle(Talky.dim.opacity(0.5))
                        Link(MacString.privacy.text,
                             destination: LegalPage.privacy.url)
                    }
                    Text(MacString.renewal.text)
                        .frame(width: 380)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Talky.dim.opacity(0.7))
                }
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Talky.dim)
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .frame(width: 470)
        .background(Talky.coal)
        .overlay(alignment: .top) {
            if purchasing {
                ProgressView()
                    .padding(8)
            }
        }
    }

    /// Chi c'è dietro Talky. Sta fra le feature e i prezzi perché è il *perché*
    /// che dà senso al *quanto*: l'app è scritta da una persona sola e il codice
    /// è pubblico, quindi Pro è un contributo, non un lucchetto. È più corto
    /// del testo iOS perché la sheet deve restare corta: un paragrafo di sei
    /// righe a 11pt lo farebbe sembrare una EULA invece di una console.
    private var supporterNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Talky.amber)
                Text(MacString.devNoteTitle.text)
                    .font(.vfd(9, weight: .bold))
                    .kerning(1.6)
                    .foregroundStyle(Talky.dim)
            }

            Text(MacString.devNote.text)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Talky.text.opacity(0.8))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Link(MacString.seeCode.text,
                 destination: URL(string: "https://github.com/andreapianidev/WalkieTalkie")!)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Talky.dim)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Talky.panelRaised.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Talky.stroke, lineWidth: 1)
        )
    }

    private func feature(_ perk: ProPerk, detailed: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: perk.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Talky.amber)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(perk.title(stations: RadioManager.shared.radioStations.count))
                    .font(.system(size: 12, weight: detailed ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(Talky.text)
                if detailed {
                    Text(perk.detail)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Talky.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    if let location = perk.location {
                        Text(location)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Talky.amber.opacity(0.85))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func planCard(_ product: Product, title: String, highlight: Bool) -> some View {
        Button {
            buy { try await iap.purchase(product) }
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.vfd(10, weight: .bold))
                    .kerning(1.6)
                    .foregroundStyle(highlight ? Talky.coal : Talky.dim)
                Text(product.displayPrice)
                    .font(.vfd(20, weight: .heavy))
                    .foregroundStyle(highlight ? Talky.coal : Talky.amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(highlight ? Talky.amber : Talky.panelRaised.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(highlight ? Talky.amberDeep : Talky.stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(purchasing)
    }

    private func buy(_ action: @escaping () async throws -> Bool) {
        purchasing = true
        errorMessage = nil
        Task {
            do {
                _ = try await action()
            } catch {
                errorMessage = error.localizedDescription
            }
            purchasing = false
        }
    }
}

private struct PaywallContentHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
