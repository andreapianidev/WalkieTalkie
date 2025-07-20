//
//  OnboardingView.swift
//  WalkieTalkie
//
//  Created by Assistant on 12/07/25.
//

import SwiftUI
import AVFoundation
import UserNotifications

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showingPermissions = false
    @Binding var isOnboardingComplete: Bool
    @ObservedObject var notificationManager: NotificationManager
    
    private let totalPages = 4
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            VStack {
                // Progress indicator
                HStack {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index <= currentPage ? Color("PrimaryTextColor") : Color("PrimaryTextColor").opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Content
                TabView(selection: $currentPage) {
                    WelcomePageView()
                        .tag(0)
                    
                    HowItWorksPageView()
                        .tag(1)
                    
                    ConnectivityPageView()
                        .tag(2)
                    
                    FrequencyPageView()
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            Text(OnboardingStrings.skipButton)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if currentPage < totalPages - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            showingPermissions = true
                        }
                    }) {
                        Text(currentPage < totalPages - 1 ? OnboardingStrings.continueButton : OnboardingStrings.getStartedButton)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color("PrimaryTextColor"))
                            .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingPermissions) {
            PermissionsView(isOnboardingComplete: $isOnboardingComplete, notificationManager: notificationManager)
        }
    }
}

struct WelcomePageView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "radio")
                .font(.system(size: 80))
                .foregroundColor(Color("PrimaryTextColor"))
            
            VStack(spacing: 15) {
                Text(OnboardingStrings.welcomeTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)
                
                Text(OnboardingStrings.welcomeSubtitle)
                    .font(.title3)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding()
    }
}

struct HowItWorksPageView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundColor(Color("PrimaryTextColor"))
            
            VStack(spacing: 15) {
                Text(OnboardingStrings.howItWorksTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)
                
                Text(OnboardingStrings.howItWorksDescription)
                    .font(.body)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding()
    }
}

struct ConnectivityPageView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "network")
                .font(.system(size: 80))
                .foregroundColor(Color("PrimaryTextColor"))
            
            VStack(spacing: 15) {
                Text(OnboardingStrings.connectivityTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)
                
                Text(OnboardingStrings.connectivityDescription)
                    .font(.body)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(OnboardingStrings.bluetoothFeature)
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.9))
                    
                    Text(OnboardingStrings.wifiFeature)
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.9))
                    
                    Text(OnboardingStrings.multipeerFeature)
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.9))
                    
                    Text(OnboardingStrings.rangeFeature)
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.9))
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 8) {
                    Text(OnboardingStrings.upToEightDevices)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("PrimaryTextColor"))
                    
                    Text(OnboardingStrings.mountainUse)
                        .font(.callout)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    
                    Text(OnboardingStrings.excursionUse)
                        .font(.callout)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                }
                .padding(.top, 10)
            }
        }
        .padding()
    }
}

struct FrequencyPageView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "waveform")
                .font(.system(size: 80))
                .foregroundColor(Color("PrimaryTextColor"))
            
            VStack(spacing: 15) {
                Text(OnboardingStrings.frequencyTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)
                
                Text(OnboardingStrings.frequencyDescription)
                    .font(.body)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Text(OnboardingStrings.homeFrequency)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("PrimaryTextColor"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color("SurfaceColor"))
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

struct PermissionsView: View {
    @Binding var isOnboardingComplete: Bool
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var microphonePermissionGranted = false
    @State private var notificationPermissionGranted = false
    @State private var isRequestingPermissions = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 80))
                        .foregroundColor(Color("PrimaryTextColor"))
                    
                    VStack(spacing: 15) {
                        Text(OnboardingStrings.permissionsTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Color("PrimaryTextColor"))
                            .multilineTextAlignment(.center)
                        
                        Text(OnboardingStrings.permissionsDescription)
                            .font(.body)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        PermissionRow(
                            icon: "mic.fill",
                            title: OnboardingStrings.microphonePermission,
                            isGranted: microphonePermissionGranted
                        )
                        
                        PermissionRow(
                            icon: "network",
                            title: OnboardingStrings.networkPermission,
                            isGranted: true // Always true for local network
                        )
                        
                        PermissionRow(
                            icon: "bluetooth",
                            title: OnboardingStrings.bluetoothPermission,
                            isGranted: true // Always true for Bluetooth
                        )
                        
                        PermissionRow(
                            icon: "bell.fill",
                            title: OnboardingStrings.notificationPermission,
                            isGranted: notificationPermissionGranted
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    VStack(spacing: 15) {
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
                        
                        Button(action: {
                            isOnboardingComplete = true
                            dismiss()
                        }) {
                            Text(OnboardingStrings.skipButton)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        // Check microphone permission
        microphonePermissionGranted = AVAudioSession.sharedInstance().recordPermission == .granted
        
        // Check notification permission
        notificationPermissionGranted = notificationManager.hasPermission
    }
    
    private func requestPermissions() {
        isRequestingPermissions = true
        
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                microphonePermissionGranted = granted
            }
        }
        
        // Request notification permission
        notificationManager.requestNotificationPermission()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRequestingPermissions = false
            checkPermissions()
            
            // Complete onboarding after requesting permissions
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isOnboardingComplete = true
                dismiss()
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let isGranted: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color("PrimaryTextColor"))
                .frame(width: 30)
            
            Text(title)
                .font(.body)
                .foregroundColor(Color("PrimaryTextColor"))
            
            Spacer()
            
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isGranted ? .green : Color("PrimaryTextColor").opacity(0.3))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 15)
        .background(Color("SurfaceColor"))
        .cornerRadius(10)
    }
}

#Preview {
    OnboardingView(
        isOnboardingComplete: .constant(false),
        notificationManager: NotificationManager()
    )
}