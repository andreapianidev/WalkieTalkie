//
//  RadioActivityIntents.swift
//  Talky
//
//  AppIntents invoked from interactive Live Activity buttons (iOS 17+).
//  Shared between app and widget targets. The intents do not directly touch
//  RadioManager — they broadcast NotificationCenter events so the file can
//  compile in the widget target which has no RadioManager symbol.
//  LiveActivityManager (in app target) observes these notifications and
//  dispatches to RadioManager.shared.
//

import Foundation
import AppIntents

@available(iOS 17.0, *)
public struct PlayPauseRadioIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Play/Pause"
    public static var description = IntentDescription("Toggle radio playback")

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .talkyRadioTogglePlayPause, object: nil)
        }
        return .result()
    }
}

@available(iOS 17.0, *)
public struct SkipNextStationIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Next Station"
    public static var description = IntentDescription("Skip to next favorite station")

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .talkyRadioNextStation, object: nil)
        }
        return .result()
    }
}

@available(iOS 17.0, *)
public struct SkipPreviousStationIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Previous Station"
    public static var description = IntentDescription("Skip to previous favorite station")

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .talkyRadioPreviousStation, object: nil)
        }
        return .result()
    }
}

public extension Notification.Name {
    static let talkyRadioTogglePlayPause = Notification.Name("com.Andrea-Piani.WalkieTalkie.radio.togglePlayPause")
    static let talkyRadioNextStation = Notification.Name("com.Andrea-Piani.WalkieTalkie.radio.next")
    static let talkyRadioPreviousStation = Notification.Name("com.Andrea-Piani.WalkieTalkie.radio.previous")
}
