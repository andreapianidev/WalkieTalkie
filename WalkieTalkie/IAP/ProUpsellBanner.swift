//creato da Andrea Piani - Immaginet Srl - 23/05/26 - https://www.andreapiani.com - ProUpsellBanner.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 23/05/26.
//

import SwiftUI
import FirebaseAnalytics

/// Banner upsell compatto e non invasivo per Talky Pro.
///
/// Design: pannello "field radio" — superficie inchiostro/crema (non gradient),
/// hairline 1pt, icona brand quadrata stile pulsante hardware. Mai full-screen,
/// mai con auto-dismiss-then-popup, mai con pulse loop. È un trigger discreto.
///
/// Usage:
/// ```
/// ProUpsellBanner(placement: .settings, onTap: { showPaywall = true })
/// ```
///
/// Si auto-nasconde quando l'utente è già Pro o ha dismissato il banner di
/// recente per questo `placement` (cooldown 7 giorni).
struct ProUpsellBanner: View {

    // MARK: - Placement

    /// Dove vive il banner. Influisce sulle chiavi UserDefaults del cooldown
    /// e sul trigger Analytics — così possiamo misurare quale placement
    /// converte meglio senza accavallare le metriche.
    enum Placement: String {
        case settings
        case stationBrowser = "station_browser"

        var dismissKey: String { "pro_banner_dismissed_until_\(rawValue)" }
        var analyticsTrigger: String { "banner_\(rawValue)" }
    }

    // MARK: - Input

    let placement: Placement
    let onTap: () -> Void

    // MARK: - Env

    @StateObject private var iap = IAPManager.shared
    @StateObject private var settingsManager = SettingsManager.shared

    // MARK: - State

    @State private var dismissedUntil: Date? = nil
    @State private var isPressed: Bool = false
    @State private var didLogImpression: Bool = false

    // MARK: - Cooldown

    /// Periodo durante il quale il banner resta nascosto dopo un dismiss esplicito.
    /// 7 giorni è un compromesso conservativo: abbastanza lungo da non risultare
    /// fastidioso, abbastanza corto da recuperare gli utenti tornati di propria
    /// volontà su una feature Pro-locked.
    private static let dismissCooldown: TimeInterval = 7 * 24 * 60 * 60

    private var isWithinCooldown: Bool {
        guard let until = dismissedUntil else { return false }
        return until > Date()
    }

    /// Visibile solo se: non sei Pro && non sei in cooldown.
    private var isVisible: Bool {
        !iap.isProUser && !isWithinCooldown
    }

    // MARK: - Palette adattiva

    /// True solo quando l'utente ha attivato manualmente la modalità scura
    /// nelle impostazioni dell'app (NON quando è scura solo a livello iOS).
    private var isAppDark: Bool { settingsManager.isDarkModeEnabled }

    private var brand: Color { Color(red: 1.0, green: 0.8, blue: 0.0) }
    private var brandDeep: Color { Color(red: 0.91, green: 0.71, blue: 0.0) }

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

    private var hairline: Color { ink.opacity(isAppDark ? 0.06 : 0.10) }

    // MARK: - Body

    var body: some View {
        Group {
            if isVisible {
                bannerContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                EmptyView()
            }
        }
        .onAppear { hydrateState() }
    }

    private var bannerContent: some View {
        HStack(spacing: 12) {
            iconTile

            VStack(alignment: .leading, spacing: 2) {
                Text("upsell.title".localized)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(ink)
                    .lineLimit(1)

                Text("upsell.subtitle".localized)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(inkSecondary)

            dismissButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(bgSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hairline, lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        ._onButtonGesture(pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onAppear {
            // Una sola impression per ciclo di vita della view: evita doppi
            // log se il banner si re-renderizza per cambio di stato esterno.
            if !didLogImpression {
                Analytics.logEvent("upsell_banner_shown", parameters: [
                    "placement": placement.rawValue
                ])
                didLogImpression = true
            }
        }
    }

    // MARK: - Sub-views

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(brand)
                .frame(width: 40, height: 40)
                // Glow solo in dark: in light l'effetto stride col panel cream
                .shadow(color: isAppDark ? brand.opacity(0.35) : .clear,
                        radius: 12, x: 0, y: 4)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
        }
    }

    private var dismissButton: some View {
        Button(action: handleDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(inkSecondary.opacity(0.7))
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(ink.opacity(isAppDark ? 0.08 : 0.05))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("upsell.dismiss".localized)
    }

    // MARK: - Actions

    private func handleTap() {
        HapticManager.shared.lightTap()
        Analytics.logEvent("upsell_banner_tapped", parameters: [
            "placement": placement.rawValue
        ])
        onTap()
    }

    private func handleDismiss() {
        let until = Date().addingTimeInterval(Self.dismissCooldown)
        UserDefaults.standard.set(until, forKey: placement.dismissKey)
        Analytics.logEvent("upsell_banner_dismissed", parameters: [
            "placement": placement.rawValue,
            "cooldown_days": 7
        ])
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            dismissedUntil = until
        }
    }

    private func hydrateState() {
        if let until = UserDefaults.standard.object(forKey: placement.dismissKey) as? Date {
            self.dismissedUntil = until
        }
    }
}

// MARK: - Press helper

/// SwiftUI 5 / iOS 17+ espone `_onButtonGesture` per intercettare press/release
/// senza dover trasformare l'intero banner in `Button`. Su iOS più vecchi cade
/// in un no-op silenzioso — l'animazione di press è un dettaglio, non bloccante.
private extension View {
    @ViewBuilder
    func _onButtonGesture(pressing: @escaping (Bool) -> Void,
                          perform: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onLongPressGesture(minimumDuration: 0.01,
                                    maximumDistance: 50,
                                    perform: perform,
                                    onPressingChanged: pressing)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview("Banner light") {
    ProUpsellBanner(placement: .settings, onTap: {})
        .padding()
}

#Preview("Banner dark") {
    ProUpsellBanner(placement: .stationBrowser, onTap: {})
        .padding()
        .preferredColorScheme(.dark)
}
