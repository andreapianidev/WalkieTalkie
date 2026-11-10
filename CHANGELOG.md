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

#### Added (versionCode 6 to 9, with iOS and Mac 4.0)
- **Relay between nearby phones**: a transmission hops through a third device
  running Talky and reaches further; retransmissions no longer mix into the
  voice of whoever is talking.
- Indonesian and Polish.
- Four duplicate stations replaced (same ids), and RTL 102.5 plays again.

#### Removed
- 8 radio stations that no longer exist (same list as iOS 3.2 build 114). `versionCode` 4 → 5.

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

### [4.0] (145), ready for review, not submitted yet

Same version number as the iPhone from now on: 2.1.1 was renamed 4.0 before it
shipped, so the 2.1.1 entry below is part of 4.0 too.

#### Added
- **Private rooms** and **talking on POC** from the Mac, in the Live panel, with
  the same rules, Safety menu and room codes as the iPhone. Reporting a channel
  opens a prefilled email.
- **Relay between nearby devices**, and the iPhone now finds the Mac by itself.
- **Widgets and controls:** My Radios, Now Playing, CB channel 19 in Control
  Center.
- **The whole interface in 16 languages.** Outside onboarding the Mac was
  English only; Indonesian and Polish added.
- **Write to me** in Settings.

#### Changed
- Paywall with **Forever** as a third option, scrolling, with Terms and Privacy
  always visible.

#### Fixed
- Radio errors were shown in Italian in every language.
- RTL 102.5 plays again (build 145).

### [2.1.1] (125), unreleased

#### Changed in (125)
- The Terms of Use and Privacy Policy links in the paywall open the new pages
  on www.andreapiani.com/talky/, rewritten to describe what the app does today.

### [2.1] (124), in review since 4 November 2026 (App Store build 158)

#### Fixed in (124)
- Opening CB from the Channel widget showed the HF list and an HF station
  name next to the CB frequency: the live view now follows the band the
  receiver is on.
- The window can no longer be made so narrow that the sidebar is cut off
  (minimum 1100 x 640).

#### New in (120)
- **Onboarding redone**, 5 pages in 14 languages: live CB, HF and POC first,
  then the walkie-talkie, network and microphone, the 330+ stations (it said
  343 from 50+ countries) and the desktop widgets.

#### Fixed in (119)
- Radio list and Now Playing show each station's country in the Mac's
  language instead of Italian.

#### New in (116)
- **The Pro panel says what you have.** The paywall lists the same features in
  every language (live bands without the daily limit, widgets, all stations,
  private channels, themes, iPhone + iPad + Mac). For a Pro user the TALKY PRO
  badge in the sidebar now opens it, with what each feature does and where the
  widgets are.

#### New in (114)
- **Widgets on the Mac desktop**: Channel, Propagation (small, medium, large)
  and Sun & bands, the same as iOS. A click opens Talky on the band.
- The station list keeps itself clean, and 8 dead stations are gone, as on
  iOS 3.2 (114).

#### New in (113)
- HF and CB show the spectrum of the received audio until the receiver's
  waterfall arrives, as on iOS 3.2 (113).

#### New in (112)
- The world radio and POC show what you are listening to as equalizer bars,
  same as iOS 3.2 (112).

#### Fixed in (111)
- The receiver's spectrum no longer waits for ever: Talky moves to a receiver
  that sends it, follows the proxy.kiwisdr.com redirects and says when no
  receiver sends one. Same fix and same measurements as iOS 3.2 (111).


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

### [4.0] (145), ready for review, not submitted yet

One version number for iPhone and Mac from now on: 3.2.2 was renamed 4.0 before
it shipped, so everything listed under 3.2.2 below is part of 4.0 too.

#### Added
- **Private rooms.** Open a room, share its 8-character code (or the invite
  link `talky://room/CODE`) and talk with friends far away, over the internet.
  Opening a room is Talky Pro, joining with a code is free, and minutes spent in
  a room do not count against the free daily minutes. Rooms live on our own
  Mumble server; only people with the code can enter, and empty rooms are
  removed after 24 hours.
- **Apple Push to Talk in rooms (Pro).** The room becomes a system channel:
  the blue pill, controls on the Lock Screen, and incoming voice even with Talky
  closed.
- **Talking on POC.** Public POC channels were listen only; now you can talk
  where the server allows it. The first time you accept the rules and choose
  the name others see. Safety, under the talk button, mutes a person or reports
  the channel, and a reported server is no longer suggested.
- **Relay between nearby phones.** A transmission hops through a third device
  running Talky (iPhone, Mac or Android) and reaches further. Older versions
  ignore the extra fields (see [TALKY1](docs/TALKY1.md), section 6b).
- **Pairing help.** If nobody shows up on Explore after 20 seconds, Talky says
  what to check (Wi-Fi and Bluetooth, same channel, distance, Local Network
  permission), shows a red card when Local Network is denied, and offers an
  invite QR code or link to install Talky on the other phone. Meanwhile it
  suggests listening to live CB.
- **Write to me** in Settings, and a review request from the radio as well.
- **Widgets and controls:** My Radios with play and stop from the Home Screen,
  Now Playing with the song title, Walkie on my channel and My favourite radio in
  Control Center.
- **Indonesian and Polish**, 16 languages in total. Live Activities now speak
  all 16 (they had 5, and Simplified Chinese got Traditional).

#### Changed
- The paywall shows **Forever** (pay once) as a third option with the same
  weight as weekly and yearly, with the comparison read from StoreKit. Whoever
  owns it no longer sees the subscriptions.
- Onboarding says up front that the walkie needs Talky on both phones, asks for
  one permission (the microphone), then asks whether you have a friend nearby or
  are on your own (that one starts live CB). Notifications are asked only after
  something worked, not at launch.
- People you accepted once reconnect without a new request; a declined device
  stays quiet for 10 minutes; simultaneous invitations queue instead of getting
  lost.
- The bottom bar is measured instead of fixed: Settings and the talk button are
  no longer covered on short screens.
- "Open source" in Settings is now "Source code": the licence is not open
  source in the OSI sense ([LICENSE](LICENSE), [TRADEMARK.md](TRADEMARK.md)).

#### Fixed
- The iPhone now calls Macs and Android phones by itself (TALKY1 discovery had
  no run loop and found nobody).
- A short tap or an interrupted gesture never leaves the microphone on.
- RTL 102.5, the default station, plays again (its old stream stopped
  answering, build 145). Four duplicate stations replaced, same ids so favourites
  keep working.

### [3.2.2] (127), unreleased

#### Changed in (127)
- Version number 3.2.2, because 3.2.1 is out: approved on 4 November 2026.

### [3.2.1] (126), approved 4 November 2026 (App Store build 167)

#### Changed in (126)
- Version number 3.2.1, because 3.2 is out: approved on 4 November 2026.

#### Fixed in (125)
- Connecting to another device no longer sends that device's name to the
  usage statistics. The name of a phone is usually the name of its owner, who
  never agreed to anything.

#### Changed in (125)
- The Terms of Use and Privacy Policy links in the paywall and in the Themes
  Pack sheet open the new pages on www.andreapiani.com/talky/, in Italian and
  Spanish when the app is in those languages, English otherwise.

### [3.2] (124), approved 4 November 2026 (App Store build 157)

#### Fixed in (124)
- Onboarding titles and notes no longer end in "..." on smaller iPhones: in
  Chinese, Thai, Italian, Japanese, Turkish and Vietnamese they wrap and the
  page scrolls (checked on all 8 pages in 14 languages on iPhone 17e).

#### Changed in (123)
- On wide screens the spectrum, waterfall and level bars take all the free
  height, and the controls sit in the middle of their panel. iPad in portrait
  keeps one column with a big screen; two panels when the screen is wider than
  tall or when iPhone Duo has a hinge.

#### New in (122): iPhone Duo and iPad
- **Two-panel radio** on wide screens (the inner display of iPhone Duo, iPad):
  the control head on one side (mode, status, bands, frequency display, keys),
  the screen on the other (spectrum and waterfall, level bars, or the
  push-to-talk key). On iPhone Duo the gap between the panels is the hinge,
  read even when the phone is open flat, so nothing moves when you fold it and
  no key sits on the crease. Folded on a table (horizontal hinge), the screen
  goes above and the keys below.
- Compact layout decided by the app's window, not the main screen: iPhone Duo
  has two displays.
- The ad banner takes the width of its container (it changes when you open
  and close iPhone Duo).
- Sheets use NavigationStack (NavigationView on iOS 15).
- Tab bar labels stay on one line on the narrower outer display.

#### Fixed in (121)
- **iPad**: the main screen no longer stretches the phone layout across the
  whole display. The radio keeps its size, centred, and the spectrum,
  waterfall and level bars grow taller to use the space.

#### New in (120)
- **Onboarding redone**, 8 pages in 14 languages: live CB, HF and POC come
  second (with a sketch of the spectrum and waterfall), then the world radio
  with the real switch (it showed "WT / FM", and there is no FM), a new page on
  the widgets, then the walkie-talkie pages.

#### Fixed in (119)
- Radio: the country of a station is shown in your language ("Germany",
  "Allemagne", "ドイツ"), not always in Italian ("Germania"). Search finds it
  both ways.

#### New in (118)
- The app is called **Talky** under its icon on iPhone and iPad, as on the Mac
  and on the App Store (it said "Walkie Talkie").

#### New in (116)
- **"Your Talky Pro".** Right after buying, the paywall turns into a page with
  everything Pro unlocks, what it does and where to find it (Settings ›
  Personalization, or the widget gallery). It opens again from Settings,
  "What your Pro includes". 14 languages.
- The paywall list now matches that page, item for item, and adds the widgets
  and the iPhone + iPad + Mac line.

#### Fixed in (115)
- Radio bars no longer go dark between HLS segments (BBC and the other HLS
  streams arrive in 6-10 second blocks).

#### New in (114)
- **The station list keeps itself clean.** A station that fails to start
  twice in a row is hidden for seven days, then gets another chance; one
  successful play resets it. Closed stations disappear without waiting for
  an app update, and stations blocked in a country (the Australian ones
  outside Australia) disappear only for whoever cannot receive them.
- Removed 8 stations that no longer exist (404, 400 or no answer, checked
  on 3 Nov 2026): Retro FM Estonia, Prambors FM, Cubania Radio, Deep House
  Lounge, RTL 102.5 Best, Ocean 89, ZFB Power 95, Melody FM Malaysia.
  335 stations remain, on iOS, Mac and Android.

#### New in (113)
- **HF and CB always show a spectrum.** Many KiwiSDRs accept one connection
  per address, and the waterfall is refused when the audio has taken it
  (measured: whichever connects first, audio or waterfall, gets the slot).
  Until the receiver's waterfall arrives, and if it never does, the screen
  shows the spectrum of the audio being received, as bars, marked "Audio
  spectrum" (Etere's audio scope idea); Talky keeps looking for a receiver
  with a waterfall meanwhile.
- **Widgets.** Propagation now also comes small (Kp, flux, flare class, the
  four bands), shows the G storm scale, the X-ray flare class and, in the
  large size, NOAA's Kp forecast for the next 24 hours; the last reading is
  kept for when the phone is offline (from Etere's propagation widget).
  New *Sun & bands* (Pro): next sunset or sunrise where you are, the best
  band now and the bands after the next change, small, medium and Lock
  Screen. The free *Channel* widget also goes on the Lock Screen. New
  Control Centre button (iOS 18) that opens Talky on CB 19.
- The world radio: a stream whose address ends in .m3u8 but sends plain MP3
  now shows its bars too.

#### New in (112)
- **The world radio screen shows what you are listening to, as equalizer
  bars** (24 LED columns, plus the level of the last six seconds), lined up
  with what the player is playing. The radio player gives no samples of a
  live stream, so Talky reads the same stream a second time and decodes it
  (decoder ported from Etere), MPEG-TS and AAC HLS segments included. It
  runs only while the radio plays with the app in front: in the background
  and on pause it uses no data. The "this stream cannot be read" caption
  is gone.
- **POC has the same bar display** of the voice coming from the channel, with
  who is talking, in place of the speaker dot grid.

#### Fixed in (111)
- **The spectrum stayed on "waiting" for ever on many receivers, in every
  country.** Most public KiwiSDRs give audio to 8 listeners but the waterfall
  to only 3 (709 of 840 in the public list are `rx8.wf3`): whoever arrives
  later gets sound and no spectrum, often without being told. Measured near
  the top download countries (Taipei, New York, Los Angeles, Berlin, Toronto,
  Hong Kong, London, Paris, Sao Paulo, Rome, Sydney): 25 of the 55 nearest
  receivers sent the waterfall, and every city had at least one among its
  nearest five. Talky now waits 6 seconds for the spectrum, then moves to
  the next receiver by itself (up to three times), remembers for six hours
  which receivers sent none, and says so when none of them does.
- **Receivers behind proxy.kiwisdr.com were skipped after a 10 second
  timeout.** They answer with a redirect to `proxy2` that the WebSocket did
  not follow, and in the US, Germany, the UK, Hong Kong and Australia they
  are often the nearest ones. The redirect is now followed.

#### Correction
- The (110) notes below said the radio waveform works "on 317 of the 344
  stations". It was never measured, and it was wrong: the audio tap that
  build used receives no samples from any live stream, HLS or not (measured
  on 20 stations; the same tap works on local files). It is being replaced.

#### In (110)

#### New
- **Widgets.** Free: *Talky channel*, your favourite channel (CB 19, CB 9,
  DX 27.555, VOLMET, 40 m, 20 m, WWV) on the walkie display with whether its
  band is open now; a tap opens Talky already tuned. Talky Pro:
  *Propagation* (medium and large) with solar flux, Kp and radio blackouts
  from NOAA SWPC, an open/weak/closed estimate for 11 m CB, 20, 40 and 80 m
  where you are, day or night, and the Kp of the last 24 hours; *Band
  conditions* on the lock screen (Kp gauge, 11 m line, inline).
- **The radio has its own screen**: no disabled talk button and no dot grid,
  but the waveform of the station that is playing (read from the stream, on
  317 of the 344 stations; HLS streams do not give access to the samples)
  and the level of the last seconds, with country, genre, bitrate, status,
  volume and sleep timer.
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
