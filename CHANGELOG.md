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

### [2.1] (109), not submitted yet

#### New in (106)
- **Spectrum and waterfall** of the receiver on HF and CB, with the CB
  channel numbers on the scale and the signal's margin over the noise.
- **5 free minutes of live radio a day**, then Talky Pro.
- The receiver is chosen near you from your time zone: from the Canary
  Islands the app picked one in France, 2,300 km away.
- Onboarding: a page on live radio, in 14 languages.


#### New
- **CB 27 MHz** in the Live receiver: all 40 channels, the DX area above
  channel 40 with the calling frequency 27.555 USB, channel step, 1 kHz fine
  tuning, AM/FM/LSB/USB, a frequency you can type.
- **SCAN on CB** (Talky Pro): stops while someone transmits, moves on 3 s
  after.
- **Automatic squelch**: the hiss stays muted between transmissions.

#### Fixed before release (105)
- **The squelch no longer cuts AM and FM stations mid sentence.** After 4
  seconds of talking it took the station for a silent carrier and muted it
  for the rest of the transmission. It now tells voice from hiss by the audio,
  and opens again when someone talks over a carrier it had muted.
- **SCAN on CB stops on a noisy channel only on the first pass**, and moves on
  as soon as it hears that it is only noise, instead of waiting 7 seconds on
  every pass.

### [2.0] (112), 2026-10-16

#### New
- **Live receiver**: real HF shortwave from public KiwiSDR receivers and real
  POC channels from public Mumble servers, listen only.

#### Removed
- All recorded and simulated audio (fake frequencies, white noise).

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

### [3.2] (109), not submitted yet

#### New
- **No talk button on HF, CB and POC**, which are listen only: the
  receiver's screen takes its place, wider, with a panel of readings
  (receiver, distance, signal in S units and dBm, mode and bandwidth, squelch
  or UTC, free minutes left).
- Header and display texts shrink to fit instead of ending in "...": the
  receiver is shown by its place, not by the long name its owner gave it.
- **Spectrum and waterfall** of the receiver on HF and CB, in place of the
  speaker grille, with the CB channel numbers on the scale and the signal's
  margin over the noise.
- **5 free minutes of live radio a day**, then Talky Pro or a short video
  for 24 hours. The one-time paywall after 10 minutes is gone.
- Onboarding: a page on live radio, in 14 languages.

#### Fixed
- **Black text on a black background in light mode.** Since 2.4 the default
  theme painted the screen almost black while the text stayed black; the
  walkie is yellow again in light mode, and the dark themes force dark mode.
- The theme background now reaches under the status bar: in light mode a
  white band sat above the yellow walkie.
- The selected band (LOCAL, HF, CB, POC) has a black outline: yellow on the
  yellow walkie it almost disappeared.
- The receiver is chosen near you from your time zone: from the Canary
  Islands the app picked one in France, 2,300 km away.

### [3.1.1] (105), never submitted, folded into 3.2

#### Fixed
- **The squelch no longer cuts AM and FM stations mid sentence.** After 4
  seconds of talking it took the station for a silent carrier and muted it
  for the rest of the transmission. It now tells voice from hiss by the audio,
  and opens again when someone talks over a carrier it had muted.
- **SCAN on CB stops on a noisy channel only on the first pass**, and moves on
  as soon as it hears that it is only noise, instead of waiting 7 seconds on
  every pass.

### [3.1] (103), on sale since November 2026

#### New
- **CB band** next to LOCAL, HF and POC: the real citizens band on 27 MHz,
  all 40 channels (AM on 1 to 35, LSB on 36 to 40 by default) and the DX area
  above channel 40, calling on 27.555 USB.
- CH up/down, 1 kHz fine tuning, AM/FM/LSB/USB, and a frequency you can type
  in the channel list.
- **SCAN on CB** (Talky Pro, or 24 hours with a short video): stops while
  someone transmits, moves on 3 s after.
- **Automatic squelch** (SQL): the hiss stays muted between transmissions.

#### Changed
- The "CB 27.555" entry left the HF list: it lives in the CB band now.

### [3.0] (113), 2026-10-16

#### New
- **HF** and **POC** bands: real shortwave from public KiwiSDR receivers and
  real public Mumble channels, listen only. SCAN and listening with the screen
  off are Talky Pro.

#### Removed
- The 19 fake frequencies, their recorded clips and the white noise switch.

### [2.48] (99), unreleased

- Explore no longer invents distances. The radar with 25/50/75/100 m rings and
  devices drawn at random positions is gone (MultipeerConnectivity gives no
  distance and no signal strength), and so are the "~20m" and "Strong/Weak"
  labels on each device. What is left is true: whether Talky is searching, and
  the list of devices found with their real status (available, request sent,
  connected). The empty-list hint now says what iPhone-to-iPhone really needs
  (Talky open, Wi-Fi and Bluetooth on) and that only Mac and Android need the
  same Wi-Fi network.
- No more em or en dashes in visible text, iOS and Mac, in every language.
- Mac: the copyright line in Settings and in the About box now carries the
  correct NIE and town.

#### Also in 2.48 (98)

- On iPhone 8, SE and other small screens, Explore and Connections now scroll:
  the "+" buttons to invite a device and "Restart discovery" no longer end up
  hidden under the bottom bar.
- The main walkie screen is more compact on small screens, and scrolls instead
  of pushing the header under the status bar when it still does not fit.
- The Pro screen shows the free trial only when the Apple ID can actually get
  it, only with the yearly plan selected, and the button says "Try free for N
  days". The yearly trial is now 7 days (set on App Store Connect).

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
