//
//  LiveActivityManager.swift
//  Talky
//
//  Orchestrates the radio and walkie Live Activities. Singleton, MainActor-isolated.
//  Gated at iOS 16.2+ — older devices simply skip the Live Activity path and keep
//  the existing MPNowPlayingInfoCenter-only behaviour.
//

import Foundation
import ActivityKit
import os.log

@available(iOS 16.2, *)
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var radioActivity: Activity<RadioActivityAttributes>?
    private var walkieActivity: Activity<WalkieActivityAttributes>?

    private var didBootstrap = false

    private init() {}

    /// Activities-enabled check (user toggle in iOS Settings → app).
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Wires the NotificationCenter observers for interactive intent broadcasts
    /// (iOS 17+) and reconnects to any in-flight activity (e.g., app relaunched
    /// while LA still on screen).
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        Logger.shared.logInfo("LiveActivityManager bootstrap")

        // Recover any live activity that may already exist (app was killed and
        // relaunched while the LA was still on screen, system kept it alive).
        radioActivity = Activity<RadioActivityAttributes>.activities.first
        walkieActivity = Activity<WalkieActivityAttributes>.activities.first

        // Observe interactive intent broadcasts. These come from
        // LiveActivityIntent.perform() in the widget UI on iOS 17+.
        NotificationCenter.default.addObserver(
            forName: .talkyRadioTogglePlayPause,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in Self.handleRadioTogglePlayPause() }
        }
        NotificationCenter.default.addObserver(
            forName: .talkyRadioNextStation,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in Self.handleRadioNext() }
        }
        NotificationCenter.default.addObserver(
            forName: .talkyRadioPreviousStation,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in Self.handleRadioPrevious() }
        }
    }

    // MARK: - Radio

    func startRadio(stationName: String, country: String, flag: String, frequency: String, genre: String, isPlaying: Bool, isBuffering: Bool) {
        guard areActivitiesEnabled else {
            Logger.shared.logInfo("Live Activities disabled by user, skip startRadio")
            return
        }
        // End any existing radio activity first (one-at-a-time semantics).
        if let existing = radioActivity {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
            radioActivity = nil
        }
        // Also end any walkie activity — modes are mutually exclusive in the UI,
        // but defensive cleanup avoids two icons piling up if the user switches fast.
        endWalkie()

        let state = RadioActivityAttributes.ContentState(
            stationName: stationName,
            stationCountry: country,
            stationFlag: flag,
            stationFrequency: frequency,
            stationGenre: genre,
            isPlaying: isPlaying,
            isBuffering: isBuffering
        )
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            radioActivity = try Activity.request(
                attributes: RadioActivityAttributes(),
                content: content,
                pushType: nil
            )
            Logger.shared.logAudioInfo("Live Activity Radio started: \(stationName)")
        } catch {
            Logger.shared.logAudioError(error, context: "Live Activity Radio start")
        }
    }

    /// Convenience: start if no activity, update otherwise. Matches the call sites
    /// in RadioManager that already mirror the same data into MPNowPlayingInfoCenter.
    func startOrUpdateRadio(stationName: String, country: String, flag: String, frequency: String, genre: String, isPlaying: Bool, isBuffering: Bool) {
        if radioActivity == nil {
            startRadio(stationName: stationName, country: country, flag: flag, frequency: frequency, genre: genre, isPlaying: isPlaying, isBuffering: isBuffering)
        } else {
            updateRadio(stationName: stationName, country: country, flag: flag, frequency: frequency, genre: genre, isPlaying: isPlaying, isBuffering: isBuffering)
        }
    }

    func updateRadio(stationName: String, country: String, flag: String, frequency: String, genre: String, isPlaying: Bool, isBuffering: Bool) {
        guard let activity = radioActivity else { return }
        let state = RadioActivityAttributes.ContentState(
            stationName: stationName,
            stationCountry: country,
            stationFlag: flag,
            stationFrequency: frequency,
            stationGenre: genre,
            isPlaying: isPlaying,
            isBuffering: isBuffering
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.update(content) }
    }

    func endRadio() {
        guard let activity = radioActivity else { return }
        radioActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        Logger.shared.logAudioInfo("Live Activity Radio ended")
    }

    // MARK: - Walkie

    func startWalkie(connectedPeerCount: Int, peerNames: [String], channelName: String) {
        guard areActivitiesEnabled else { return }
        if let existing = walkieActivity {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
            walkieActivity = nil
        }
        endRadio()

        let state = WalkieActivityAttributes.ContentState(
            connectedPeerCount: connectedPeerCount,
            peerNames: Array(peerNames.prefix(3)),
            channelName: channelName,
            talkerName: nil
        )
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            walkieActivity = try Activity.request(
                attributes: WalkieActivityAttributes(),
                content: content,
                pushType: nil
            )
            Logger.shared.logNetworkInfo("Live Activity Walkie started: \(connectedPeerCount) peer(s)")
        } catch {
            Logger.shared.logNetworkError(error, context: "Live Activity Walkie start")
        }
    }

    /// Convenience for the walkie side — start if no activity, update otherwise.
    func startOrUpdateWalkie(connectedPeerCount: Int, peerNames: [String], channelName: String, talkerName: String?) {
        if walkieActivity == nil {
            startWalkie(connectedPeerCount: connectedPeerCount, peerNames: peerNames, channelName: channelName)
            if talkerName != nil {
                updateWalkie(connectedPeerCount: connectedPeerCount, peerNames: peerNames, channelName: channelName, talkerName: talkerName)
            }
        } else {
            updateWalkie(connectedPeerCount: connectedPeerCount, peerNames: peerNames, channelName: channelName, talkerName: talkerName)
        }
    }

    func updateWalkie(connectedPeerCount: Int, peerNames: [String], channelName: String, talkerName: String?) {
        guard let activity = walkieActivity else { return }
        let state = WalkieActivityAttributes.ContentState(
            connectedPeerCount: connectedPeerCount,
            peerNames: Array(peerNames.prefix(3)),
            channelName: channelName,
            talkerName: talkerName
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.update(content) }
    }

    func endWalkie() {
        guard let activity = walkieActivity else { return }
        walkieActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        Logger.shared.logNetworkInfo("Live Activity Walkie ended")
    }

    // MARK: - Intent Handlers

    /// Tap on play/pause from the Dynamic Island.
    private static func handleRadioTogglePlayPause() {
        let radio = RadioManager.shared
        if radio.isPlaying {
            radio.pauseRadio()
        } else if radio.currentStation != nil {
            radio.resumeRadio()
        }
    }

    /// Tap on ⏭ — moves through favorites if any, else through the full available pool.
    private static func handleRadioNext() {
        let radio = RadioManager.shared
        let favs = radio.favoriteStations
        if favs.isEmpty {
            radio.nextStation()
            return
        }
        let current = radio.currentStation
        let idx = current.flatMap { c in favs.firstIndex { $0.id == c.id } } ?? -1
        let next = favs[(idx + 1) % favs.count]
        radio.playStation(next)
    }

    /// Tap on ⏮ — moves through favorites if any, else through the full available pool.
    private static func handleRadioPrevious() {
        let radio = RadioManager.shared
        let favs = radio.favoriteStations
        if favs.isEmpty {
            radio.previousStation()
            return
        }
        let current = radio.currentStation
        let idx = current.flatMap { c in favs.firstIndex { $0.id == c.id } } ?? 0
        let prev = favs[(idx - 1 + favs.count) % favs.count]
        radio.playStation(prev)
    }
}
