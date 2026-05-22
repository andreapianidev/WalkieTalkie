//
//  LiveActivityAttributes.swift
//  Talky
//
//  Shared between WalkieTalkie app target and TalkyLiveActivities widget extension.
//  Defines the ActivityAttributes for the radio and walkie Dynamic Island / Lock Screen
//  Live Activities. Gated to iOS 16.2+ (the minimum on which we ship Live Activities).
//

import Foundation
import ActivityKit

@available(iOS 16.2, *)
public struct RadioActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var stationName: String
        public var stationCountry: String
        public var stationFlag: String
        public var stationFrequency: String
        public var stationGenre: String
        public var isPlaying: Bool
        public var isBuffering: Bool

        public init(
            stationName: String,
            stationCountry: String,
            stationFlag: String,
            stationFrequency: String,
            stationGenre: String,
            isPlaying: Bool,
            isBuffering: Bool
        ) {
            self.stationName = stationName
            self.stationCountry = stationCountry
            self.stationFlag = stationFlag
            self.stationFrequency = stationFrequency
            self.stationGenre = stationGenre
            self.isPlaying = isPlaying
            self.isBuffering = isBuffering
        }
    }

    public init() {}
}

@available(iOS 16.2, *)
public struct WalkieActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var connectedPeerCount: Int
        public var peerNames: [String]
        public var channelName: String
        public var talkerName: String?

        public init(
            connectedPeerCount: Int,
            peerNames: [String],
            channelName: String,
            talkerName: String? = nil
        ) {
            self.connectedPeerCount = connectedPeerCount
            self.peerNames = peerNames
            self.channelName = channelName
            self.talkerName = talkerName
        }
    }

    public init() {}
}
