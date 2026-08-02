# Android Reliability and Background Operation Design

## Scope

This design applies only to the open-source Android port in `Android/`. It fixes the reported radio, permission, lifecycle, TALKY1 encoding, and channel-isolation defects while preserving the existing AdMob banner, Firebase integrations, application ID, signing configuration, and APK update path. No iOS or macOS production files are changed.

The Android application continues to ship source code publicly. No signing credentials, production ad secrets, or other private configuration may be added to tracked files. The existing AdMob and Firebase SDKs remain the only proprietary runtime integrations affected by this work; their initialization stays in the activity/application layer and no Android service retains an `Activity` reference.

## Goals

- Play catalogued HTTP radio streams on Android 9 through Android 16 without enabling cleartext for unrelated hosts.
- Continue walkie discovery, connections, incoming audio, and radio playback while the app is backgrounded or the screen is off.
- Keep a user-visible foreground-service notification with a stop action for as long as background operation is active.
- Allow receive-only walkie operation when microphone permission is denied, and reject PTT safely without throwing an uncaught exception.
- Encode TALKY1 fields with RFC 3986 percent encoding so spaces arrive as spaces on Apple platforms.
- Discover, connect, and exchange audio only with peers on the current channel.
- Retain wire compatibility: `_walkie-talkie._tcp.`, framed UInt32 big-endian payloads, TALKY1 text messages, and PCM16LE 48 kHz mono audio do not change.
- Audit all 343 Android radio entries and replace demonstrably dead URLs when a verified replacement is available.
- Keep AdMob visible in the Android UI and preserve existing Firebase analytics events.

## Non-goals

- Changing iOS or macOS behavior or source files.
- Adding accounts, cloud relay, remote push-to-talk, boot-time startup, or a Play Store release workflow.
- Guaranteeing permanent availability of third-party radio servers. External outages, geoblocking, and future URL changes remain possible and must produce a recoverable UI error.
- Moving signing credentials into Git or changing the version/signing identity as part of the reliability fixes.

## Chosen Architecture

### Foreground service ownership

Add one started-and-bound `TalkyForegroundService`. It is the sole owner of `CrossPlatformWalkieManager` and `RadioManager`. `MainActivity` binds to the service and renders service-owned observable state; Compose no longer constructs or closes either manager.

The service is started only from the visible activity. It enters the foreground immediately and remains alive across configuration changes, backgrounding, and screen-off. Its manifest declaration supports `connectedDevice`, `mediaPlayback`, and `microphone` service types. The active foreground type is:

- `connectedDevice | mediaPlayback` while receiving peers or making radio playback available;
- `connectedDevice | mediaPlayback | microphone` only while PTT capture is active and `RECORD_AUDIO` is granted.

The notification channel is low importance but persistent. The notification reports the current channel or playing station and exposes an explicit stop action. Stopping terminates PTT, radio, NSD, sockets, playback, and the service. Reopening the app can start a fresh service. The service is not started from `BOOT_COMPLETED`.

The service owns only application-scoped objects. AdMob consent and banner rendering remain in `MainActivity`; the service neither initializes ads nor stores an activity/context that could leak the UI.

### Activity binding and state

The service exposes a local Binder API for these commands:

- start/restart walkie networking;
- change channel;
- start and stop PTT;
- play and stop a radio station;
- stop all background operation.

It also exposes an immutable snapshot/state stream containing walkie status, current channel, peer list, event list, transmit/receive flags, radio status, and the latest user-facing permission or audio error. The activity collects this state while started. A temporary unbind does not stop the service.

Switching to radio stops an active transmission; switching to walkie stops radio playback, preserving current product behavior. Backgrounding alone does neither.

## Permission and Failure Model

Permission decisions are separated into a small, pure policy component so they can be unit-tested without Android framework objects.

- Nearby/network permission allows NSD and receive-only walkie startup.
- Microphone permission gates only PTT capture.
- Notification permission is requested on Android 13+, but denial does not trigger microphone or network work and is surfaced clearly to the user.
- A denied microphone never calls `AudioManager.startCapturing()`.
- `AudioManager` and the transmission coroutine catch `SecurityException`, initialization failure, and recorder failures, clean up their state, and publish a recoverable failure result.
- PTT returns a typed result (`Started`, `NoPeer`, `PermissionDenied`, or `AudioFailure`) rather than reporting success before audio capture is viable.
- Repeated permission requests occur only after an explicit user action; permanent denial directs the user to app settings.

Receive-only operation remains available without microphone permission. This avoids coupling network availability to recording permission and eliminates the reported denial crash path.

## Radio Network Security and Playback

Add `res/xml/network_security_config.xml` and reference it from the application manifest. Its base policy denies cleartext. Domain entries permit cleartext only for hosts used by `http://` URLs in the compiled Android station catalog, including literal IP hosts where present. HTTPS remains the default for every other destination.

A regression test compares the catalog's HTTP hosts with the allowlist so adding a future HTTP station without updating the policy fails the test. The test also rejects a global `cleartextTrafficPermitted="true"` base policy.

The audit checks every Android station URL with bounded timeouts and redirect following. Dead URLs are replaced only with verified broadcaster or stream-provider endpoints. Where a reliable replacement cannot be verified, the entry stays identifiable and playback reports a concise error rather than hanging or crashing. Audit results are recorded in the implementation handoff; live network health is not asserted by the offline unit suite.

`RadioManager` remains service-owned, cleans up failed players, resets buffering/error state between stations, and updates the foreground notification once playback starts or fails.

## TALKY1 Interoperability

Replace Java form encoding with UTF-8 RFC 3986 encoding. Only ASCII alphanumerics and `-._~` pass unescaped; spaces encode as `%20`, plus signs as `%2B`, and delimiters such as `|` and `=` remain escaped. Decoding percent escapes does not translate literal `+` into a space. Unit vectors cover Apple-compatible names such as `Google Pixel 10 Pro`, literal plus signs, Unicode, and delimiters.

Channel isolation is enforced at every Android boundary:

1. Ignore resolved Bonjour/TXT peers whose channel differs from `currentChannel`.
2. Refuse outgoing connection attempts to a mismatched peer.
3. Validate the received HELLO channel on both incoming and outgoing handshakes before storing a connection.
4. Reject a mid-connection HELLO that changes to a different channel.
5. On channel change, stop transmission, disconnect existing peers, clear stale discovery state, republish TXT data, and restart discovery.
6. Broadcast audio only to connections whose validated peer channel still equals the current channel.

The public channel remains `public`; Android's existing `ch1` through `ch8` identifiers remain unchanged. The TALKY1 frame and audio formats remain unchanged.

## Android Manifest and Notification Requirements

The manifest adds the base foreground-service permission plus the `CONNECTED_DEVICE`, `MEDIA_PLAYBACK`, and `MICROPHONE` type permissions. The service is non-exported and declares all three service types. Existing microphone, internet, Wi-Fi, nearby-device, notification, Ad ID, launcher activity, AdMob application ID, backup, icon, and theme declarations remain intact.

Notification creation precedes long-running manager startup so the service satisfies the foreground-start deadline. All notification PendingIntents are explicit and use immutable/update flags appropriate to their purpose.

## Testing Strategy

Work follows RED-GREEN-REFACTOR with one behavior per regression test.

- Protocol unit tests: RFC 3986 encoding/decoding and Apple-compatible vectors.
- Channel-policy unit tests: TXT mismatch, incoming HELLO mismatch, outgoing HELLO mismatch, channel-change cleanup, and matching-channel acceptance.
- Permission-policy unit tests: denied microphone permits receive-only startup but blocks PTT; granted microphone permits PTT; missing network permission blocks NSD safely.
- Transmission tests around an injectable audio-capture boundary: recorder failures become typed errors and always reset transmitting state.
- Radio-policy unit tests: every HTTP catalog host is explicitly allowlisted and the base policy is not globally cleartext.
- Service/manifest verification: merged manifest contains a non-exported foreground service and the required permissions/types.
- Existing TALKY1 tests remain green.
- Full `testDebugUnitTest`, debug APK build, release APK build, lint, and APK signing verification run with constrained Gradle workers because of current machine load.
- Device/emulator smoke checks cover service notification, Home/screen-off persistence, radio background playback, denied-microphone PTT, matching/mismatching channels, and notification stop. True peer audio remains a physical multi-device verification item.

## Success Criteria

- No catalogued HTTP URL is blocked by Android cleartext policy.
- Denying microphone cannot start capture or crash the app; receiving remains available when network permission is present.
- Radio playback and walkie receive remain active after Home and screen-off while the persistent notification is present.
- Stopping from the notification releases all service resources.
- Apple peers display Android device names with spaces and literal plus signs correctly.
- Android neither lists as connected nor exchanges audio with a peer on a different channel.
- AdMob banner and consent initialization still compile and remain present in the Android activity UI.
- No iOS/macOS source, application ID, signing key, or tracked secret is changed.
