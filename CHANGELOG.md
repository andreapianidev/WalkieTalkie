# Changelog

This repository ships **three products** that share one protocol and one
codebase: **Talky iOS**, **macTalky** (macOS) and **Talky Android**. Each has its
own version line, so each has its own section below, newest first.

## The rules, and they are not optional

1. **Every change bumps the build number, in the same commit as the change.**
   `versionCode` on Android, `CURRENT_PROJECT_VERSION` on Xcode. A repair, a
   string, a colour, a comment: always. A build number raised later, on its own,
   no longer says which work it belongs to.
2. **The marketing version** (`versionName`, `MARKETING_VERSION`) goes up when
   the work actually reaches a person: an App Store release, a published APK.
3. **Nothing is released without an entry here first.** If it was worth shipping
   it is worth one line explaining what changes for whoever installs it.
4. Entries say **what changes for the user**, not what changed in the code.
   "Fixed a crash at startup" belongs here; "refactored the manager" does not.

Entries before this file existed have been reconstructed from the GitHub
releases and from the git history, so they are less detailed than what follows.

---

## Talky Android

### [1.3] — unreleased

#### Fixed

- **The app no longer dies on startup.** On Android 16 the published 1.2 APK
  crashed before showing a single screen, taking the whole process down:
  `Unable to get provider androidx.startup.InitializationProvider`, caused by
  `Failed to create an instance of androidx.work.impl.WorkDatabase`. WorkManager
  is not something this app uses directly: it arrives with Firebase and Play
  Services Ads, and `androidx.startup` initialises it as the process starts.
  Room looks up its generated `_Impl` class **by name** at runtime, and R8 was
  renaming it away, because `proguard-rules.pro` had no keep rules at all.
  The rules are now in place.
  This only ever affected the **release** APK, the one people download: debug
  builds are not minified, so the fault was invisible during development and
  visible to everyone else.
- TALKY1 protocol and networking classes are kept unobfuscated, so a Crashlytics
  trace about a failed connection names the real class instead of `qn2`.

#### Changed

- **Minimum Android version is now 13 (API 33)**, up from Android 11 (API 30).
  Two versions forward: no decrepit systems kept alive, and in exchange runtime
  notification permission (`POST_NOTIFICATIONS`, API 33) and modern network and
  audio behaviour can be taken for granted without compatibility branches.
  Devices on Android 11 and 12 stay on 1.2, which is still downloadable.
- `versionCode` 3 → 4.

### [1.2] — 2026-08-20

#### Removed

- **The "Test Ad" banner.** A strip of Google advertising at the bottom of the
  main screen showing a fake ad, which never earned anything.
- **The consent form at first launch.** Talky asked permission to profile you
  for advertising that did not exist. There is nothing left to consent to.
- The advertising SDK is no longer initialised and no ads are fetched in the
  background: lighter startup, less traffic and battery.

Nothing else was removed: local-network push-to-talk, 343 radio stations,
password-protected private channels, and compatibility with iPhone, iPad and Mac
all stayed.

### [1.1] — 2026-08-02

#### Fixed

- Restored all catalogued HTTP radio stations through a domain-scoped network
  security policy; cleartext stays denied by default.
- Replaced nine unavailable or unreliable radio endpoints with verified HTTPS
  streams, keeping the 343-station catalogue intact.
- Fixed a crash when microphone permission is denied or audio capture fails.

#### Added

- Foreground service for background radio playback and peer connectivity.

### [1.0] — 2026-06-17 (beta)

First public release of the Android port, Kotlin and Jetpack Compose: push-to-talk
over the local network via NSD, the 343-station radio catalogue, Firebase
Analytics and Crashlytics. No Pro tier, no Live Activities, one base theme.

---

## macTalky (macOS)

### [1.1.4] — current

Version train opened after 1.1.3 went on sale.

### [1.1.3] and earlier 1.1.x

- The Now Playing panel stopped announcing radio streams as "FM", which they are
  not.
- Streaming playback, half-duplex push-to-talk and link recovery reworked (1.1.0).

### [1.0] — 2026-08-02

First macOS release, native, macOS 26+. Push-to-talk with the TALK key or the
space bar, auto-discovery of iPhone, Android and Mac peers over
[TALKY1](docs/TALKY1.md), the 343-station radio, a tactical Metal console with
five backdrops, private password channels, onboarding in 14 languages.
Sandboxed, no ads, no tracking.

---

## Talky iOS

### [2.46] — 2026-09-20

- The paywall trigger is consumed only once the paywall has actually appeared,
  so a trigger is no longer burned on a screen nobody saw.
- Prices and documentation aligned to what actually exists.
- Copyright line corrected: it carried an old VAT number dressed up as a NIE and
  the wrong town.

### [2.45] — 2026-08-19

- The rewarded ad gives something worth having; the radio states it is internet
  radio rather than FM.

### [2.44] — 2026-08-04

### [2.42] — 2026-08-03

### [2.41] — 2026-07-10

---

## Protocol

The TALKY1 wire protocol is specified in [`docs/TALKY1.md`](docs/TALKY1.md) and
is **shared by all three products**. It is versioned separately from the apps:
new message types and new fields are compatible and need no version change,
because every receiver ignores what it does not recognise. Anything that changes
the audio payload, the framing or the `HELLO` handshake is incompatible and needs
`TALKY2` published alongside `TALKY1`, for as long as shipped versions speak it.
