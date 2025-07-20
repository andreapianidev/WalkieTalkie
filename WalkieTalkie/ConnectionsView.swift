//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - ConnectionsView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import SwiftUI
import MultipeerConnectivity

struct ConnectionsView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @State private var showingDisconnectAlert = false
    @State private var selectedPeer: MCPeerID?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerView
            
            // Connection info textbox
            connectionInfoView
            
            // Status section
            statusSection
            
            // Connected devices
            connectedDevicesSection
            
            // Controls
            controlsSection
            
            Spacer()
        }
        .padding()
        .alert("disconnect_device".localized, isPresented: $showingDisconnectAlert) {
            Button("disconnect".localized, role: .destructive) {
                multipeerManager.disconnect()
            }
            Button("cancel".localized, role: .cancel) { }
        } message: {
            Text("disconnect_confirmation".localized)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(Color("PrimaryTextColor"))
            
            Text("connections".localized)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color("PrimaryTextColor"))
            
            Text("manage_connections".localized)
                .font(.caption)
                .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
        }
    }
    
    private var connectionInfoView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("device".localized + ": \(multipeerManager.localPeerID.displayName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("PrimaryTextColor"))
                
                HStack {
                    Text("connected_devices".localized + ": \(multipeerManager.connectedPeers.count)")
                        .font(.caption)
                        .foregroundColor(multipeerManager.connectedPeers.isEmpty ? .red : .green)
                    
                    if multipeerManager.isBrowsing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("scanning".localized)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack {
                Circle()
                    .fill(multipeerManager.connectedPeers.isEmpty ? Color.red : Color.green)
                    .frame(width: 12, height: 12)
                Text(multipeerManager.connectedPeers.isEmpty ? "offline".localized : "online".localized)
                    .font(.caption2)
                    .foregroundColor(multipeerManager.connectedPeers.isEmpty ? .red : .green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("SurfaceColor"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(multipeerManager.isAdvertising ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text("advertising".localized + ": \(multipeerManager.isAdvertising ? "on".localized : "off".localized)")
                    .font(.subheadline)
                    .foregroundColor(Color("PrimaryTextColor"))
                
                Spacer()
            }
            
            HStack {
                Circle()
                    .fill(multipeerManager.isBrowsing ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text("browsing".localized + ": \(multipeerManager.isBrowsing ? "on".localized : "off".localized)")
                    .font(.subheadline)
                    .foregroundColor(Color("PrimaryTextColor"))
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("SurfaceColor"))
        )
    }
    
    private var connectedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("connected_devices".localized + " (\(multipeerManager.connectedPeers.count))")
                .font(.headline)
                .foregroundColor(Color("PrimaryTextColor"))
            
            if multipeerManager.connectedPeers.isEmpty {
                VStack {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 40))
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
                    
                    Text("no_devices_connected".localized)
                    .font(.subheadline)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    
                    Text("devices_nearby_hint".localized)
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(multipeerManager.connectedPeers, id: \.self) { peer in
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(Color("PrimaryTextColor"))
                        
                        VStack(alignment: .leading) {
                            Text(peer.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color("PrimaryTextColor"))
                            
                            Text("connected".localized)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("SurfaceColor"))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.1))
        )
    }
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            if !multipeerManager.connectedPeers.isEmpty {
                Button(action: {
                    showingDisconnectAlert = true
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("disconnect_all".localized)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red)
                    )
                }
            }
            
            Button(action: {
                // Restart discovery
                multipeerManager.stopAdvertising()
                multipeerManager.stopBrowsing()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    multipeerManager.startAdvertising()
                    multipeerManager.startBrowsing()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("restart_discovery".localized)
                }
                .foregroundColor(Color("PrimaryTextColor"))
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color("SurfaceColor"))
                )
            }
        }
    }
}

#Preview {
    ConnectionsView(multipeerManager: MultipeerManager())
}