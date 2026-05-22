//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - EqualizerView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Sheet che permette di scegliere un preset per l'equalizzatore.
/// Solo "Piatto" è disponibile gratuitamente; gli altri sono Pro.
struct EqualizerView: View {

    // MARK: - Dependencies

    @ObservedObject private var manager = EqualizerManager.shared

    /// Closure invocata quando l'utente tocca un preset Pro-locked senza essere Pro.
    private let onLockedTap: () -> Void

    // MARK: - Init

    init(onLockedTap: @escaping () -> Void) {
        self.onLockedTap = onLockedTap
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header con preset corrente + barre
                    currentPresetCard
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Sottotitolo descrittivo
                    Text("equalizer.subtitle".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    // Lista verticale dei preset
                    VStack(spacing: 12) {
                        ForEach(EqualizerPreset.allCases, id: \.self) { preset in
                            presetRow(for: preset)
                                .onTapGesture {
                                    handleTap(on: preset)
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("equalizer.title".localized)
        }
    }

    // MARK: - Header corrente

    private var currentPresetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: manager.currentPreset.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.yellow)
                    .frame(width: 44, height: 44)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("equalizer.active_preset".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(manager.currentPreset.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
            }

            gainBars(for: manager.currentPreset)
                .frame(height: 60)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// Mini-visualizzazione delle 5 bande come barre verticali centrate sullo zero.
    private func gainBars(for preset: EqualizerPreset) -> some View {
        let gains = preset.gains
        let maxAbs = max(1, gains.map { abs($0) }.max() ?? 1)
        return HStack(alignment: .center, spacing: 8) {
            ForEach(0..<gains.count, id: \.self) { idx in
                let normalized = CGFloat(gains[idx]) / CGFloat(maxAbs)
                GeometryReader { geo in
                    let half = geo.size.height / 2
                    let barHeight = max(2, abs(normalized) * half)
                    ZStack {
                        // Linea centrale
                        Rectangle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(height: 1)
                        // Barra
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.yellow)
                            .frame(width: 12, height: barHeight)
                            .offset(y: normalized >= 0 ? -barHeight / 2 : barHeight / 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func presetRow(for preset: EqualizerPreset) -> some View {
        let isSelected = manager.currentPreset == preset
        let showProBadge = preset != .flat && !manager.isProUser

        HStack(spacing: 14) {
            Image(systemName: preset.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isSelected ? .white : .yellow)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.yellow : Color.yellow.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(preset.displayName)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                    if showProBadge {
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.yellow))
                    }
                }
                // Mini preview barre per ciascuna riga
                miniGainPreview(for: preset)
                    .frame(height: 14)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.yellow)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.yellow, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(Rectangle())
    }

    private func miniGainPreview(for preset: EqualizerPreset) -> some View {
        let gains = preset.gains
        let maxAbs = max(1, gains.map { abs($0) }.max() ?? 1)
        return HStack(alignment: .center, spacing: 3) {
            ForEach(0..<gains.count, id: \.self) { idx in
                let normalized = CGFloat(gains[idx]) / CGFloat(maxAbs)
                GeometryReader { geo in
                    let half = geo.size.height / 2
                    let barHeight = max(2, abs(normalized) * half)
                    ZStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(height: 1)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.yellow.opacity(0.85))
                            .frame(width: 4, height: barHeight)
                            .offset(y: normalized >= 0 ? -barHeight / 2 : barHeight / 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 6)
            }
        }
    }

    // MARK: - Tap

    private func handleTap(on preset: EqualizerPreset) {
        let applied = manager.setPreset(preset)
        if !applied {
            onLockedTap()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct EqualizerView_Previews: PreviewProvider {
    static var previews: some View {
        EqualizerView(onLockedTap: {})
    }
}
#endif
