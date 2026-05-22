# Talky — Dynamic Island & Live Activities Design

**Date:** 2026-05-22
**Author:** Andrea Piani (with Claude)
**Status:** Approved (verbal — "fai tutto tu")

## Goal

When the user backgrounds Talky with the radio playing or the walkie-talkie session active, surface the state via iOS Dynamic Island + Lock Screen Live Activity. Already present today: `MPNowPlayingInfoCenter` for radio (lock-screen Now Playing tile). Missing: rich Live Activity / Dynamic Island treatment.

## Scope

- **Radio Live Activity** — active whenever a station is playing.
- **Walkie Live Activity** — active whenever at least one peer is connected.
- Mutually exclusive (already enforced by app's mode toggle).
- Pro gating: **none**. Both LAs are free-tier features.

## iOS gating

- App min target stays at **iOS 15.6**. No existing user is broken.
- All Live Activity code gated behind `@available(iOS 16.1, *)`.
- Interactive buttons (App Intents from LA) gated at **iOS 17+**; on iOS 16.1–16.x the same buttons exist but tap opens the app via deep link.
- Widget Extension target deployment: **iOS 16.1**.

## Architecture

### Targets

1. **WalkieTalkie** (existing app target) — adds `LiveActivityManager`, hooks in `RadioManager` / `MultipeerManager`, deep-link handler.
2. **TalkyLiveActivities** (new Widget Extension) — `WidgetBundle` containing `RadioActivityWidget` + `WalkieActivityWidget`.

### Shared code

`Shared/` folder at project root, traditional file references, added to **both** targets' Sources build phase:

- `LiveActivityAttributes.swift` — defines `RadioActivityAttributes` and `WalkieActivityAttributes` (Codable, Hashable, conform to `ActivityAttributes`).

### App target additions

`WalkieTalkie/LiveActivity/` (auto-included via existing sync group):

- `LiveActivityManager.swift` — singleton orchestrator. Methods: `startRadio(station:)`, `updateRadio(station:isPlaying:)`, `endRadio()`, `startWalkie(...)`, `updateWalkie(...)`, `endWalkie()`. Internal availability checks (`ActivityAuthorizationInfo`).
- `RadioActivityIntents.swift` — `PlayPauseRadioIntent`, `SkipNextStationIntent`, `SkipPreviousStationIntent` conforming to `LiveActivityIntent` (iOS 17+). Each performs its action against `RadioManager.shared`.
- `LiveActivityDeepLinkHandler.swift` — parses `talky://radio/<action>` URLs for iOS 16.x fallback.

### Widget Extension target

`TalkyLiveActivities/` (new sync group, owned by widget target):

- `TalkyLiveActivitiesBundle.swift` — `@main` WidgetBundle.
- `RadioActivityWidget.swift` — `ActivityConfiguration<RadioActivityAttributes>` with all states (minimal, compact leading/trailing, expanded regions, lock-screen).
- `WalkieActivityWidget.swift` — same for walkie.
- `Info.plist` — minimal, with `NSExtension` and `NSSupportsLiveActivities = YES`.

## Data Models

### `RadioActivityAttributes`

```swift
struct RadioActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stationName: String
        var stationCountry: String       // "Italia"
        var stationFlag: String          // "🇮🇹"
        var stationFrequency: String     // "102.5" or "—"
        var stationGenre: String         // "Pop"
        var isPlaying: Bool
        var isBuffering: Bool
    }
    // Static: nothing for now (could carry brand color later)
}
```

### `WalkieActivityAttributes`

```swift
struct WalkieActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var connectedPeerCount: Int
        var peerNames: [String]          // first 3
        var channelName: String          // "Pubblico" or private channel label
        var talkerName: String?          // non-nil when receiving audio
    }
}
```

## Dynamic Island layouts

### Radio

- **Minimal:** SF Symbol `radio` with orange pulse when playing, gray when paused/buffering.
- **Compact leading:** flag emoji.
- **Compact trailing:** station name truncated (~12 chars) or play/pause icon if buffering.
- **Expanded (top-leading):** `radio` symbol + flag.
- **Expanded (top-trailing):** play/pause indicator.
- **Expanded (center):** large station name, country • frequency, genre tag.
- **Expanded (bottom):** three buttons — ⏮ prev favorite, ⏯ play/pause, ⏭ next favorite. iOS 17+ interactive via `LiveActivityIntent`; iOS 16.x deep-link to `talky://radio/<action>`.
- **Lock screen banner:** horizontal layout — flag | station + frequency | controls (right side).

### Walkie

- **Minimal:** SF Symbol `antenna.radiowaves.left.and.right` green = connected.
- **Compact leading:** `dot.radiowaves.left.and.right` + peer count.
- **Compact trailing:** channel name shortened (max 8 chars).
- **Expanded (top-leading):** channel name + peer count badge.
- **Expanded (top-trailing):** receiving indicator (red dot) when `talkerName != nil`.
- **Expanded (center):** peer name list (up to 3, "+N altri" if more).
- **Expanded (bottom):** if talkerName != nil → "🔴 <name> sta parlando", else "Tutti in ascolto".
- **Lock screen banner:** larger version of expanded, no buttons.

## Lifecycle

### Radio

- **Start:** end of `RadioManager.playStation` after successful `play()`.
- **Update:** every place that currently updates `MPNowPlayingInfoCenter` (play/pause/station change/buffering state via KVO).
- **End:** in `stopRadio()`. Also auto-stops at iOS-imposed 8h max.

### Walkie

- **Start:** in `session(_:peer:didChange:)` `.connected` branch when `connectedPeers.count == 1` (first peer just joined).
- **Update:** every peer connect/disconnect; flip `talkerName` on `session(_:didReceive:fromPeer:)` (set name, clear after 2s — same timing as `isReceiving`).
- **End:** when `connectedPeers.isEmpty` (already detected in `.notConnected` branch).

## Deep linking & interactivity

- Add **URL scheme** `talky` via Info.plist `CFBundleURLTypes`.
- Routes: `talky://radio/play`, `talky://radio/pause`, `talky://radio/next`, `talky://radio/prev`, `talky://walkie`.
- App handles via `.onOpenURL` on root `WindowGroup` content.
- iOS 17+ App Intents (`LiveActivityIntent`) perform actions directly without deep-linking — they execute in app process and call `RadioManager.shared` methods.

## Skip behavior

When LA button "next" or "prev" is tapped:

```
let pool = !radio.favoriteStations.isEmpty ? radio.favoriteStations : radio.availableStations
// from current, wrap-around
```

Falls back to existing `nextStation()` / `previousStation()` semantics if favorites empty.

## Localization

Strings live in widget target's resource bundle. Add IT/EN/ES/MS keys:

- `live_activity_radio_playing`, `live_activity_radio_paused`, `live_activity_radio_buffering`
- `live_activity_walkie_listening`, `live_activity_walkie_speaking_format` ("%@ sta parlando")
- `live_activity_walkie_channel_public`

## Permissions / Privacy

- Live Activities themselves require no runtime permission (user toggles in iOS Settings → app).
- `NSSupportsLiveActivities = YES` in app Info.plist (auto-prompts no permission — only declares capability).

## Risks & mitigations

- **Xcode project corruption:** all `.pbxproj` edits done via `xcodeproj` Ruby gem (v1.27.0 confirmed available). Backup of `project.pbxproj` made before any write.
- **Widget Extension code signing:** uses automatic signing, inherits team `ERAK83QBBM`. Bundle ID: `com.Andrea-Piani.WalkieTalkie.LiveActivities`.
- **Sandbox issues with `mkdir`/file writes:** if any sandbox refuses path write, fall back to `Bash` with explicit path quoting.
- **iOS 15.6 users:** all new code gated behind `@available(iOS 16.1, *)`. No regression.
- **Background audio for walkie:** unchanged. Live Activity is read-only on walkie side — no PTT button — so no new audio-session edge cases.

## Out of scope

- Push-notification-driven Live Activity updates (ActivityKit push). Local updates only.
- PTT via LA button (technically possible iOS 17+ but unreliable — explicitly rejected during brainstorm).
- Apple Watch complication.
- StandBy / Always-On display tweaks beyond default LA behavior.
