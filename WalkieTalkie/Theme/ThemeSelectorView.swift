//  ThemeSelectorView.swift
//  WalkieTalkie

import SwiftUI

struct ThemeSelectorView: View {

    @ObservedObject private var themeManager = ThemeManager.shared
    private let onLockedTap: ((Theme) -> Void)?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    init(onLockedTap: ((Theme) -> Void)? = nil) {
        self.onLockedTap = onLockedTap
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("theme.subtitle".localized)
                        .font(AppFont.caption())
                        .foregroundColor(themeManager.currentTheme.textSecondary)
                        .padding(.horizontal)
                        .padding(.top, AppSpacing.xs)

                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(Theme.allCases, id: \.self) { theme in
                            themeCard(for: theme)
                                .onTapGesture { handleTap(on: theme) }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .background(themeManager.currentTheme.backgroundPrimary)
            .navigationTitle("theme.title".localized)
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func themeCard(for theme: Theme) -> some View {
        let isSelected = themeManager.currentTheme == theme
        let showProBadge = theme.isProLocked && !themeManager.canAccess(theme: theme)
        let isAnimated = theme.backgroundStyle == .animated

        VStack(spacing: AppSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                // Card con sfondo reale del tema
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(theme.backgroundPrimary)
                    .frame(height: 100)
                    .overlay(
                        Group {
                            if theme.backgroundStyle == .gradient,
                               let top = theme.gradientTop,
                               let bottom = theme.gradientBottom {
                                LinearGradient(
                                    gradient: Gradient(colors: [top, bottom]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                            } else if isAnimated {
                                AnimatedThemePreview(theme: theme)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                            }
                        }
                    )
                    // Superficie interna (simula una mini-card dentro)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                            .fill(theme.surfaceColor)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: theme.iconName)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(theme.accentColor)
                            )
                    )
                    // Bordo selezione
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                            .stroke(theme.accentColor, lineWidth: isSelected ? 3 : 0)
                    )
                    // Glow accento
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                            .stroke(theme.accentGlow ?? .clear, lineWidth: isSelected ? 6 : 0)
                            .blur(radius: 8)
                    )
                    // Checkmark
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(theme.accentColor)
                                .background(Circle().fill(theme.surfaceColor))
                                .padding(AppSpacing.xs)
                        }
                    }

                // Badge PRO
                if showProBadge {
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.yellow))
                        .offset(x: AppSpacing.xs, y: -AppSpacing.xs)
                }
            }

            // Nome tema
            Text(theme.displayName)
                .font(AppFont.caption().weight(isSelected ? .semibold : .regular))
                .foregroundColor(themeManager.currentTheme.textPrimary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Tap Handling

    private func handleTap(on theme: Theme) {
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
        ThemeSelectorView(onLockedTap: { _ in })
    }
}
#endif
