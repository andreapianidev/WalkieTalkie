//
//  RadioActivityWidget.swift
//  TalkyLiveActivities
//
//  Live Activity / Dynamic Island presentation for the radio mode.
//  States: minimal · compact leading/trailing · expanded · lock-screen banner.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 16.2, *)
struct RadioActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RadioActivityAttributes.self) { context in
            RadioLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.65))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RadioLeadingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RadioTrailingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    RadioCenterView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RadioControlsView(state: context.state)
                }
            } compactLeading: {
                Text(context.state.stationFlag)
                    .font(.system(size: 14))
            } compactTrailing: {
                if context.state.isBuffering {
                    ProgressView()
                        .tint(.orange)
                        .scaleEffect(0.7)
                } else {
                    Text(context.state.stationName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .frame(maxWidth: 80)
                }
            } minimal: {
                ZStack {
                    Image(systemName: "radio.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(context.state.isPlaying ? Color.orange : Color.gray)
                    if context.state.isPlaying {
                        Circle()
                            .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                            .frame(width: 18, height: 18)
                    }
                }
            }
            .widgetURL(URL(string: "talky://radio"))
            .keylineTint(.orange)
        }
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
private struct RadioLockScreenView: View {
    let state: RadioActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            // Artwork placeholder — gradient disk that vibes "radio".
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.orange, Color.red.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "radio.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .shadow(color: .orange.opacity(0.4), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(state.stationFlag).font(.system(size: 16))
                    Text(state.stationName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text("\(state.stationCountry) · \(state.stationFrequency)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            RadioControlsView(state: state, compact: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Expanded regions

@available(iOS 16.2, *)
private struct RadioLeadingView: View {
    let state: RadioActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.orange, Color.red.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "radio.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            Text(state.stationFlag)
                .font(.system(size: 18))
        }
    }
}

@available(iOS 16.2, *)
private struct RadioTrailingView: View {
    let state: RadioActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if state.isBuffering {
                ProgressView()
                    .tint(.orange)
            } else {
                Image(systemName: state.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(state.isPlaying ? Color.orange : Color.gray)
            }
            Text(state.stationGenre.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

@available(iOS 16.2, *)
private struct RadioCenterView: View {
    let state: RadioActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.stationName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(state.stationCountry) · \(state.stationFrequency)")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Controls (skip prev / play-pause / skip next)

@available(iOS 16.2, *)
private struct RadioControlsView: View {
    let state: RadioActivityAttributes.ContentState
    var compact: Bool = false

    private var size: CGFloat { compact ? 22 : 26 }
    private var padding: CGFloat { compact ? 6 : 10 }

    var body: some View {
        HStack(spacing: compact ? 4 : 10) {
            prevButton
            playPauseButton
            nextButton
        }
    }

    private var prevButton: some View {
        let label = ControlButtonLabel(symbol: "backward.fill", size: size, padding: padding, emphasized: false)
        return AnyView(
            Group {
                if #available(iOS 17.0, *) {
                    Button(intent: SkipPreviousStationIntent()) { label }
                        .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "talky://radio/prev")!) { label }
                }
            }
            .accessibilityLabel("Previous favorite station")
        )
    }

    private var playPauseButton: some View {
        let symbol = state.isPlaying ? "pause.fill" : "play.fill"
        let label = ControlButtonLabel(symbol: symbol, size: size, padding: padding, emphasized: true)
        return AnyView(
            Group {
                if #available(iOS 17.0, *) {
                    Button(intent: PlayPauseRadioIntent()) { label }
                        .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "talky://radio/playpause")!) { label }
                }
            }
            .accessibilityLabel(state.isPlaying ? "Pause" : "Play")
        )
    }

    private var nextButton: some View {
        let label = ControlButtonLabel(symbol: "forward.fill", size: size, padding: padding, emphasized: false)
        return AnyView(
            Group {
                if #available(iOS 17.0, *) {
                    Button(intent: SkipNextStationIntent()) { label }
                        .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "talky://radio/next")!) { label }
                }
            }
            .accessibilityLabel("Next favorite station")
        )
    }
}

@available(iOS 16.2, *)
private struct ControlButtonLabel: View {
    let symbol: String
    let size: CGFloat
    let padding: CGFloat
    let emphasized: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .bold))
            .foregroundStyle(emphasized ? Color.white : Color.orange)
            .frame(width: size + padding, height: size + padding)
            .background(
                Circle().fill(emphasized
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.orange, Color.red.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    : AnyShapeStyle(Color.white.opacity(0.14))
                )
            )
    }
}
