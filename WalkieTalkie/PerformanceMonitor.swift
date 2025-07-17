//
//  PerformanceMonitor.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//  High Traffic Performance Monitoring System
//

import Foundation
import Combine
import os.log

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()
    private var performanceTimer: Timer?
    
    // MARK: - Performance Metrics
    @Published var currentConnectionCount = 0
    @Published var averageConnectionTime: TimeInterval = 0
    @Published var memoryUsage: Double = 0
    @Published var networkLatency: TimeInterval = 0
    @Published var isHighTrafficMode = false
    
    // MARK: - Thresholds
    private let highTrafficThreshold = 5 // connections
    private let memoryWarningThreshold: Double = 80.0 // percentage
    private let latencyThreshold: TimeInterval = 2.0 // seconds
    
    // MARK: - Performance History
    private var connectionTimes: [TimeInterval] = []
    private var latencyMeasurements: [TimeInterval] = []
    private let maxHistorySize = 20
    
    private init() {
        startPerformanceMonitoring()
    }
    
    deinit {
        stopPerformanceMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
        
        logger.logNetworkInfo("Performance monitoring avviato")
    }
    
    private func stopPerformanceMonitoring() {
        performanceTimer?.invalidate()
        performanceTimer = nil
    }
    
    // MARK: - Metrics Collection
    
    private func updatePerformanceMetrics() {
        updateMemoryUsage()
        updateAverageConnectionTime()
        updateNetworkLatency()
        evaluateHighTrafficMode()
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0 // MB
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 // MB
            memoryUsage = (usedMemory / totalMemory) * 100.0
        }
    }
    
    private func updateAverageConnectionTime() {
        guard !connectionTimes.isEmpty else { return }
        averageConnectionTime = connectionTimes.reduce(0, +) / Double(connectionTimes.count)
    }
    
    private func updateNetworkLatency() {
        guard !latencyMeasurements.isEmpty else { return }
        networkLatency = latencyMeasurements.reduce(0, +) / Double(latencyMeasurements.count)
    }
    
    // MARK: - High Traffic Detection
    
    private func evaluateHighTrafficMode() {
        let shouldEnableHighTraffic = currentConnectionCount >= highTrafficThreshold ||
                                    memoryUsage > memoryWarningThreshold ||
                                    networkLatency > latencyThreshold
        
        if shouldEnableHighTraffic != isHighTrafficMode {
            isHighTrafficMode = shouldEnableHighTraffic
            
            if isHighTrafficMode {
                logger.logNetworkWarning("Modalità traffico elevato attivata - Connessioni: \(currentConnectionCount), Memoria: \(String(format: "%.1f", memoryUsage))%, Latenza: \(String(format: "%.2f", networkLatency))s")
                // Note: MultipeerManager optimization will be handled by the manager itself
            } else {
                logger.logNetworkInfo("Modalità traffico elevato disattivata")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func recordConnectionTime(_ time: TimeInterval) {
        connectionTimes.append(time)
        if connectionTimes.count > maxHistorySize {
            connectionTimes.removeFirst()
        }
    }
    
    func recordLatency(_ latency: TimeInterval) {
        latencyMeasurements.append(latency)
        if latencyMeasurements.count > maxHistorySize {
            latencyMeasurements.removeFirst()
        }
    }
    
    func updateConnectionCount(_ count: Int) {
        currentConnectionCount = count
    }
    
    func getPerformanceReport() -> [String: Any] {
        return [
            "connectionCount": currentConnectionCount,
            "averageConnectionTime": averageConnectionTime,
            "memoryUsage": memoryUsage,
            "networkLatency": networkLatency,
            "isHighTrafficMode": isHighTrafficMode,
            "connectionHistory": connectionTimes,
            "latencyHistory": latencyMeasurements
        ]
    }
    
    func forceHighTrafficMode(_ enabled: Bool) {
        isHighTrafficMode = enabled
        if enabled {
            logger.logNetworkInfo("Modalità traffico elevato forzata")
            // Note: MultipeerManager optimization will be handled by the manager itself
        }
    }
    
    // MARK: - Performance Recommendations
    
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if memoryUsage > 70.0 {
            recommendations.append("Memoria elevata (\(String(format: "%.1f", memoryUsage))%) - Considera di ridurre le connessioni")
        }
        
        if networkLatency > 1.5 {
            recommendations.append("Latenza elevata (\(String(format: "%.2f", networkLatency))s) - Verifica la connessione di rete")
        }
        
        if currentConnectionCount > 8 {
            recommendations.append("Troppe connessioni (\(currentConnectionCount)) - Considera di limitare a 6-8 per prestazioni ottimali")
        }
        
        if averageConnectionTime > 10.0 {
            recommendations.append("Tempo di connessione lento (\(String(format: "%.1f", averageConnectionTime))s) - Verifica la stabilità della rete")
        }
        
        return recommendations
    }
}

// MARK: - Extensions

extension PerformanceMonitor {
    func startLatencyTest(to peer: String) {
        let startTime = Date()
        
        // Simulate ping test (in real implementation, this would send a ping packet)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let latency = Date().timeIntervalSince(startTime)
            self?.recordLatency(latency)
            self?.logger.logNetworkDebug("Latenza misurata per \(peer): \(String(format: "%.3f", latency))s")
        }
    }
}