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
import MultipeerConnectivity
import os.log

@available(iOS 16.2, *)
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var radioActivity: Activity<RadioActivityAttributes>?
    private var walkieActivity: Activity<WalkieActivityAttributes>?

    private var didBootstrap = false

    /// Lifecycle queue. Each start/update/end appends to a single Task chain.
    /// Awaiting the previous task before the next op completes serializes ActivityKit
    /// requests, preventing the "ivar nil-ed before await end completes" race that
    /// otherwise made rapid mode switches leak activities or fail with
    /// `targetMaximumExceeded`.
    private var pendingLifecycle: Task<Void, Never>?

    /// Synchronous "this mode is intended to be visible" flags. Set/cleared *before*
    /// scheduling work, so precedence checks (radio wins over walkie) are race-free
    /// even when a peer audio packet arrives during the radio start/end window.
    private var radioIntent: Bool = false
    private var walkieIntent: Bool = false

    private var observerTokens: [NSObjectProtocol] = []

    private init() {}

    /// Activities-enabled check (user toggle in iOS Settings → app).
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Appends work to the lifecycle chain. Use `enqueue` for any code that mutates
    /// an Activity (request/update/end) so ops run in the order they were scheduled
    /// on the MainActor.
    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let prev = pendingLifecycle
        pendingLifecycle = Task { @MainActor in
            await prev?.value
            await work()
        }
    }

    /// Wires the NotificationCenter observers for interactive intent broadcasts
    /// (iOS 17+) and reconciles in-flight activities with the current app state.
    /// Idempotent — safe to call from AppDelegate as well as scene `.task`.
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        Logger.shared.logInfo("LiveActivityManager bootstrap")

        // End ALL stale in-flight activities from a previous process. At cold launch
        // neither RadioManager nor MultipeerManager has any active session yet, so
        // any LA the OS still has on screen is by definition orphaned and would
        // otherwise stay visible with broken (no-op) intent buttons. Iterating —
        // not `.first` — also covers the edge case where ActivityKit delivered
        // duplicates after a process crash + relaunch.
        enqueue { [weak self] in
            for activity in Activity<RadioActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            for activity in Activity<WalkieActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            self?.radioActivity = nil
            self?.walkieActivity = nil
        }

        // Observe interactive intent broadcasts. These come from
        // LiveActivityIntent.perform() in the widget UI on iOS 17+.
        // Registering BEFORE the scene processes any deep-link URL is critical:
        // a cold launch from a talky:// URL must find observers ready.
        let t1 = NotificationCenter.default.addObserver(
            forName: .talkyRadioTogglePlayPause,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in Self.handleRadioTogglePlayPause() }
        }
        let t2 = NotificationCenter.default.addObserver(
            forName: .talkyRadioNextStation,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in Self.handleRadioNext() }
        }
        let t3 = NotificationCenter.default.addObserver(
            forName: .talkyRadioPreviousStation,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in Self.handleRadioPrevious() }
        }
        observerTokens = [t1, t2, t3]
    }

    // MARK: - Radio

    func startRadio(stationName: String, country: String, flag: String, frequency: String, genre: String, isPlaying: Bool, isBuffering: Bool) {
        guard areActivitiesEnabled else {
            Logger.shared.logInfo("Live Activities disabled by user, skip startRadio")
            return
        }
        // Synchronous intent: protects against a walkie sync racing in between the
        // end-walkie and Activity.request below.
        radioIntent = true
        walkieIntent = false
        enqueue { [weak self] in
            guard let self = self else { return }
            if let existing = self.radioActivity {
                self.radioActivity = nil
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            if let walkie = self.walkieActivity {
                self.walkieActivity = nil
                await walkie.end(nil, dismissalPolicy: .immediate)
            }
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
                self.radioActivity = try Activity.request(
                    attributes: RadioActivityAttributes(),
                    content: content,
                    pushType: nil
                )
                Logger.shared.logAudioInfo("Live Activity Radio started: \(stationName)")
            } catch {
                Logger.shared.logAudioError(error, context: "Live Activity Radio start")
            }
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
        enqueue { [weak self] in
            guard let self = self, let activity = self.radioActivity else { return }
            let state = RadioActivityAttributes.ContentState(
                stationName: stationName,
                stationCountry: country,
                stationFlag: flag,
                stationFrequency: frequency,
                stationGenre: genre,
                isPlaying: isPlaying,
                isBuffering: isBuffering
            )
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func endRadio() {
        radioIntent = false
        enqueue { [weak self] in
            guard let self = self, let activity = self.radioActivity else { return }
            self.radioActivity = nil
            await activity.end(nil, dismissalPolicy: .immediate)
            Logger.shared.logAudioInfo("Live Activity Radio ended")
        }
    }

    // MARK: - Walkie

    func startWalkie(connectedPeerCount: Int, peerNames: [String], channelName: String) {
        guard areActivitiesEnabled else { return }
        walkieIntent = true
        enqueue { [weak self] in
            guard let self = self else { return }
            if let existing = self.walkieActivity {
                self.walkieActivity = nil
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            // Defensive — if radio is concurrently being started, the radioIntent
            // flag is true and we yield. Otherwise tear down any orphan radio LA
            // so the two icons don't overlap on the Dynamic Island.
            if self.radioIntent {
                self.walkieIntent = false
                return
            }
            if let radio = self.radioActivity {
                self.radioActivity = nil
                await radio.end(nil, dismissalPolicy: .immediate)
            }
            let state = WalkieActivityAttributes.ContentState(
                connectedPeerCount: connectedPeerCount,
                peerNames: Array(peerNames.prefix(3)),
                channelName: channelName,
                talkerName: nil
            )
            let content = ActivityContent(state: state, staleDate: nil)
            do {
                self.walkieActivity = try Activity.request(
                    attributes: WalkieActivityAttributes(),
                    content: content,
                    pushType: nil
                )
                Logger.shared.logNetworkInfo("Live Activity Walkie started: \(connectedPeerCount) peer(s)")
            } catch {
                Logger.shared.logNetworkError(error, context: "Live Activity Walkie start")
            }
        }
    }

    /// Convenience for the walkie side — start if no activity, update otherwise.
    /// **Precedence rule:** if a radio Live Activity is currently visible OR is
    /// being requested, walkie updates are silently ignored. We check the
    /// synchronous `radioIntent` flag rather than only the ivar because the ivar
    /// is nil-ed inside the serialized lifecycle Task before `Activity.request`
    /// returns — without the flag, walkie can sneak in during that window.
    func startOrUpdateWalkie(connectedPeerCount: Int, peerNames: [String], channelName: String, talkerName: String?) {
        if radioIntent || radioActivity != nil {
            if walkieActivity != nil { endWalkie() }
            return
        }
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
        enqueue { [weak self] in
            guard let self = self, let activity = self.walkieActivity else { return }
            let state = WalkieActivityAttributes.ContentState(
                connectedPeerCount: connectedPeerCount,
                peerNames: Array(peerNames.prefix(3)),
                channelName: channelName,
                talkerName: talkerName
            )
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func endWalkie() {
        walkieIntent = false
        enqueue { [weak self] in
            guard let self = self, let activity = self.walkieActivity else { return }
            self.walkieActivity = nil
            await activity.end(nil, dismissalPolicy: .immediate)
            Logger.shared.logNetworkInfo("Live Activity Walkie ended")
        }
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
    /// When `currentStation` isn't in favorites (or is nil), we wrap from the
    /// "before the list" position → last favorite. Consistent with Next which
    /// treats the same situation as wrapping forward → first favorite.
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

@available(iOS 16.2, *)
extension LiveActivityManager {
    /// Public entry point: re-sync walkie LA from current MultipeerManager state.
    /// Called after the radio is stopped so a still-connected walkie session can
    /// reclaim the Dynamic Island.
    func resyncWalkieFromCurrentState() {
        guard let mp = MultipeerManager.shared else { return }
        if mp.connectedPeers.isEmpty {
            endWalkie()
            return
        }
        let names = mp.connectedPeers.map { $0.displayName }
        startOrUpdateWalkie(
            connectedPeerCount: mp.connectedPeers.count,
            peerNames: names,
            channelName: mp.liveActivityChannelDisplayNamePublic,
            talkerName: mp.currentTalkerName
        )
    }
}
