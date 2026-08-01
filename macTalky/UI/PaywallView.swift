//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - PaywallView.swift
//  macTalky
//
//  Paywall Talky Pro. Stessi prodotti App Store dell'app iOS (universal
//  purchase: stesso bundle ID → un acquisto vale su iPhone, iPad e Mac):
//  - ProWeeklyWT / ProAnnualWT (subscription "Talky Pro")
//  - app.immaginet.talky.themes.allpack (non-consumable temi)

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var iap: IAPManager
    @Environment(\.dismiss) private var dismiss

    @State private var purchasing = false
    @State private var errorMessage: String?

    private var weekly: Product? { iap.products.first { $0.id == ProductID.weekly.rawValue } }
    private var yearly: Product? { iap.products.first { $0.id == ProductID.yearly.rawValue } }
    private var themesPack: Product? { iap.products.first { $0.id == ProductID.themesPackID } }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Text("TALKY PRO")
                    .font(.vfd(26, weight: .heavy))
                    .kerning(4)
                    .foregroundStyle(Talky.amber)
                    .shadow(color: Talky.amberDeep.opacity(0.7), radius: 10)
                Text("One purchase. iPhone, iPad and Mac.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Talky.dim)
            }
            .padding(.top, 26)

            // Features
            ConsolePanel(padding: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    feature("antenna.radiowaves.left.and.right", "All \(RadioManager.shared.radioStations.count) worldwide radio stations")
                    feature("lock.fill", "Private password-protected channels")
                    feature("paintpalette.fill", "All themes on the iOS app")
                    feature("heart.fill", "Supports independent development")
                }
            }
            .frame(width: 380)

            if iap.isProUser {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Talky.signal)
                    Text("You are a Pro user. Thank you!")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Talky.text)
                }
                .padding(.vertical, 8)
            } else if iap.products.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading products from the App Store…")
                        .font(.system(size: 11))
                        .foregroundStyle(Talky.dim)
                    Text("If nothing loads, make sure the Mac platform is enabled for Talky on App Store Connect.")
                        .font(.system(size: 10))
                        .foregroundStyle(Talky.dim.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(width: 340)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 12) {
                    if let weekly {
                        planCard(weekly, title: "WEEKLY", highlight: false)
                    }
                    if let yearly {
                        planCard(yearly, title: "YEARLY", highlight: true)
                    }
                }
                .frame(width: 380)

                if let themesPack {
                    Button {
                        buy { try await iap.purchaseThemesPack() }
                    } label: {
                        Text("THEMES PACK · \(themesPack.displayPrice) ONE-TIME")
                    }
                    .buttonStyle(ChipButtonStyle(accent: Talky.teal))
                    .disabled(purchasing)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Talky.alarm)
                    .frame(width: 360)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 14) {
                Button("RESTORE PURCHASES") {
                    buy { try await iap.restorePurchases(); return true }
                }
                .buttonStyle(ChipButtonStyle(accent: Talky.dim))
                .disabled(purchasing)

                Button("CLOSE") { dismiss() }
                    .buttonStyle(ChipButtonStyle(accent: Talky.dim))
            }
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

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Talky.amber)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Talky.text)
            Spacer()
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
                if highlight {
                    Text("BEST VALUE")
                        .font(.vfd(8, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(Talky.coal.opacity(0.7))
                }
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
