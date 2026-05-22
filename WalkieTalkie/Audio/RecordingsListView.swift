//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - RecordingsListView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Vista lista delle registrazioni audio salvate.
/// Pro-only: se l'utente non è Pro mostra un overlay paywall.
struct RecordingsListView: View {

    // MARK: - Dependencies

    @ObservedObject private var manager = RecordingsManager.shared

    /// Callback per presentare il paywall (chiamato anche dal tap su "Sblocca").
    private let onUnlockTap: () -> Void

    @State private var showDeleteAllConfirm = false

    // MARK: - Init

    init(onUnlockTap: @escaping () -> Void) {
        self.onUnlockTap = onUnlockTap
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            Group {
                if !manager.isProUser {
                    paywallOverlay
                } else if manager.recordings.isEmpty {
                    emptyState
                } else {
                    contentList
                }
            }
            .navigationTitle("recordings.title".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if manager.isProUser && !manager.recordings.isEmpty {
                            Button {
                                showDeleteAllConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.yellow)
                            }
                        } else {
                            EmptyView()
                        }
                    }
                }
            }
            .alert("recordings.delete_all_title".localized, isPresented: $showDeleteAllConfirm) {
                Button("recordings.cancel".localized, role: .cancel) {}
                Button("recordings.delete_all".localized, role: .destructive) {
                    manager.deleteAll()
                }
            } message: {
                Text("recordings.delete_all_message".localized)
            }
        }
    }

    // MARK: - Paywall overlay

    private var paywallOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(.yellow)
            Text("recordings.pro_feature".localized)
                .font(.title2.weight(.bold))
            Text("recordings.paywall_message".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onUnlockTap) {
                Text("recordings.unlock_pro".localized)
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.yellow))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.secondary)
            Text("recordings.empty_title".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            Text("recordings.empty_message".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var contentList: some View {
        List {
            Section {
                ForEach(manager.recordings) { recording in
                    row(for: recording)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            manager.playRecording(recording)
                        }
                }
                .onDelete(perform: deleteAt)
            }

            Section {
                Text("recordings.privacy_notice".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for recording: AudioRecording) -> some View {
        HStack(spacing: 14) {
            Image(systemName: recording.type == .sent ? "arrow.up.forward.app" : "arrow.down.forward.app")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.yellow)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.peerName ?? "recordings.own_transmission".localized)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                Text(subtitle(for: recording))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
        }
        .padding(.vertical, 4)
    }

    private func subtitle(for recording: AudioRecording) -> String {
        "\(relativeTime(recording.timestamp)) - \(formatDuration(recording.durationSeconds))"
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let secs = total % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return "\(secs)s"
        }
    }

    private func deleteAt(_ offsets: IndexSet) {
        let items = offsets.map { manager.recordings[$0] }
        for item in items {
            manager.delete(item)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingsListView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingsListView(onUnlockTap: {})
    }
}
#endif
