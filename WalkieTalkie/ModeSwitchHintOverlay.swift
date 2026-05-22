//
//  ModeSwitchHintOverlay.swift
//  WalkieTalkie
//
//  Educational one-time overlay that teaches the user about the WT <-> FM
//  mode toggle located at the top-left of the screen.
//

import SwiftUI

struct ModeSwitchHintOverlay: View {
    @Binding var isShown: Bool

    @State private var arrowPulse: Bool = false
    @State private var cardOpacity: Double = 0
    @State private var arrowOpacity: Double = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Dim background — dismissable by tapping anywhere
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }

            // Animated arrow pointing toward the top-left toggle
            Image(systemName: "arrow.up.left")
                .font(.system(size: 38, weight: .heavy))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)
                .scaleEffect(arrowPulse ? 1.18 : 0.92)
                .opacity(arrowOpacity)
                .padding(.leading, 26)
                .padding(.top, 70)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // Tooltip card — vertically centered
            VStack {
                Spacer()

                VStack(spacing: 14) {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color("PrimaryTextColor"))
                        .symbolRenderingMode(.hierarchical)

                    Text("mode_switch_hint".localized)
                        .font(.headline)
                        .foregroundColor(Color("PrimaryTextColor"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        dismiss()
                    } label: {
                        Text("got_it".localized)
                            .font(.body.weight(.semibold))
                            .foregroundColor(Color("BackgroundColor"))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(
                                Capsule().fill(Color("PrimaryTextColor"))
                            )
                    }
                    .accessibilityLabel("got_it".localized)
                }
                .padding(20)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color("SurfaceColor"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color("PrimaryTextColor").opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
                .opacity(cardOpacity)

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                cardOpacity = 1
                arrowOpacity = 1
            }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                arrowPulse = true
            }
        }
    }

    private func dismiss() {
        UserDefaults.standard.set(true, forKey: "talky_seen_mode_switch_hint")
        withAnimation(.easeIn(duration: 0.2)) {
            isShown = false
        }
    }
}

#if DEBUG
struct ModeSwitchHintOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            ModeSwitchHintOverlay(isShown: .constant(true))
        }
    }
}
#endif
