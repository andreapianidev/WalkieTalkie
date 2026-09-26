//creato da Andrea Piani - 2024 - https://www.andreapiani.com - ExploreView.swift

import SwiftUI
import MultipeerConnectivity

struct ExploreView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @ObservedObject private var crossPlatformManager = TalkyCrossPlatformManager.shared
    @State private var searchWave: Bool = false
    @State private var detectedDevices: [DetectedDevice] = []
    @State private var showPaywall: Bool = false
    @State private var pendingInvitePeerIDs: Set<String> = []

    /// iPhone 8/SE (667 pt) e simili: pannello di ricerca piu' basso, cosi' la
    /// lista dei dispositivi, con i "+" per invitare, resta sopra la tab bar.
    private let isCompact: Bool = UIScreen.main.bounds.height < 700
    private var waveSize: CGFloat { isCompact ? 96 : 130 }

    var body: some View {
        FitOrScroll {
        VStack(spacing: 0) {
            // Header
            headerView

            // Banner Pro discreto: cooldown 7gg gestito da ProUpsellBanner.
            // Posizionato sotto l'header per essere visibile senza coprire il pannello di ricerca.
            ProUpsellBanner(placement: .explore) {
                showPaywall = true
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            // Alternativa morbida al paywall: guarda un video → 1h senza ads.
            // Si auto-nasconde per i Pro o se il reward è già attivo.
            RewardAdCTAView(source: "explore_banner")
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Adaptive banner: low-interaction view, safe for a persistent ad.
            AdaptiveBannerView()
                .padding(.horizontal, 16)
                .padding(.top, 6)

            Spacer()

            // Stato della ricerca (niente radar: Multipeer non da' distanze)
            searchPanel

            Spacer()

            // Device List
            deviceListView

            Spacer(minLength: 100)
        }
        }
        .background(Color("BackgroundColor"))
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(trigger: "explore_banner")
        }
        .onAppear {
            searchWave = true
            updateDetectedDevices()
        }
        .onReceive(multipeerManager.$connectedPeers) { _ in
            updateDetectedDevices()
        }
        .onReceive(multipeerManager.$discoveredPeers) { _ in
            updateDetectedDevices()
        }
        .onReceive(crossPlatformManager.$peers) { _ in
            updateDetectedDevices()
        }
        .onReceive(crossPlatformManager.$connectedPeerCount) { _ in
            updateDetectedDevices()
        }
        .onReceive(crossPlatformManager.$connectedPeerIDs) { _ in
            updateDetectedDevices()
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color("PrimaryTextColor"))
                .font(.title2)
            
            Spacer()
            
            VStack {
                Text("explore".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("scan_nearby_devices".localized)
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
            }
            
            Spacer()
            
            Button(action: {
                multipeerManager.stopBrowsing()
                multipeerManager.startBrowsing()
                crossPlatformManager.start()
            }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(Color("PrimaryTextColor"))
                    .font(.title2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 15)
    }
    
    /// Pannello di ricerca. Prima qui c'era un radar con anelli a 25, 50, 75 e
    /// 100 metri e i dispositivi disegnati in posizioni casuali: Multipeer non
    /// da' ne' distanza ne' intensita' del segnale, quindi era tutto inventato.
    /// Adesso dice solo quello che l'app sa davvero: se sta cercando e quanti
    /// dispositivi ha trovato. L'animazione e' un'onda senza scala ne' posizioni.
    private var searchPanel: some View {
        VStack(spacing: isCompact ? 10 : 14) {
            ZStack {
                ForEach(0..<2) { i in
                    Circle()
                        .stroke(Color.green.opacity(multipeerManager.isBrowsing ? 0.5 : 0.0), lineWidth: 2)
                        .frame(width: waveSize, height: waveSize)
                        .scaleEffect(searchWave ? 1.0 : 0.35)
                        .opacity(searchWave ? 0.0 : 1.0)
                        .animation(
                            multipeerManager.isBrowsing
                                ? .easeOut(duration: 2.2).repeatForever(autoreverses: false).delay(Double(i) * 1.1)
                                : .default,
                            value: searchWave
                        )
                }

                Circle()
                    .fill(Color("SurfaceColor"))
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 1))

                Image(systemName: multipeerManager.isBrowsing
                      ? "antenna.radiowaves.left.and.right"
                      : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color("PrimaryTextColor"))
            }
            .frame(height: waveSize)
            .accessibilityHidden(true)

            Text(multipeerManager.isBrowsing ? "explore.searching".localized : "explore.search_stopped".localized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color("PrimaryTextColor"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompact ? 12 : 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private var deviceListView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.black)
                Text("detected_devices".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
                Text("\(detectedDevices.count)")
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.1))
                    )
            }

            if !detectedDevices.isEmpty {
                Text("tap_plus_to_invite".localized)
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if detectedDevices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.title2)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
                    Text("no_devices_detected".localized)
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    Text("ensure_devices_open".localized)
                        .font(.caption)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(detectedDevices) { device in
                        deviceRow(for: device)
                    }
                }
            }
        }
        .padding()
        .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color("SurfaceColor"))
            )
        .padding(.horizontal, 20)
    }
    
    private func deviceRow(for device: DetectedDevice) -> some View {
        let isInvitePending = pendingInvitePeerIDs.contains(device.id)

        return HStack {
            Circle()
                .fill(deviceStatusColor(device, isInvitePending: isInvitePending))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                
                Text(deviceStatusText(device, isInvitePending: isInvitePending))
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))

                Text(device.transportLabel)
                    .font(.caption2)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.45))
            }
            
            Spacer()
            
            if !device.isConnected, let peerID = device.applePeerID {
                Button(action: {
                    pendingInvitePeerIDs.insert(device.id)
                    multipeerManager.invitePeer(peerID)
                }) {
                    if isInvitePending {
                        ProgressView()
                            .scaleEffect(0.75)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.black)
                            .font(.title3)
                    }
                }
                .disabled(isInvitePending)
                .accessibilityLabel(isInvitePending ? "invitation_sent".localized : "send_connection_request".localized)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.05))
        )
    }
    
    private func updateDetectedDevices() {
        var devices: [DetectedDevice] = []
        
        // Add connected peers
        for peer in multipeerManager.connectedPeers {
            let device = DetectedDevice(
                id: "apple-\(peer.hash)",
                applePeerID: peer,
                name: peer.displayName,
                transportLabel: "Apple",
                isConnected: true,
            )
            devices.append(device)
        }
        
        // Add nearby peers
        for peer in multipeerManager.discoveredPeers {
            if !multipeerManager.connectedPeers.contains(peer) {
                let device = DetectedDevice(
                    id: "apple-\(peer.hash)",
                    applePeerID: peer,
                    name: peer.displayName,
                    transportLabel: "Apple",
                    isConnected: false,
                )
                devices.append(device)
            }
        }

        for peer in crossPlatformManager.peers {
            let isConnected = crossPlatformManager.connectedPeerIDs.contains(peer.id)
            let device = DetectedDevice(
                id: "android-\(peer.id)",
                applePeerID: nil,
                name: peer.name,
                transportLabel: "Android / Cross-platform",
                isConnected: isConnected,
            )
            devices.append(device)
        }
        
        detectedDevices = devices
        let visiblePeerIDs = Set(devices.map(\.id))
        pendingInvitePeerIDs = pendingInvitePeerIDs.intersection(visiblePeerIDs)
        for peer in multipeerManager.connectedPeers {
            pendingInvitePeerIDs.remove("apple-\(peer.hash)")
        }
    }

    private func deviceStatusColor(_ device: DetectedDevice, isInvitePending: Bool) -> Color {
        if device.isConnected { return .green }
        return isInvitePending ? .blue : .orange
    }

    private func deviceStatusText(_ device: DetectedDevice, isInvitePending: Bool) -> String {
        if device.isConnected { return "connected".localized }
        return isInvitePending ? "invitation_sent".localized : "available".localized
    }
}

struct DetectedDevice: Identifiable {
    let id: String
    let applePeerID: MCPeerID?
    let name: String
    let transportLabel: String
    let isConnected: Bool
}

#Preview {
    ExploreView(multipeerManager: MultipeerManager())
}
