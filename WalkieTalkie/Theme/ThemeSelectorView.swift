//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemeSelectorView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// View per la selezione del tema dell'app.
/// Mostra una griglia di card; le Pro-locked espongono un badge "PRO".
struct ThemeSelectorView: View {

    // MARK: - Dependencies

    @ObservedObject private var themeManager = ThemeManager.shared

    /// Closure invocata quando l'utente tocca un tema Pro-locked senza essere Pro
    /// né possessore del themes pack. Riceve il tema che ha innescato il tap
    /// così che l'orchestrator possa mostrarlo come preview nella sheet del pack.
    private let onLockedTap: ((Theme) -> Void)?

    // MARK: - Layout

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    // MARK: - Init

    init(onLockedTap: ((Theme) -> Void)? = nil) {
        self.onLockedTap = onLockedTap
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Sottotitolo descrittivo (hardcoded IT come da specifica)
                    Text("theme.subtitle".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Theme.allCases, id: \.self) { theme in
                            themeCard(for: theme)
                                .onTapGesture {
                                    handleTap(on: theme)
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("theme.title".localized)
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func themeCard(for theme: Theme) -> some View {
        let isSelected = themeManager.currentTheme == theme
        let showProBadge = theme.isProLocked && !themeManager.canAccess(theme: theme)

        let isAnimatedTheme = (theme == .blackHole || theme == .galaxy)

        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                // Riquadro colorato 100x100 con icona SF Symbol centrata.
                // Per i temi animati (blackHole/galaxy) sovrapponiamo una mini-preview
                // del particle effect dietro l'icona, così l'utente vede cosa compra.
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.accentColor)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Group {
                            if isAnimatedTheme {
                                AnimatedThemePreview(theme: theme)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                    )
                    .overlay(
                        Image(systemName: theme.iconName)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: isAnimatedTheme ? .black.opacity(0.5) : .clear, radius: 4)
                    )
                    .overlay(
                        // Bordo giallo + checkmark se selezionato
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.yellow, lineWidth: isSelected ? 3 : 0)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.yellow)
                                .background(Circle().fill(Color.white))
                                .padding(6)
                        }
                    }

                // Badge "PRO" in alto a destra per i temi bloccati
                if showProBadge {
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.yellow)
                        )
                        .offset(x: 6, y: -6)
                }
            }

            Text(theme.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Tap Handling

    private func handleTap(on theme: Theme) {
        // Se setTheme ritorna false il tema è Pro-locked: inoltra alla sheet del
        // themes pack, passando il tema toccato come preview.
        let applied = themeManager.setTheme(theme)
        if !applied {
            onLockedTap?(theme)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ThemeSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        ThemeSelectorView(onLockedTap: { _ in
            // Anteprima: stub paywall
        })
    }
}
#endif
