//
//  PerformanceStatsView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//  Real-time Performance Statistics View
//

import SwiftUI
import Charts

struct PerformanceStatsView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var showingRecommendations = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header con stato generale
                    performanceHeaderView
                    
                    // Metriche principali
                    metricsGridView
                    
                    // Grafici delle performance
                    chartsSection
                    
                    // Raccomandazioni
                    recommendationsSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("performance_title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("recommendations".localized) {
                        showingRecommendations = true
                    }
                }
            }
            .sheet(isPresented: $showingRecommendations) {
                RecommendationsView()
            }
        }
    }
    
    // MARK: - Header View
    
    private var performanceHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: performanceMonitor.isHighTrafficMode ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(performanceMonitor.isHighTrafficMode ? .orange : .green)
                    .font(.title2)
                
                Text(performanceMonitor.isHighTrafficMode ? "high_traffic".localized : "normal_performance".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack {
                Text("\(performanceMonitor.currentConnectionCount) " + "connections_active".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("updated_now".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            MetricCard(
                title: "memory_usage".localized,
                value: "\(String(format: "%.1f", performanceMonitor.memoryUsage))%",
                icon: "memorychip",
                color: performanceMonitor.memoryUsage > 70 ? .orange : .blue
            )
            
            MetricCard(
                title: "network_latency".localized,
                value: "\(String(format: "%.0f", performanceMonitor.networkLatency * 1000))ms",
                icon: "wifi",
                color: performanceMonitor.networkLatency > 1.0 ? .red : .green
            )
            
            MetricCard(
                title: "connection_time".localized,
                value: "\(String(format: "%.1f", performanceMonitor.averageConnectionTime))s",
                icon: "timer",
                color: performanceMonitor.averageConnectionTime > 5.0 ? .orange : .blue
            )
            
            MetricCard(
                title: "active_connections".localized,
                value: "\(performanceMonitor.currentConnectionCount)/8",
                icon: "person.3",
                color: performanceMonitor.currentConnectionCount > 6 ? .orange : .green
            )
        }
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("performance_trends".localized)
                .font(.headline)
                .fontWeight(.semibold)
            
            // Grafico memoria
            VStack(alignment: .leading, spacing: 8) {
                Text("memory_usage".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ProgressView(value: performanceMonitor.memoryUsage / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: performanceMonitor.memoryUsage > 70 ? .orange : .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Indicatori di stato
            HStack(spacing: 16) {
                StatusIndicator(
                    title: "optimized_mode".localized,
                    isActive: performanceMonitor.isHighTrafficMode,
                    activeColor: .orange,
                    inactiveColor: .green
                )
                
                StatusIndicator(
                    title: "audio_cache".localized,
                    isActive: true,
                    activeColor: .blue,
                    inactiveColor: .gray
                )
            }
        }
    }
    
    // MARK: - Recommendations Section
    
    private var recommendationsSection: some View {
        let recommendations = performanceMonitor.getPerformanceRecommendations()
        
        return Group {
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("recommendations".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(recommendations.prefix(3), id: \.self) { recommendation in
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                            
                            Text(recommendation)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemYellow).opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusIndicator: View {
    let title: String
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? activeColor : inactiveColor)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(isActive ? activeColor : .secondary)
        }
    }
}

struct RecommendationsView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("current_recommendations".localized) {
                    let recommendations = performanceMonitor.getPerformanceRecommendations()
                    
                    if recommendations.isEmpty {
                        Text("no_recommendations".localized)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(recommendations, id: \.self) { recommendation in
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                
                                Text(recommendation)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                }
                
                Section("full_report".localized) {
                    let report = performanceMonitor.getPerformanceReport()
                    
                    ForEach(report.keys.sorted(), id: \.self) { key in
                        if let value = report[key] {
                            HStack {
                                Text(key.capitalized)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(value)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("recommendations".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PerformanceStatsView()
}