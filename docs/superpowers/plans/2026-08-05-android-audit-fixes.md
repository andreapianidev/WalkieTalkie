# Android Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the actionable Android reliability, privacy, power, radio, advertising, and Apple-interoperability defects found in the 2026-08-04 audit.

**Architecture:** Keep `TalkyForegroundService` as the lifecycle owner while extracting JVM-testable policies for frame writing, receive state, ad gating, radio state, reconnect behavior, and password-derived channel IDs. Android framework wiring remains in the existing managers; TCP writes become per-peer serialized, incoming audio becomes explicitly delimited with an inactivity fallback, and foreground-service types reflect current activity.

**Tech Stack:** Kotlin 2.2, Android API 30–36, Jetpack Compose, coroutines, NSD, `AudioRecord`/`AudioTrack`, `MediaPlayer`, Google Mobile Ads/UMP, JUnit 4.

## Global Constraints

- Modify Android production code only; iOS and macOS production files remain unchanged.
- Preserve TALKY1 compatibility with peers that do not yet send `AUDIO_END` by retaining a receive inactivity timeout.
- Keep test AdMob IDs and placeholder Firebase configuration for the source/sideload build; no production credentials are invented or committed.
- Do not label a password-derived channel as encrypted: TALKY1 remains plaintext on the local network.
- Every behavioral change follows RED → GREEN and the complete Android verification suite runs at the end.

---

### Task 1: Serialize TALKY1 Frames Per Peer

**Files:**
- Create: `Android/app/src/main/java/com/immaginet/talky/protocol/TalkyFrameWriter.kt`
- Create: `Android/app/src/test/java/com/immaginet/talky/protocol/TalkyFrameWriterTest.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/net/CrossPlatformWalkieManager.kt`

**Interfaces:**
- Produces: `TalkyFrameWriter(output: DataOutputStream)` and thread-safe `write(payload: ByteArray)`.
- Consumes: the existing four-byte big-endian TALKY1 length prefix.

- [ ] **Step 1: Write the failing frame-writer tests**

```kotlin
@Test fun `concurrent writes remain complete parseable frames`()
@Test fun `writer rejects an empty payload and payloads over one megabyte`()
```

- [ ] **Step 2: Run `./gradlew testDebugUnitTest --tests '*TalkyFrameWriterTest'` and confirm RED**
- [ ] **Step 3: Implement a per-instance lock around header, payload, and flush; replace every connection write with that writer**
- [ ] **Step 4: Re-run the focused test and the protocol suite and confirm GREEN**

### Task 2: End Receive Sessions and Enforce Half Duplex

**Files:**
- Modify: `Android/app/src/main/java/com/immaginet/talky/protocol/TalkyProtocol.kt`
- Create: `Android/app/src/main/java/com/immaginet/talky/audio/RemoteAudioPolicy.kt`
- Create: `Android/app/src/test/java/com/immaginet/talky/audio/RemoteAudioPolicyTest.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/net/CrossPlatformWalkieManager.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/MainActivity.kt`
- Modify: `Android/app/src/test/java/com/immaginet/talky/protocol/TalkyProtocolTest.kt`

**Interfaces:**
- Produces: `TalkyMessageType.AUDIO_END`, `TalkyMessage.audioEnd()`, and `RemoteAudioPolicy` with a bounded inactivity timeout.
- Produces: `TransmissionStartResult.Receiving` when PTT is attempted during receive.

- [ ] **Step 1: Add failing tests for `AUDIO_END`, inactivity expiry, and the receive-side transmission gate**
- [ ] **Step 2: Run focused tests and confirm failures are caused by the missing behavior**
- [ ] **Step 3: Send `AUDIO_END` in the capture coroutine's `finally`, stop playback on receipt, and reset a fallback timeout after each legacy peer frame**
- [ ] **Step 4: Remove blocking playback from `channelLock`; serialize playback with a coroutine mutex and disable PTT while receiving**
- [ ] **Step 5: Re-run audio/protocol tests and confirm GREEN**

### Task 3: Gate Ads on UMP Consent and Repair Full-Screen Callbacks

**Files:**
- Create: `Android/app/src/main/java/com/immaginet/talky/ads/AdsRequestGate.kt`
- Create: `Android/app/src/test/java/com/immaginet/talky/ads/AdsRequestGateTest.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/ads/AdManager.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/ads/AdBanner.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/MainActivity.kt`

**Interfaces:**
- Produces: `AdManager.gatherConsentAndInitialize(activity)` and observable `canRequestAds` / `privacyOptionsRequired` state.
- Produces: `showInterstitial(activity, onDismissed)`; callbacks complete on dismissal or failure.

- [ ] **Step 1: Add failing state-machine tests proving ads remain blocked before consent and initialize once after `canRequestAds == true`**
- [ ] **Step 2: Run the focused test and confirm RED**
- [ ] **Step 3: Request consent on launch, use `loadAndShowConsentFormIfRequired`, initialize/load ads only through the gate, and expose the required privacy-options button**
- [ ] **Step 4: Require a real `Activity` for interstitial display and complete rewarded callbacks when dismissed without reward**
- [ ] **Step 5: Re-run ads tests and compile Debug**

### Task 4: Bound Wake Locks and Foreground-Service Types

**Files:**
- Modify: `Android/app/src/main/java/com/immaginet/talky/service/TalkyWakeLockPolicy.kt`
- Modify: `Android/app/src/test/java/com/immaginet/talky/service/TalkyWakeLockPolicyTest.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/service/TalkyForegroundTypePolicy.kt`
- Modify: `Android/app/src/test/java/com/immaginet/talky/service/TalkyForegroundTypePolicyTest.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/service/TalkyForegroundService.kt`

**Interfaces:**
- Produces: `TalkyWakeLockPolicy.shouldHold(isTransmitting)`.
- Produces: `TalkyForegroundTypePolicy.types(isTransmitting, isRadioActive)` with `mediaPlayback` only during radio playback/buffering.

- [ ] **Step 1: Change policy expectations first so idle discovery and radio playback do not request a manual CPU lock, and idle service type is only `connectedDevice`**
- [ ] **Step 2: Run both focused policy suites and confirm RED**
- [ ] **Step 3: Update service policy calls and preserve a bounded lock only while actively capturing the microphone**
- [ ] **Step 4: Re-run service tests and compile Debug**

### Task 5: Correct Radio State and Audio Focus

**Files:**
- Create: `Android/app/src/main/java/com/immaginet/talky/radio/RadioPlaybackState.kt`
- Create: `Android/app/src/test/java/com/immaginet/talky/radio/RadioPlaybackStateTest.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/radio/RadioManager.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/service/TalkyForegroundService.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/MainActivity.kt`

**Interfaces:**
- Produces: pure state transitions `buffering(station)`, `playing(station)`, `stopped()`, and `failed(message)`.
- `RadioManager` consumes an application `Context` and owns/abandons its `AudioFocusRequest`.

- [ ] **Step 1: Add failing tests proving Stop clears buffering/station/error state and an error cannot leave playback active**
- [ ] **Step 2: Run the focused test and confirm RED**
- [ ] **Step 3: Route MediaPlayer callbacks through the state object, add completion handling, request/abandon audio focus, and surface Stop while buffering**
- [ ] **Step 4: Re-run radio tests and compile Debug**

### Task 6: Repair NSD Lifecycle and Password-Channel Interoperability

**Files:**
- Create: `Android/app/src/main/java/com/immaginet/talky/protocol/PrivateChannelId.kt`
- Create: `Android/app/src/test/java/com/immaginet/talky/protocol/PrivateChannelIdTest.kt`
- Create: `Android/app/src/main/java/com/immaginet/talky/net/PeerLifecyclePolicy.kt`
- Create: `Android/app/src/test/java/com/immaginet/talky/net/PeerLifecyclePolicyTest.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/net/CrossPlatformWalkieManager.kt`
- Modify: `Android/app/src/main/java/com/immaginet/talky/MainActivity.kt`

**Interfaces:**
- Produces: `PrivateChannelId.fromPassword(password): String`, matching Apple's lowercase SHA-256 16-character prefix.
- Adds stable `serviceName` identity to `CrossPlatformPeer` and bounded reconnect delay decisions in `PeerLifecyclePolicy`.

- [ ] **Step 1: Add failing literal-vector tests for Apple-compatible channel IDs and peer-removal/reconnect decisions**
- [ ] **Step 2: Run focused tests and confirm RED**
- [ ] **Step 3: Remove lost peers by NSD service identity, retain resolvable peers across socket drops, and retry with bounded delay**
- [ ] **Step 4: Use API-34 service-info callbacks with the legacy resolver only on older devices**
- [ ] **Step 5: Add a private-channel password dialog with a plaintext/local-network disclosure and route its derived ID through `setChannel`**
- [ ] **Step 6: Re-run protocol/network tests and compile Debug**

### Task 7: Full Verification

**Files:**
- Verify: `Android/app/build/reports/tests/testDebugUnitTest/index.html`
- Verify: `Android/app/build/reports/lint-results-debug.html`
- Verify: `Android/app/build/outputs/apk/release/app-release.apk`

- [ ] **Step 1: Run `./gradlew testDebugUnitTest lintDebug assembleDebug assembleRelease --rerun-tasks --console=plain`**
- [ ] **Step 2: Confirm test totals contain zero failures/errors and inspect all lint findings**
- [ ] **Step 3: Verify the Release APK signature with `apksigner verify --verbose`**
- [ ] **Step 4: Inspect `git diff --check`, the Android-only diff, and confirm no iOS/macOS production files changed**

## Explicitly Unchanged External Requirements

- The source/sideload Release continues using test AdMob IDs until real account IDs are supplied.
- Firebase remains disabled by its placeholder `google-services.json` until a real project configuration is supplied.
- TALKY1 payload encryption/authentication requires a versioned protocol migration across Android, iOS, and macOS and is not introduced by this Android-only compatibility patch.
