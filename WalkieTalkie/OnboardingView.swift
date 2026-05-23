//
//  OnboardingView.swift
//  WalkieTalkie
//
//  Created by Assistant on 12/07/25.
//

import SwiftUI
import AVFoundation
import UserNotifications
import FirebaseAnalytics

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showingPermissions = false
    @State private var lastTrackedPage = -1
    @Binding var isOnboardingComplete: Bool
    @ObservedObject var notificationManager: NotificationManager

    private let totalPages = 6

    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentPage ? Color("PrimaryTextColor") : Color("PrimaryTextColor").opacity(0.25))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 20)

                Spacer(minLength: 12)

                TabView(selection: $currentPage) {
                    OnboardingHookPage().tag(0)
                    OnboardingNoInternetPage().tag(1)
                    OnboardingPTTPage().tag(2)
                    OnboardingFrequencyPage().tag(3)
                    OnboardingRadioModePage().tag(4)
                    OnboardingStepsPage().tag(5)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                Spacer(minLength: 12)

                HStack {
                    if currentPage > 0 {
                        Button {
                            withAnimation { currentPage -= 1 }
                        } label: {
                            Text(OnboardingStrings.backButton)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                        }
                    } else {
                        Button {
                            Analytics.logEvent("onboarding_skip", parameters: ["page_index": currentPage])
                            showingPermissions = true
                        } label: {
                            Text(OnboardingStrings.skipButton)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                        }
                    }

                    Spacer()

                    Button {
                        if currentPage < totalPages - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            showingPermissions = true
                        }
                    } label: {
                        Text(currentPage < totalPages - 1 ? OnboardingStrings.continueButton : OnboardingStrings.getStartedButton)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color("PrimaryTextColor"))
                            .cornerRadius(28)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear { trackPageView(0) }
        .onChange(of: currentPage) { newValue in
            trackPageView(newValue)
        }
        .sheet(isPresented: $showingPermissions) {
            PermissionsView(isOnboardingComplete: $isOnboardingComplete, notificationManager: notificationManager)
        }
    }

    private func trackPageView(_ index: Int) {
        guard index != lastTrackedPage else { return }
        lastTrackedPage = index
        Analytics.logEvent("onboarding_page_view", parameters: ["page_index": index])
    }
}

// MARK: - Page 1: Hook

private struct OnboardingHookPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 84, weight: .light))
                .foregroundColor(Color("PrimaryTextColor"))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 14) {
                Text(OnboardingStrings.p1Title)
                    .font(.largeTitle.bold())
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)

                Text(OnboardingStrings.p1Subtitle)
                    .font(.title3)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding()
    }
}

// MARK: - Page 2: No internet

private struct OnboardingNoInternetPage: View {
    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                HStack(spacing: 28) {
                    Image(systemName: "iphone")
                        .font(.system(size: 56, weight: .light))
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                    Image(systemName: "iphone")
                        .font(.system(size: 56, weight: .light))
                }
                .foregroundColor(Color("PrimaryTextColor"))
            }

            VStack(spacing: 14) {
                Text(OnboardingStrings.p2Title)
                    .font(.title.bold())
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)

                Text(OnboardingStrings.p2Body)
                    .font(.body)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.footnote)
                    Text(OnboardingStrings.p2RangeCaveat)
                        .font(.footnote)
                }
                .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                .padding(.top, 6)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "ipad.and.iphone")
                        .font(.footnote)
                    Text(OnboardingStrings.p2MultiPlatform)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }
        }
        .padding()
    }
}

// MARK: - Page 3: Push to Talk

private struct OnboardingPTTPage: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(Color("PrimaryTextColor").opacity(0.2), lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                    .opacity(isPulsing ? 0 : 0.8)

                Circle()
                    .fill(Color("PrimaryTextColor"))
                    .frame(width: 110, height: 110)

                Image(systemName: "mic.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color("BackgroundColor"))
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }

            VStack(spacing: 14) {
                Text(OnboardingStrings.p3Title)
                    .font(.title.bold())
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)

                Text(OnboardingStrings.p3Body)
                    .font(.body)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(OnboardingStrings.p3Rule)
                    .font(.callout.weight(.medium))
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    .padding(.top, 6)
            }
        }
        .padding()
    }
}

// MARK: - Page 4: Frequency

private struct OnboardingFrequencyPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "dial.medium")
                .font(.system(size: 72, weight: .light))
                .foregroundColor(Color("PrimaryTextColor"))

            VStack(spacing: 14) {
                Text(OnboardingStrings.p4Title)
                    .font(.title.bold())
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)

                Text(OnboardingStrings.p4Analogy)
                    .font(.body)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(spacing: 10) {
                    Image(systemName: "hand.tap")
                        .font(.footnote)
                    Text(OnboardingStrings.p4ChangeFreqHint)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(Color("PrimaryTextColor").opacity(0.65))
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Text(OnboardingStrings.p4PrivateChannelsTeaser)
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
            }
        }
        .padding()
    }
}

// MARK: - Page 5: Radio Mode (WT <-> FM toggle)

private struct OnboardingRadioModePage: View {
    @State private var showFM = false

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "antenna.radiowaves.left.and.right.circle")
                .font(.system(size: 84, weight: .light))
                .foregroundColor(Color("PrimaryTextColor"))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 14) {
                Text(OnboardingStrings.radioModeTitle)
                    .font(.title.bold())
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)

                Text(OnboardingStrings.radioModeSubtitle)
                    .font(.title3)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Mock toggle illustration (larger than the real one for emphasis)
                HStack(spacing: 8) {
                    Image(systemName: showFM ? "radio" : "antenna.radiowaves.left.and.right")
                        .foregroundColor(Color("PrimaryTextColor"))
                        .font(.title2)
                    Text(showFM ? "FM" : "WT")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color("PrimaryTextColor"))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("PrimaryTextColor").opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("PrimaryTextColor").opacity(0.25), lineWidth: 1)
                )
                .padding(.top, 8)

                Text(OnboardingStrings.radioModeBody)
                    .font(.footnote)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
            }
        }
        .padding()
        .onAppear {
            // Gentle illustrative toggle animation to communicate the switch action.
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                showFM = true
            }
        }
    }
}

// MARK: - Page 6: Steps

private struct OnboardingStepsPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "checklist")
                .font(.system(size: 72, weight: .light))
                .foregroundColor(Color("PrimaryTextColor"))

            Text(OnboardingStrings.p5Title)
                .font(.title.bold())
                .foregroundColor(Color("PrimaryTextColor"))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                StepRow(index: 1, text: OnboardingStrings.p5Step1)
                StepRow(index: 2, text: OnboardingStrings.p5Step2)
                StepRow(index: 3, text: OnboardingStrings.p5Step3)
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
}

private struct StepRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color("PrimaryTextColor")))

            Text(text)
                .font(.body)
                .foregroundColor(Color("PrimaryTextColor"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Permissions Sheet

struct PermissionsView: View {
    @Binding var isOnboardingComplete: Bool
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss

    @State private var microphonePermissionGranted = false
    @State private var notificationPermissionGranted = false
    @State private var isRequestingPermissions = false
    @State private var hasRequestedOnce = false

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 72, weight: .light))
                        .foregroundColor(Color("PrimaryTextColor"))
                        .padding(.top, 20)

                    VStack(spacing: 12) {
                        Text(OnboardingStrings.permissionsTitle)
                            .font(.title.bold())
                            .foregroundColor(Color("PrimaryTextColor"))
                            .multilineTextAlignment(.center)

                        Text(OnboardingStrings.permissionsDescription)
                            .font(.body)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    VStack(spacing: 12) {
                        PermissionRow(
                            icon: "mic.fill",
                            title: OnboardingStrings.microphonePermission,
                            subtitle: OnboardingStrings.microphonePermissionWhy,
                            isGranted: microphonePermissionGranted
                        )

                        PermissionRow(
                            icon: "bell.fill",
                            title: OnboardingStrings.notificationPermission,
                            subtitle: OnboardingStrings.notificationPermissionWhy,
                            isGranted: notificationPermissionGranted
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    VStack(spacing: 12) {
                        Button(action: requestPermissions) {
                            HStack {
                                if isRequestingPermissions {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(OnboardingStrings.allowPermissionsButton)
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color("PrimaryTextColor"))
                            .cornerRadius(25)
                        }
                        .disabled(isRequestingPermissions)

                        if hasRequestedOnce && (!microphonePermissionGranted || !notificationPermissionGranted) {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(OnboardingStrings.openSettingsLink)
                                    .font(.footnote)
                                    .underline()
                                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                                    .padding(.vertical, 6)
                            }
                        }

                        Button {
                            isOnboardingComplete = true
                            dismiss()
                        } label: {
                            Text(OnboardingStrings.skipButton)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.55))
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear { checkPermissions() }
    }

    private func checkPermissions() {
        microphonePermissionGranted = AVAudioSession.sharedInstance().recordPermission == .granted
        notificationPermissionGranted = notificationManager.hasPermission
    }

    private func requestPermissions() {
        isRequestingPermissions = true
        hasRequestedOnce = true

        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                microphonePermissionGranted = granted
                Analytics.logEvent(
                    granted ? "permission_mic_granted" : "permission_mic_denied",
                    parameters: nil
                )
            }
        }

        notificationManager.requestNotificationPermission()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRequestingPermissions = false
            checkPermissions()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isOnboardingComplete = true
                dismiss()
            }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color("PrimaryTextColor"))
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color("PrimaryTextColor"))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isGranted ? .green : Color("PrimaryTextColor").opacity(0.3))
                .padding(.top, 2)
        }
        .padding(14)
        .background(Color("SurfaceColor"))
        .cornerRadius(12)
    }
}

#Preview {
    OnboardingView(
        isOnboardingComplete: .constant(false),
        notificationManager: NotificationManager()
    )
}
