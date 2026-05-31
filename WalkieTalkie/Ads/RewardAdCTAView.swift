//  RewardAdCTAView.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

import SwiftUI
import FirebaseAnalytics

/// CTA riusabile "Guarda un video → 1 ora senza pubblicità".
///
/// È il bottone che porta finalmente impression sul rewarded (`walkiepremio`),
/// oggi mai servito perché l'unico entry point era sepolto in fondo a Settings.
/// Lo si piazza dove l'utente Free incontra attrito (paywall, banner Explore, …).
///
/// - Si auto-nasconde se l'utente è Pro o se ha già un reward attivo (sarebbe
///   un'offerta priva di senso).
/// - Resta disabilitato con uno spinner finché l'ad non è caricato.
/// - Emette un funnel misurabile: `rewarded_cta_shown` (una volta, alla comparsa)
///   → `rewarded_cta_tapped` → `rewarded_reward_earned` (gli ultimi due da
///   `AdManager.presentRewardedRemoveAds`), tutti con lo stesso `source`.
struct RewardAdCTAView: View {

    /// Superficie che mostra il CTA. Diventa il parametro `source` su Firebase,
    /// così possiamo confrontare quale placement converte di più.
    let source: String

    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var rewarded = AdManager.shared.rewarded
    @StateObject private var settingsManager = SettingsManager.shared

    @State private var didLogImpression = false

    private var isProUser: Bool {
        UserDefaults.standard.bool(forKey: "fastboot_isProUser")
    }

    /// Visibile solo a chi può davvero approfittarne: utente Free senza un reward
    /// già in corso.
    private var isVisible: Bool {
        !isProUser && !adManager.adsRemoved
    }

    private var isAppDark: Bool { settingsManager.isDarkModeEnabled }
    private var brand: Color { Color(red: 1.0, green: 0.8, blue: 0.0) }
    private var ink: Color {
        isAppDark
            ? Color(red: 0.957, green: 0.937, blue: 0.894)
            : Color(red: 0.086, green: 0.082, blue: 0.075)
    }
    private var bgSubtle: Color {
        isAppDark
            ? Color(red: 0.122, green: 0.106, blue: 0.086)
            : Color(red: 0.945, green: 0.925, blue: 0.871)
    }

    var body: some View {
        if isVisible {
            Button {
                adManager.presentRewardedRemoveAds(source: source)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(brand)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("watch_ad_remove_ads".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ink)
                            .lineLimit(1)
                        Text("watch_ad_remove_ads_subtitle".localized)
                            .font(.system(size: 12))
                            .foregroundColor(ink.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if rewarded.isAdReady {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ink.opacity(0.4))
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(bgSubtle)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ink.opacity(0.10), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!rewarded.isAdReady)
            .opacity(rewarded.isAdReady ? 1.0 : 0.6)
            .onAppear {
                guard !didLogImpression else { return }
                didLogImpression = true
                Analytics.logEvent("rewarded_cta_shown", parameters: ["source": source])
            }
        }
    }
}
