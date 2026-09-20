# TALKY1 — wire protocol specification

TALKY1 is the local-network push-to-talk protocol behind Talky. It is what lets an
iPhone, a Mac and an Android phone on the same Wi-Fi hear each other, without an
account, a server or an internet connection.

This document is the **normative specification**. It was written by reading the
three shipping implementations and it describes what they actually do, not what
they were meant to do. If an implementation and this document disagree, that is a
bug in one of the two and it is worth an issue.

Anyone can implement TALKY1. It is a small protocol: Bonjour for discovery, TCP
for transport, length-prefixed frames, one line of text per control message and
raw PCM for audio. A working implementation is a few hundred lines.

## Implementations

| Platform | Transport code | Published service name |
|---|---|---|
| Talky iOS | [`WalkieTalkie/TalkyCrossPlatformManager.swift`](../WalkieTalkie/TalkyCrossPlatformManager.swift) | `Talky iPhone <uid4>` |
| Talky macOS (macTalky) | [`macTalky/Core/WalkieEngine.swift`](../macTalky/Core/WalkieEngine.swift) | `Talky Mac <uid4>` |
| Talky Android | [`Android/.../net/CrossPlatformWalkieManager.kt`](../Android/app/src/main/java/com/immaginet/talky/net/CrossPlatformWalkieManager.kt), [`.../protocol/TalkyProtocol.kt`](../Android/app/src/main/java/com/immaginet/talky/protocol/TalkyProtocol.kt) | `Talky Android <uid4>` |
| Peak (third-party, same author) | `SpeedTracker/PeakTalky.swift` in the Peak GPS Altimeter app | `Peak <uid4>` |

`<uid4>` is the first four characters of the instance UID (see *Identity* below).

On Apple platforms TALKY1 runs **alongside** MultipeerConnectivity, it does not
replace it. iPhone-to-iPhone traffic prefers MultipeerConnectivity; TALKY1 is what
reaches everything else. See *Trap 1* for the consequence.

---

## 1. Identity

Every running instance generates a **UID**: a random UUID string, regenerated at
each launch. It is not stable across restarts and must not be used to recognise a
person or a device over time; it exists only to tell two live instances apart
within one session.

Every instance also has:

- a **display name**, the device name, shown to the user;
- a **channel**, a string. `public` is the default. Talky derives private channel
  IDs from a shared password; implementations without private channels use
  `public` and interoperate normally.

---

## 2. Discovery — Bonjour

Publish a Bonjour service:

- **type** `_walkie-talkie._tcp.`
- **domain** `local.`
- **port** the TCP port of your listener (any free port)
- **TXT record**

| TXT key | Value | Required |
|---|---|---|
| `proto` | `talky1` | yes — peers without it are ignored |
| `uid` | this instance's UID | yes |
| `name` | display name | yes |
| `channel` | channel ID, `public` by default | yes |

Browse the same type. For each service found, resolve it and accept it only if
**all** of these hold:

1. `proto` equals `talky1`;
2. its `channel` equals your current channel (a missing `channel` is read as `public`);
3. it is not yourself, checked on `uid` and on the service name;
4. the address resolved to a non-empty host.

Reject anything else silently.

### Apple clients: declare the service

iOS and macOS block Bonjour traffic for services that are not declared in the app's
`Info.plist`:

```xml
<key>NSBonjourServices</key>
<array>
    <string>_walkie-talkie._tcp</string>
</array>
<key>NSLocalNetworkUsageDescription</key>
<string>…why you need the local network…</string>
```

Android needs `INTERNET`, `ACCESS_WIFI_STATE` and `CHANGE_WIFI_MULTICAST_STATE`
for NSD.

---

## 3. Connection

Plain TCP. No TLS, no authentication: TALKY1 assumes a local network you already
trust, exactly like the radio it imitates. Do not carry anything private over it.

Both sides dial each other when they discover each other, so a pair of peers
normally ends up with **two** TCP connections. This is expected and harmless,
provided you follow one rule:

> **Send each transmission once per peer UID, not once per socket.**

Otherwise the other side hears everything twice. Receiving on both sockets is fine.

On connect, each side immediately sends `HELLO`. A peer is "known" once its
`HELLO` has arrived, because that is what carries its UID and display name.

---

## 4. Framing

Every message, text or audio, is one frame:

```
+--------------------+---------------------------+
| length  (4 bytes)  | payload (length bytes)    |
| UInt32 big-endian  |                           |
+--------------------+---------------------------+
```

- **Maximum payload: 1 MiB (1048576 bytes).** All three implementations drop a
  frame that declares more, and Android refuses to write one. A sender that
  exceeds it is simply not heard.
- Empty frames (length 0) are invalid.
- Read the 4-byte header first, then exactly `length` bytes, then loop. Do not
  assume one TCP read returns one frame.

### Telling text from audio

There is no type byte. The receiver decides like this:

1. try to decode the payload as UTF-8;
2. if it decodes **and** starts with `TALKY1|`, it is a control message;
3. otherwise it is audio.

This is why control messages are ASCII and percent-encoded: so that no control
message can ever be mistaken for audio, and audio that happens to be valid UTF-8
is not mistaken for a control message.

---

## 5. Control messages

One line, no trailing content after the newline:

```
TALKY1|<TYPE>|<key>=<value>|<key>=<value>\n
```

Keys and values are **percent-encoded**, with only `A-Z a-z 0-9 - . _ ~` left
literal. Field order is not significant. Unknown fields must be ignored, not
rejected; unknown message types must be ignored too. That is the whole extension
story: add fields, ignore what you do not know.

| Type | Fields | Meaning |
|---|---|---|
| `HELLO` | `uid`, `name`, `channel` | Sent once, immediately on connect. Registers the peer. |
| `HEARTBEAT` | none | Keep-alive. Accepted and ignored by every implementation; nothing requires you to send it. |
| `AUDIO_META` | `byteCount`, `sampleRate`, `channels`, `encoding` | Announces the audio frames that follow. |
| `AUDIO_END` | none | Marks the end of a streamed transmission. Sent by Android; ignored by iOS and macOS. |
| `INVITE` / `ACCEPT` | none | **Reserved.** Declared in the Android enum, and Android answers an `INVITE` with an `ACCEPT`, but no implementation ever sends one. Do not rely on them. |

A receiver must tolerate audio arriving without a preceding `AUDIO_META`, and
`AUDIO_META` that is never followed by audio.

---

## 6. Audio

**The only format is:**

| | |
|---|---|
| Encoding | `pcm_s16le` — signed 16-bit integer, little-endian |
| Sample rate | 48000 Hz |
| Channels | 1 (mono) |
| Container | none, raw samples |

`AUDIO_META` carries these values, but no implementation negotiates or converts:
they are constants. Sending anything else produces noise on the other side, not an
error. If you ever need a second format, add a new message type rather than
changing these values, or you break every shipped version.

### Two sending styles, and why the receiver must handle both

- **iOS and macOS** accumulate the whole push-to-talk and send it as **one frame**
  when the user releases the button. With the 1 MiB cap that is about 10.9 seconds;
  macTalky caps its own transmissions at 10 s for that reason.
- **Android** streams: one frame per capture buffer, for the whole time the button
  is held, then `AUDIO_END`.

> **A receiver must queue incoming audio frames and play them back to back.**
> Starting a fresh player for each frame works with iOS and macOS and turns Android
> into stuttering, because each frame cancels the one before it. Schedule the
> buffers on a single audio player node, or buffer with a short jitter delay
> (macTalky uses 0.15 s) before starting playback.

Senders should cap a transmission at **10 seconds** of audio (960000 bytes), which
keeps a single-frame transmission under the 1 MiB limit with room to spare.

---

## 7. Session flow

```
A                                          B
|  publish _walkie-talkie._tcp (TXT)       |
|  browse  _walkie-talkie._tcp             |
|<--------- discovers A, dials ----------- |
| ---------- discovers B, dials ---------->|
| ---------- TALKY1|HELLO|… -------------->|
|<--------- TALKY1|HELLO|… --------------- |
|                                          |
|   user holds the button, then releases   |
| ---- TALKY1|AUDIO_META|byteCount=… ----->|
| ---- <raw pcm_s16le frame(s)> ---------->|
| ---- TALKY1|AUDIO_END (Android only) --->|
|                                          |
|              B plays the audio           |
```

---

## 8. Traps

Every one of these has already cost someone a debugging session.

**1. Do not name your service `Talky iPhone …`.** Talky on iOS deliberately skips
every discovered service whose name starts with that prefix, because it reaches
other iPhones over MultipeerConnectivity instead. Pick your own prefix, or iOS
Talky will never connect to you while everything else does, which is a confusing
way to fail.

**2. Send once per peer, not once per socket.** See *Connection*. The symptom is
an echo: every message heard twice.

**3. A frame is not a TCP read.** Length-prefix parsing must handle partial reads
and coalesced frames.

**4. The 1 MiB cap is enforced by the receiver.** A long transmission sent as one
frame is not truncated, it is dropped whole, silently.

**5. Queue the audio.** See *Audio*. Android is the case that exposes this.

**6. Declare the Bonjour service in `Info.plist` on Apple platforms**, or discovery
fails with no error worth reading. Adding the service to an app that already had
another one may re-trigger the local-network permission prompt.

**7. Channel mismatch looks exactly like "no peers".** A peer on a different
channel is filtered out at discovery, silently and by design.

---

## 9. Conformance checklist

A new implementation is TALKY1-compliant when it:

- [ ] publishes `_walkie-talkie._tcp.` in `local.` with TXT `proto=talky1`, `uid`, `name`, `channel`
- [ ] browses the same type and filters on `proto`, `channel` and self
- [ ] uses a service name that does not start with `Talky iPhone`
- [ ] accepts TCP connections and dials discovered peers
- [ ] sends `HELLO` immediately on every connection, in both directions
- [ ] frames everything as UInt32 big-endian length + payload, rejecting > 1 MiB
- [ ] distinguishes control from audio by the `TALKY1|` prefix on valid UTF-8
- [ ] percent-encodes control fields and ignores unknown types and fields
- [ ] sends audio as `pcm_s16le`, 48000 Hz, mono, preceded by `AUDIO_META`
- [ ] caps a transmission at 10 s
- [ ] sends once per peer UID, not per socket
- [ ] queues received audio frames instead of restarting playback per frame

---

## 10. Versioning

The literal `TALKY1` opens every control line and is checked by every receiver: a
line that does not start with it is treated as audio. It is the protocol version.

Compatible changes are new message types and new fields, both of which existing
receivers ignore. Anything that changes the meaning of the audio payload, the
framing or the `HELLO` handshake is incompatible and needs `TALKY2`, alongside
`TALKY1` for as long as shipped versions speak it.
