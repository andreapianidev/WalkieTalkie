# Talky for Android v1.1

This release makes Talky reliable for daily Android use while preserving the
existing AdMob and Firebase integrations.

## Fixed

- Restored all catalogued HTTP radio stations through a domain-scoped Android
  network security policy; cleartext remains denied by default.
- Replaced six unavailable radio endpoints with verified HTTPS streams.
- Prevented a crash when microphone permission is denied or audio capture fails.
- Added a foreground service for background radio playback, peer connectivity,
  and active microphone transmission.
- Made Android peer-name encoding interoperable with iPhone and Mac by using
  RFC 3986 percent encoding (`%20` for spaces, never `+`).
- Enforced TALKY1 channel isolation during discovery, handshake, connection,
  and broadcast.

## Install

Download `Talky-Android-v1.1.apk` from this release. On first sideload, Android
may ask you to permit installation from the browser or file manager you used.

Minimum supported version: Android 11 (API 30).
