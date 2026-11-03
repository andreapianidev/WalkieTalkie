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

    private let totalPages = 8

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

                // Ogni pagina scorre invece di essere tagliata: su iPhone SE le
                // pagine piu' dense (rete, passi) non ci stanno in altezza, e la
                // UI troncata su schermi corti e' gia' costata recensioni da una
                // stella. Su schermi grandi lo ScrollView non si vede.
                TabView(selection: $currentPage) {
                    // La radio dal vivo prima del walkie: e' quello che Talky ha
                    // e le altre app no, e chi installa per la CB deve vederlo
                    // subito, non alla sesta pagina.
                    ScrollableOnboardingPage { OnboardingHookPage() }.tag(0)
                    ScrollableOnboardingPage { OnboardingLiveRadioPage() }.tag(1)
                    ScrollableOnboardingPage { OnboardingRadioModePage() }.tag(2)
                    ScrollableOnboardingPage { OnboardingWidgetsPage() }.tag(3)
                    ScrollableOnboardingPage { OnboardingNoInternetPage() }.tag(4)
                    ScrollableOnboardingPage { OnboardingPTTPage() }.tag(5)
                    ScrollableOnboardingPage { OnboardingFrequencyPage() }.tag(6)
                    ScrollableOnboardingPage { OnboardingStepsPage() }.tag(7)
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

// MARK: - Hook

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

// MARK: - Contenitore scrollabile

/// Centra la pagina quando ci sta e la lascia scorrere quando non ci sta.
/// `minHeight` legato all'altezza disponibile evita che le pagine corte si
/// incollino in alto, che e' l'effetto collaterale tipico di uno ScrollView.
private struct ScrollableOnboardingPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
            }
        }
    }
}

// MARK: - No internet

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

                // Mac e Android parlano solo via TALKY1 su Bonjour/TCP: serve la
                // stessa rete Wi-Fi, a differenza del link Apple-to-Apple.
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wifi")
                        .font(.footnote)
                    Text(OnboardingStrings.p2SameWiFi)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                .padding(.horizontal, 24)
                .padding(.top, 4)

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

// MARK: - Push to Talk

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

// MARK: - Frequency

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

// MARK: - Radio mode

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

                // Lo stesso selettore che c'e' in alto nell'app, con le sue
                // etichette: prima qui c'era "WT / FM", e l'FM nell'app non
                // esiste (le stazioni arrivano da internet).
                HStack(spacing: 4) {
                    modeChip("antenna.radiowaves.left.and.right", "walkie_talkie".localized, active: !showFM)
                    modeChip("radio", "radio_fm".localized, active: showFM)
                }
                .padding(4)
                .background(Capsule().fill(Color("PrimaryTextColor").opacity(0.12)))
                .padding(.top, 8)

                Text(OnboardingStrings.radioModeBody)
                    .font(.footnote)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                Text(OnboardingStrings.radioModeStreamingNote)
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
        .padding()
        .onAppear {
            // Il selettore passa avanti e indietro da solo, per far vedere il gesto.
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                showFM = true
            }
        }
    }
    private func modeChip(_ symbol: String, _ title: String, active: Bool) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(Color("PrimaryTextColor").opacity(active ? 1 : 0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(active ? Color("BackgroundColor") : Color.clear))
    }
}

// MARK: - Live radio (HF, CB, POC)

/// La radio vera: tre bande che si ascoltano da ricevitori e server pubblici.
private struct OnboardingLiveRadioPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 72, weight: .light))
                .foregroundColor(Color("PrimaryTextColor"))

            VStack(spacing: 12) {
                Text(OnboardingStrings.liveTitle)
                    .font(.title.bold())
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)
                Text(OnboardingStrings.liveSubtitle)
                    .font(.title3)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            SpectrumSketch()
                .frame(height: 96)
                .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 14) {
                bandRow("HF", OnboardingStrings.liveHF)
                bandRow("CB", OnboardingStrings.liveCB)
                bandRow("POC", OnboardingStrings.livePOC)
            }
            .padding(.horizontal, 28)

            Text(String(format: OnboardingStrings.liveNote, FreeListening.secondsPerDay / 60))
                .font(.footnote)
                .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding()
    }

    private func bandRow(_ band: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(band)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundColor(.yellow)
                .frame(width: 46, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.black))
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color("PrimaryTextColor"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Widgets

private struct OnboardingWidgetsPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 72, weight: .light))
                .foregroundColor(Color("PrimaryTextColor"))

            VStack(spacing: 12) {
                Text(OnboardingStrings.widgetsTitle)
                    .font(.title.bold())
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)
                Text(OnboardingStrings.widgetsSubtitle)
                    .font(.title3)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 14) {
                row("dot.radiowaves.left.and.right", OnboardingStrings.widgetsChannel)
                row("chart.bar.fill", OnboardingStrings.widgetsPropagation)
                row("sun.horizon.fill", OnboardingStrings.widgetsSun)
            }
            .padding(.horizontal, 28)

            Text(Tour.text("tour.perk.widgets.where"))
                .font(.footnote)
                .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding()
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.yellow)
                .frame(width: 34, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.black))
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color("PrimaryTextColor"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Uno schizzo dello schermo HF/CB: la traccia dello spettro sopra e la
/// cascata sotto, con due portanti. E' un disegno e non un segnale vero:
/// l'onboarding non si collega a nessun ricevitore.
private struct SpectrumSketch: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height, split = h * 0.38
            let carriers: [CGFloat] = [0.32, 0.61]
            func level(_ x: CGFloat, _ row: Int) -> CGFloat {
                let noise = (sin(x * 61 + CGFloat(row) * 1.7) + sin(x * 23 + CGFloat(row) * 0.9)) * 0.08
                let peaks = carriers.map { c in max(0, 1 - abs(x - c) * 40) }.reduce(0, +)
                return min(1, 0.2 + noise + peaks * 0.7)
            }
            let rows = 14
            let rowH = (h - split) / CGFloat(rows)
            for row in 0..<rows {
                var x: CGFloat = 0
                while x < w {
                    let v = level(x / w, row)
                    ctx.fill(Path(CGRect(x: x, y: split + CGFloat(row) * rowH, width: 3, height: rowH + 0.5)),
                             with: .color(Color(red: 1, green: 0.78, blue: 0).opacity(Double(v) * 0.9)))
                    x += 3
                }
            }
            var line = Path()
            var x: CGFloat = 0
            while x <= w {
                let y = split - 4 - level(x / w, 0) * (split - 8)
                if x == 0 { line.move(to: CGPoint(x: x, y: y)) } else { line.addLine(to: CGPoint(x: x, y: y)) }
                x += 2
            }
            ctx.stroke(line, with: .color(.yellow), lineWidth: 1.5)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Steps

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

                    // Linea guida 5.1.1(iv): il bottone che precede il prompt di
                    // sistema non deve spingere verso il si', quindi "Continua" e
                    // mai "Consenti" (rifiuto iOS 2.44, 9 ago 2026 — stesso
                    // rilievo gia' preso su macOS il 6 agosto). Il testo
                    // esplicativo sopra invece e' consentito e va tenuto.
                    VStack(spacing: 12) {
                        Button(action: requestPermissions) {
                            HStack {
                                if isRequestingPermissions {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(OnboardingStrings.continueButton)
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

                        // Niente "Salta" qui: la 5.1.1(iv) vuole che dopo il
                        // messaggio esplicativo si arrivi SEMPRE al prompt di
                        // sistema, e questo bottone permetteva di rimandarlo.
                        // Nessuno resta bloccato: requestPermissions() chiude
                        // comunque il foglio, anche se l'utente rifiuta o se il
                        // permesso era gia' stato deciso e il prompt non riappare.
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
