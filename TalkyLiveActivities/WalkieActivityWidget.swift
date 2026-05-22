//
//  WalkieActivityWidget.swift
//  TalkyLiveActivities
//
//  Live Activity / Dynamic Island presentation for walkie-talkie connected sessions.
//  Purely informational — no buttons (per design decision; PTT from LA is fragile).
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct WalkieActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkieActivityAttributes.self) { context in
            WalkieLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.65))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WalkieLeadingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WalkieTrailingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    WalkieCenterView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WalkieBottomView(state: context.state)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("\(context.state.connectedPeerCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            } compactTrailing: {
                Text(context.state.channelName.prefix(8).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(context.state.talkerName != nil ? Color.red : Color.green)
                    .lineLimit(1)
            } minimal: {
                ZStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(context.state.talkerName != nil ? Color.red : Color.green)
                    if context.state.talkerName != nil {
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 1.2)
                            .frame(width: 18, height: 18)
                    }
                }
            }
            .widgetURL(URL(string: "talky://walkie"))
            .keylineTint(.green)
        }
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
private struct WalkieLockScreenView: View {
    let state: WalkieActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                .shadow(color: .green.opacity(0.4), radius: 6, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.channelName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(peerSummary)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer()
                ConnectionPill(count: state.connectedPeerCount, talking: state.talkerName != nil)
            }
            if let talker = state.talkerName {
                TalkerBanner(name: talker)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var peerSummary: String {
        if state.peerNames.isEmpty {
            return "\(state.connectedPeerCount) peer"
        }
        let first = state.peerNames.prefix(2).joined(separator: ", ")
        let extra = state.connectedPeerCount - min(2, state.peerNames.count)
        return extra > 0 ? "\(first) +\(extra)" : first
    }
}

// MARK: - Expanded regions

@available(iOS 16.2, *)
private struct WalkieLeadingView: View {
    let state: WalkieActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(state.channelName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(state.connectedPeerCount) peer")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

@available(iOS 16.2, *)
private struct WalkieTrailingView: View {
    let state: WalkieActivityAttributes.ContentState
    var body: some View {
        ConnectionPill(count: state.connectedPeerCount, talking: state.talkerName != nil)
    }
}

@available(iOS 16.2, *)
private struct WalkieCenterView: View {
    let state: WalkieActivityAttributes.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if state.peerNames.isEmpty {
                Text("In ascolto")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(state.peerNames.prefix(3), id: \.self) { name in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green.opacity(state.talkerName == name ? 1.0 : 0.6))
                            .frame(width: 6, height: 6)
                        Text(name)
                            .font(.system(size: 12, weight: state.talkerName == name ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                if state.connectedPeerCount > state.peerNames.count {
                    Text("+\(state.connectedPeerCount - state.peerNames.count) altri")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 16.2, *)
private struct WalkieBottomView: View {
    let state: WalkieActivityAttributes.ContentState
    var body: some View {
        if let talker = state.talkerName {
            TalkerBanner(name: talker)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "ear")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                Text("Tutti in ascolto")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Helpers

@available(iOS 16.2, *)
private struct ConnectionPill: View {
    let count: Int
    let talking: Bool
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(talking ? Color.red : Color.green)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.white.opacity(0.14))
        )
    }
}

@available(iOS 16.2, *)
private struct TalkerBanner: View {
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            Group {
                if #available(iOS 17.0, *) {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative, isActive: true)
                } else {
                    Image(systemName: "waveform")
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.red)
            Text("\(name) sta parlando")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.red.opacity(0.25))
        )
    }
}
