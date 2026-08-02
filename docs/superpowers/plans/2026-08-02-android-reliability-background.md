# Android Reliability and Background Operation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Android app's radio and TALKY1 walkie reliable, channel-isolated, and foreground-service-backed while preserving the open-source distribution, AdMob, Firebase, signing identity, and Apple wire compatibility.

**Architecture:** A started-and-bound `TalkyForegroundService` becomes the sole owner of `CrossPlatformWalkieManager` and `RadioManager`; Compose binds to that service instead of constructing managers. Pure protocol, channel, permission, and foreground-type policies carry regression coverage, while Android-specific service/manifest integration is verified by compilation, lint, and merged-manifest inspection.

**Tech Stack:** Kotlin 2.2, Android API 30–36, Jetpack Compose, Android Services/Notifications, NSD, AV media APIs, coroutines, JUnit 4, Firebase, AdMob.

## Global Constraints

- Modify production code only under `Android/`; do not modify iOS or macOS production files.
- Keep application ID `com.immaginet.talky.android`, TALKY1 framing/audio constants, and release signing configuration unchanged.
- Preserve AdMob banner/consent and Firebase initialization/events; add no tracked secrets.
- Keep cleartext denied by default and allow it only for HTTP radio catalog hosts.
- Keep Gradle at one worker while the host is under Xcode load.
- Do not claim runtime emulator/device behavior; the user will run final runtime checks.

---

### Task 1: Apple-compatible TALKY1 codec

**Files:**
- Modify: `Android/app/src/main/java/com/immaginet/talky/protocol/TalkyProtocol.kt`
- Modify: `Android/app/src/test/java/com/immaginet/talky/protocol/TalkyProtocolTest.kt`

**Interfaces:**
- Produces: `TalkyProtocol.encodeLine(TalkyMessage): String` and `decodeLine(String): TalkyMessage?` using UTF-8 RFC 3986 encoding.
- Compatibility vectors: space `%20`, plus `%2B`, Unicode UTF-8 percent bytes, `|` `%7C`, `=` `%3D`.

- [ ] **Step 1: Write failing compatibility tests**

```kotlin
@Test fun appleWireEncodingUsesPercent20ForSpaces() {
    val line = TalkyProtocol.encodeLine(TalkyMessage.hello("u", "Google Pixel 10 Pro", "public"))
    assertTrue(line.contains("name=Google%20Pixel%2010%20Pro"))
    assertFalse(line.contains("Google+Pixel"))
}

@Test fun literalPlusRoundTripsWithoutBecomingSpace() {
    val decoded = TalkyProtocol.decodeLine("TALKY1|HELLO|uid=u|name=C%2B%2B%20Phone|channel=public\n")
    assertEquals("C++ Phone", decoded?.fields?.get(TalkyProtocol.Keys.NAME))
}
```

- [ ] **Step 2: Run RED**

Run: `./gradlew testDebugUnitTest --tests '*TalkyProtocolTest' --max-workers=1 --no-daemon --console=plain`

Expected: the space test fails because `URLEncoder` emits `+`.

- [ ] **Step 3: Replace form encoding with a strict UTF-8 codec**

Implement byte-wise encoding that leaves only ASCII `A-Z a-z 0-9 - . _ ~`, emits uppercase `%HH`, and a decoder that parses `%HH` byte runs without treating `+` specially. Remove `URLEncoder`/`URLDecoder` imports.

- [ ] **Step 4: Run GREEN and commit**

Run the Task 1 test command; expect all protocol tests to pass.

Commit: `fix(android): use RFC3986 TALKY1 encoding`

### Task 2: Channel isolation at discovery and handshake

**Files:**
- Create: `Android/app/src/main/java/com/immaginet/talky/protocol/PeerChannelPolicy.kt`
- Create: `Android/app/src/test/java/com/immaginet/talky/protocol/PeerChannelPolicyTest.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/net/CrossPlatformWalkieManager.kt`

**Interfaces:**
- Produces: `PeerChannelPolicy.matches(currentChannel: String, peerChannel: String?): Boolean`.
- `null` peer channels resolve to `TalkyProtocol.DEFAULT_CHANNEL` only for backward compatibility.
- Every stored `PeerConnection.peer.channel` has passed `matches`.

- [ ] **Step 1: Write failing channel-policy tests**

```kotlin
@Test fun matchingChannelsAreAccepted() = assertTrue(PeerChannelPolicy.matches("ch3", "ch3"))
@Test fun mismatchingChannelsAreRejected() = assertFalse(PeerChannelPolicy.matches("ch3", "public"))
@Test fun missingChannelMeansPublicOnly() {
    assertTrue(PeerChannelPolicy.matches("public", null))
    assertFalse(PeerChannelPolicy.matches("ch3", null))
}
```

- [ ] **Step 2: Run RED**

Run: `./gradlew testDebugUnitTest --tests '*PeerChannelPolicyTest' --max-workers=1 --no-daemon --console=plain`

Expected: compilation fails because `PeerChannelPolicy` is absent.

- [ ] **Step 3: Implement the pure policy and apply it at all boundaries**

Use `PeerChannelPolicy.matches(currentChannel, peerChannel)` in resolved TXT records, before outgoing connects, after incoming HELLO parsing, after outgoing HELLO parsing, and when handling later HELLO frames. Close/refuse mismatches and log `Canale incompatibile`. Clear discovered peers and disconnect connections during `setChannel`, and broadcast only to connections matching `currentChannel`.

- [ ] **Step 4: Run GREEN and commit**

Run all unit tests; expect zero failures.

Commit: `fix(android): isolate TALKY1 channels`

### Task 3: Permission-safe audio transmission

**Files:**
- Create: `Android/app/src/main/java/com/immaginet/talky/permissions/WalkiePermissionPolicy.kt`
- Create: `Android/app/src/test/java/com/immaginet/talky/permissions/WalkiePermissionPolicyTest.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/audio/AudioManager.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/net/CrossPlatformWalkieManager.kt`

**Interfaces:**
- Produces: `WalkiePermissionPolicy(microphoneGranted, networkGranted)` with `canReceive` and `canTransmit`.
- Produces: sealed `TransmissionStartResult` values `Started`, `NoPeer`, `PermissionDenied`, `AlreadyTransmitting`.
- `CrossPlatformWalkieManager.startTransmitting()` never starts capture without `RECORD_AUDIO` and never lets capture exceptions escape its supervisor scope.

- [ ] **Step 1: Write failing permission-policy tests**

```kotlin
@Test fun deniedMicrophoneStillAllowsReceive() {
    val policy = WalkiePermissionPolicy(microphoneGranted = false, networkGranted = true)
    assertTrue(policy.canReceive)
    assertFalse(policy.canTransmit)
}

@Test fun deniedNetworkBlocksReceive() {
    assertFalse(WalkiePermissionPolicy(true, false).canReceive)
}
```

- [ ] **Step 2: Run RED**

Run: `./gradlew testDebugUnitTest --tests '*WalkiePermissionPolicyTest' --max-workers=1 --no-daemon --console=plain`

Expected: compilation fails because the policy does not exist.

- [ ] **Step 3: Implement permission and capture defenses**

Add an injectable `hasMicrophonePermission` lambda to `CrossPlatformWalkieManager`, defaulting to `ContextCompat.checkSelfPermission`. Return `PermissionDenied` before launch when false. Wrap `startCapturing().collect` in `try/catch` for `SecurityException`, `IllegalStateException`, and other non-cancellation exceptions; log, reset capture/transmit state, and do not rethrow. Move `AudioRecord.startRecording()` inside cleanup protection and use `runCatching` for stop/release.

- [ ] **Step 4: Run GREEN and commit**

Run all unit tests; expect zero failures.

Commit: `fix(android): handle denied microphone safely`

### Task 4: Domain-scoped radio cleartext policy

**Files:**
- Create: `Android/app/src/main/res/xml/network_security_config.xml`
- Modify: `Android/app/src/main/AndroidManifest.xml`
- Create: `Android/app/src/test/java/com/immaginet/talky/radio/RadioNetworkSecurityTest.kt`

**Interfaces:**
- Manifest references `@xml/network_security_config`.
- Base config explicitly uses `cleartextTrafficPermitted="false"`.
- Each unique host in an Android catalog `http://` URL has an exact cleartext-enabled `<domain>` entry.

- [ ] **Step 1: Write the failing source/resource regression test**

The JUnit test reads `RadioManager.kt`, extracts HTTP URL hosts with `URI`, reads `network_security_config.xml`, and asserts `httpHosts == allowedDomains`. It also asserts the base config is false and the manifest references the resource.

- [ ] **Step 2: Run RED**

Run: `./gradlew testDebugUnitTest --tests '*RadioNetworkSecurityTest' --max-workers=1 --no-daemon --console=plain`

Expected: failure because the resource and manifest reference are absent.

- [ ] **Step 3: Generate the explicit domain config and manifest reference**

Build one sorted `<domain-config cleartextTrafficPermitted="true">` containing every current HTTP catalog host. Do not set `android:usesCleartextTraffic="true"` and do not enable cleartext in the base config.

- [ ] **Step 4: Run GREEN and commit**

Run all unit tests; expect exact host-set equality and zero failures.

Commit: `fix(android): allow cleartext radio hosts`

### Task 5: Unified foreground service and Compose binding

**Files:**
- Create: `Android/app/src/main/java/com/immaginet/talky/service/TalkyForegroundTypePolicy.kt`
- Create: `Android/app/src/test/java/com/immaginet/talky/service/TalkyForegroundTypePolicyTest.kt`
- Create: `Android/app/src/main/java/com/immaginet/talky/service/TalkyForegroundService.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/MainActivity.kt`
- Modify: `Android/app/src/main/AndroidManifest.xml`
- Modify: `Android/app/src/main/res/values/strings.xml`

**Interfaces:**
- `TalkyForegroundService.LocalBinder.service` exposes the local service.
- Service owns `walkieManager` and `radioManager` for its entire lifetime.
- Service commands: `configurePermissions`, `setChannel`, `startTransmitting`, `stopTransmitting`, `playStation`, `stopRadio`, `restartWalkie`, and `stopAll`.
- `TalkyForegroundTypePolicy.types(isTransmitting)` returns connected-device + media-playback, adding microphone only during granted PTT.

- [ ] **Step 1: Write failing foreground-type tests**

```kotlin
@Test fun idleServiceDoesNotClaimMicrophone() {
    assertFalse(TalkyForegroundTypePolicy.types(false) and MICROPHONE != 0)
}

@Test fun transmittingServiceClaimsMicrophone() {
    assertTrue(TalkyForegroundTypePolicy.types(true) and MICROPHONE != 0)
}
```

- [ ] **Step 2: Run RED**

Run: `./gradlew testDebugUnitTest --tests '*TalkyForegroundTypePolicyTest' --max-workers=1 --no-daemon --console=plain`

Expected: compilation fails because the policy is absent.

- [ ] **Step 3: Implement service, manifest, and notification**

Declare `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, and `FOREGROUND_SERVICE_MICROPHONE`; declare a non-exported service with `connectedDevice|mediaPlayback|microphone`. In `onCreate`, create the notification channel, call `ServiceCompat.startForeground` immediately with non-microphone types, then instantiate managers. Handle an explicit stop action in `onStartCommand`. Update the notification for channel, radio status, and PTT. In `onDestroy`, close both managers.

- [ ] **Step 4: Rebind Compose to service ownership**

Start the service from visible `MainActivity`, bind with `BIND_AUTO_CREATE`, and render a short startup state until the Binder arrives. Request runtime permissions and pass their actual map values to `configurePermissions`; never call walkie startup blindly. Keep AdMob/Firebase initialization and `AdBanner()` unchanged. Route UI commands through service methods and unbind without stopping the service.

- [ ] **Step 5: Run GREEN, build, and commit**

Run all unit tests and `./gradlew assembleDebug --max-workers=1 --no-daemon --console=plain`; expect zero failures and a debug APK.

Commit: `feat(android): keep talky active in foreground service`

### Task 6: Radio health fixes, complete verification, and handoff

**Files:**
- Modify: `Android/app/src/main/java/com/immaginet/talky/radio/RadioManager.kt`
- Modify if needed: `Android/README.md`
- Create: `Android/docs/radio-stream-audit-2026-08-02.md`

**Interfaces:**
- Catalog remains 343 entries and preserves stable station IDs.
- Failed playback resets buffering state and releases the player.
- Audit document records status, redirects, and any replacement URL for failed entries.

- [ ] **Step 1: Audit all catalog URLs with bounded network checks**

Extract URLs from `RadioManager.kt`; probe with redirect following, a short connect timeout, and a bounded total timeout. Record HTTP/ICY success, timeout, geoblocking, and failure. Verify replacements from broadcaster or established stream-provider endpoints before editing.

- [ ] **Step 2: Replace verified dead endpoints and harden failure cleanup**

Keep IDs/names/count stable. At minimum investigate the reported RTL2 France, Fun Radio, and `streaming507` entries. Ensure `onError` releases the failing player, sets `isPlayingState=false`, clears buffering, and emits a recoverable error.

- [ ] **Step 3: Run the full fresh verification suite**

Run in order with one worker:

```bash
./gradlew testDebugUnitTest --max-workers=1 --no-daemon --console=plain
./gradlew lintDebug --max-workers=1 --no-daemon --console=plain
./gradlew assembleDebug --max-workers=1 --no-daemon --console=plain
./gradlew assembleRelease --max-workers=1 --no-daemon --console=plain
```

Then inspect the merged release manifest, run `apksigner verify --verbose --print-certs` on the release APK, confirm certificate SHA-256 `36728c012894c90f11596e8a8f8bb781eceb4b4247764e14d4ecde4a3ec90991`, count 343 stations, and confirm `AdBanner()` plus AdMob initialization remain present.

- [ ] **Step 4: Commit and prepare runtime handoff**

Commit: `fix(android): refresh radio streams and finalize reliability`

Report only verified build/test/lint/signing facts. Explicitly list emulator checks for the user: denied microphone, HTTP station playback/logcat, Home/screen-off radio, Home/screen-off walkie receive, same/different channel peers, Apple device-name rendering, and notification stop.
