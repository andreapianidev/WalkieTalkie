//creato da Andrea Piani - Immaginet Srl - 2024 - https://www.andreapiani.com - ExploreView.swift

import SwiftUI
import MultipeerConnectivity

struct ExploreView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @State private var radarRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var scanningOpacity: Double = 0.3
    @State private var detectedDevices: [DetectedDevice] = []
    
    private let radarRadius: CGFloat = 120
    private let maxRange: Double = 100 // metri
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Spacer()
            
            // Radar Display
            radarView
            
            Spacer()
            
            // Device List
            deviceListView
            
            Spacer(minLength: 100)
        }
        .background(Color("BackgroundColor"))
        .onAppear {
            startRadarAnimation()
            updateDetectedDevices()
        }
        .onReceive(multipeerManager.$connectedPeers) { _ in
            updateDetectedDevices()
        }
        .onReceive(multipeerManager.$discoveredPeers) { _ in
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
    
    private var radarView: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                radarBackground(center: center)
                radarSweepEffects(center: center)
                radarDevices(center: center)
                radarLabels(center: center)
            }
        }
        .frame(width: radarRadius * 2 + 60, height: radarRadius * 2 + 60)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func radarBackground(center: CGPoint) -> some View {
        ZStack {
            // Background circles (range rings)
            ForEach(1..<5) { ring in
                Circle()
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    .frame(width: radarRadius * 2 * CGFloat(ring) / 4,
                           height: radarRadius * 2 * CGFloat(ring) / 4)
                    .position(center)
            }
            
            // Main radar circle
            Circle()
                .stroke(Color.black, lineWidth: 2)
                .frame(width: radarRadius * 2, height: radarRadius * 2)
                .position(center)
            
            // Crosshairs
            Path { path in
                path.move(to: CGPoint(x: center.x - radarRadius, y: center.y))
                path.addLine(to: CGPoint(x: center.x + radarRadius, y: center.y))
                path.move(to: CGPoint(x: center.x, y: center.y - radarRadius))
                path.addLine(to: CGPoint(x: center.x, y: center.y + radarRadius))
            }
            .stroke(Color.black.opacity(0.3), lineWidth: 1)
        }
    }
    
    private func radarSweepEffects(center: CGPoint) -> some View {
        ZStack {
            // Scanning pulse
            Circle()
                .stroke(Color.green.opacity(scanningOpacity), lineWidth: 3)
                .frame(width: radarRadius * 2 * pulseScale,
                       height: radarRadius * 2 * pulseScale)
                .position(center)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseScale)
            
            // Radar sweep line with gradient effect
            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x, y: center.y - radarRadius))
            }
            .stroke(
                LinearGradient(
                    colors: [Color.green.opacity(0.8), Color.green.opacity(0.1)],
                    startPoint: .center,
                    endPoint: .top
                ),
                lineWidth: 3
            )
            .rotationEffect(.degrees(radarRotation), anchor: UnitPoint(x: 0.5, y: 0.5))
            .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: radarRotation)
            
            // Radar sweep shadow/trail
            ForEach(0..<8) { i in
                Path { path in
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x, y: center.y - radarRadius))
                }
                .stroke(
                    Color.green.opacity(0.1 - Double(i) * 0.01),
                    lineWidth: 2
                )
                .rotationEffect(.degrees(radarRotation - Double(i) * 5), anchor: UnitPoint(x: 0.5, y: 0.5))
            }
        }
    }
    
    private func radarDevices(center: CGPoint) -> some View {
        ZStack {
            // Detected devices
            ForEach(detectedDevices) { device in
                deviceDot(for: device, center: center)
            }
            
            // Center dot (your position)
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .position(center)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .position(center)
                )
        }
    }
    
    private func radarLabels(center: CGPoint) -> some View {
        ZStack {
            // Fixed range labels
            ForEach(1..<5) { ring in
                Text("\(Int(maxRange * Double(ring) / 4))m")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.8))
                            .padding(.horizontal, -4)
                            .padding(.vertical, -1)
                    )
                    .position(
                        x: center.x + (radarRadius * CGFloat(ring) / 4) + 15,
                        y: center.y - 8
                    )
            }
        }
    }
    
    private func deviceDot(for device: DetectedDevice, center: CGPoint) -> some View {
        let devicePosition = CGPoint(
            x: center.x + device.position.x,
            y: center.y + device.position.y
        )
        
        return ZStack {
            // Device glow effect
            Circle()
                .fill(device.isConnected ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
                .frame(width: 20, height: 20)
                .position(devicePosition)
                .scaleEffect(device.pulseScale * 1.5)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: device.pulseScale)
            
            // Main device dot
            Circle()
                .fill(device.isConnected ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
                .position(devicePosition)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 12, height: 12)
                        .position(devicePosition)
                )
                .scaleEffect(device.pulseScale)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: device.pulseScale)
            
            // Device name label
            Text(device.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(Color("PrimaryTextColor"))
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color("SurfaceColor"))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .padding(.horizontal, -6)
                        .padding(.vertical, -2)
                )
                .position(
                    x: devicePosition.x,
                    y: devicePosition.y - 25
                )
        }
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
        HStack {
            Circle()
                .fill(device.isConnected ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                
                Text(device.isConnected ? "connected".localized : "available".localized)
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("~\(Int(device.estimatedDistance))m")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                
                Text(device.signalStrength)
                    .font(.caption2)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
            }
            
            if !device.isConnected {
                Button(action: {
                    // Connect to device
                    if let peer = multipeerManager.discoveredPeers.first(where: { $0.displayName == device.name }) {
                        multipeerManager.invitePeer(peer)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.black)
                        .font(.title3)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.05))
        )
    }
    
    private func startRadarAnimation() {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            radarRotation = 360
        }
        
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.5
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            scanningOpacity = 0.8
        }
    }
    
    private func updateDetectedDevices() {
        var devices: [DetectedDevice] = []
        
        // Add connected peers
        for peer in multipeerManager.connectedPeers {
            let device = DetectedDevice(
                id: peer.displayName,
                name: peer.displayName,
                isConnected: true,
                estimatedDistance: Double.random(in: 5...30),
                signalStrength: "Strong",
                position: randomPosition(),
                pulseScale: 1.2
            )
            devices.append(device)
        }
        
        // Add nearby peers
        for peer in multipeerManager.discoveredPeers {
            if !multipeerManager.connectedPeers.contains(peer) {
                let device = DetectedDevice(
                    id: peer.displayName,
                    name: peer.displayName,
                    isConnected: false,
                    estimatedDistance: Double.random(in: 10...80),
                    signalStrength: ["weak".localized, "medium".localized, "strong".localized].randomElement() ?? "medium".localized,
                    position: randomPosition(),
                    pulseScale: 1.0
                )
                devices.append(device)
            }
        }
        
        detectedDevices = devices
    }
    
    private func randomPosition() -> CGPoint {
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = Double.random(in: 20...Double(radarRadius - 20))
        
        let x = cos(angle) * distance
        let y = sin(angle) * distance
        
        return CGPoint(x: x, y: y)
    }
}

struct DetectedDevice: Identifiable {
    let id: String
    let name: String
    let isConnected: Bool
    let estimatedDistance: Double
    let signalStrength: String
    let position: CGPoint
    let pulseScale: CGFloat
}

#Preview {
    ExploreView(multipeerManager: MultipeerManager())
}