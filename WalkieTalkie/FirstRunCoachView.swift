//
//  FirstRunCoachView.swift
//  WalkieTalkie
//
//  Post-onboarding coachmark that guides the user from a cold home screen
//  to the first successful walkie-talkie transmission.
//

import SwiftUI

struct FirstRunCoachView: View {
    let connectedPeersCount: Int
    let isTransmitting: Bool
    let onGoToConnections: () -> Void
    let onDismiss: () -> Void

    private var stage: Stage {
        if isTransmitting { return .done }
        return connectedPeersCount == 0 ? .noPeers : .pressPTT
    }

    var body: some View {
        VStack {
            if stage == .noPeers {
                banner(
                    title: OnboardingStrings.coachNoPeersTitle,
                    body: OnboardingStrings.coachNoPeersBody,
                    icon: "1.circle.fill",
                    actionLabel: "connections".localized,
                    actionIcon: "arrow.down.right.circle.fill",
                    onAction: onGoToConnections
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                Spacer()
            } else if stage == .pressPTT {
                Spacer()
                banner(
                    title: OnboardingStrings.coachPressPTTTitle,
                    body: OnboardingStrings.coachPressPTTBody,
                    icon: "hand.point.down.fill",
                    actionLabel: nil,
                    actionIcon: nil,
                    onAction: nil
                )
                .padding(.bottom, 220)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.3), value: stage)
        .onChange(of: isTransmitting) { transmitting in
            if transmitting { onDismiss() }
        }
    }

    @ViewBuilder
    private func banner(
        title: String,
        body: String,
        icon: String,
        actionLabel: String?,
        actionIcon: String?,
        onAction: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(body)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel(OnboardingStrings.coachDismiss)
            }

            if let actionLabel, let onAction {
                Button(action: onAction) {
                    HStack(spacing: 6) {
                        Text(actionLabel)
                            .font(.footnote.weight(.semibold))
                        if let actionIcon {
                            Image(systemName: actionIcon)
                                .font(.footnote)
                        }
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow)
                    .cornerRadius(14)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }

    private enum Stage { case noPeers, pressPTT, done }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        FirstRunCoachView(
            connectedPeersCount: 0,
            isTransmitting: false,
            onGoToConnections: {},
            onDismiss: {}
        )
    }
}
