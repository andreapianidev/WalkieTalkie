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
| `AUDIO_META` | `byteCount`, `sampleRate`, `channels`, `encoding`, optional relay fields (see *Relay*) | Announces the audio frames that follow. |
| `AUDIO_END` | none | Marks the end of a streamed transmission. Sent by Android; since 4.0 iOS and macOS use it to close a streamed message before relaying it. |
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

## 6b. Relay (bridge A-B-C, since iOS 4.0, macOS 4.0, Android versionCode 6)

Every device that receives a transmission plays it and forwards it to its other
peers, so A reaches C through B when A and C are out of range of each other.

`AUDIO_META` gains five fields. Older versions ignore them (unknown fields) and
play the audio as before.

| Field | Meaning |
|---|---|
| `msgId` | Unique id of the transmission (UUID, at most 64 characters). Receivers remember the last 256 and drop duplicates: the same message arrives directly and through a bridge. |
| `origin`, `originName` | `uid` and display name of who spoke, not of the bridge that forwarded it. Receivers cut both to 64 characters. |
| `ttl` | Hops left. The speaker sends `2`. A receiver forwards only if `ttl > 1`, with `ttl - 1`. A value above `2` is lowered to `2`. |
| `reached` | Comma-separated short ids (first 8 characters of the `uid`, lowercase) of devices that already got the message from the sender. A bridge does not forward to them, and adds its own targets before forwarding. Without it, a group where everyone is connected to everyone would copy each message from everyone to everyone. At most 64 entries are read or written. |
| `stream` | `1` when the audio comes as many frames closed by `AUDIO_END` (Android). Without it the message is complete after `byteCount` bytes. |

Rules:

- Forward only complete messages: one `AUDIO_META` and one audio frame, back to back
  on the same connection, never interleaved with another message. Android holds one
  output lock from its own `AUDIO_META` to its own `AUDIO_END`: a relay waits for the
  current transmission to end (at most 30 s, then it is dropped) and never for the next.
- A `msgId` counts as seen only when its message is complete (`byteCount` reached, or
  `AUDIO_END`). While it is arriving, a second copy on another connection is dropped;
  if the connection closes halfway, the id is released and a full copy from another
  bridge is played.
- Never forward to the peer it came from, and only to peers on the same channel as the
  connection it came from. A `HELLO` with a different `channel` closes the connection,
  and a channel change closes every connection and restarts publishing and browsing.
- Messages without `msgId` (older versions) are played but not forwarded: without an
  id nobody can tell whether another bridge already delivered them.

On iOS the same fields also travel over MultipeerConnectivity, so an iPhone bridges
between iPhones (Multipeer) and Android/Mac (TALKY1). Older iOS versions play every
Multipeer message as raw Float32, so the fields sit in a header made of Float32 words
whose two high bytes are zero: `0x4B54`, `0x3152` ("TK" "R1"), the number of text
words (at most 2048), then the `k=v|k=v` text two bytes per word, then the Float32
audio. Read as samples, each header word is a subnormal number below 1e-40, i.e. a
couple of milliseconds of silence before the voice. A relay carries at most 30 s of
audio. See `WalkieTalkie/Ponte.swift`.

### Recognising a device already accepted (iOS, Multipeer only)

The `uid` changes at every launch on every platform, so it never identifies a phone
over time. On the public channel an iPhone that accepts an invitation by hand sends,
once and inside the session, a header `0x4B54`, `0x3150` ("TK" "P1") whose text is
`s=<32 random bytes, base64>`, with no audio after it. Both phones keep that secret
in the Keychain. It goes only to peers that advertise `ponte=1`, so an older version
never receives it, and it is accepted only from a peer this phone invited.

Later invitations to a peer with the same display name carry, after the channel line,
`uid=<inviter uid>`, `ts=<unix seconds>` and up to 8 lines
`t=<base64 of the first 16 bytes of HMAC-SHA256(secret, "talky-invito|<invitee uid>|<ts>")>`.
The invitee accepts without asking if one of them matches a secret it holds, `ts` is
within 120 s, and that `t` was not used before. The secret itself never travels again
and nothing stable is advertised. These lines go only to peers advertising `ponte=1`;
older versions compare the whole context with their channel and get the channel alone.

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
- [ ] relay: drops duplicate `msgId` (marked when complete), lowers `ttl` above 2, forwards complete messages with `ttl - 1` only when `ttl > 1`, skips the source, `reached` and other channels

---

## 10. Versioning

The literal `TALKY1` opens every control line and is checked by every receiver: a
line that does not start with it is treated as audio. It is the protocol version.

Compatible changes are new message types and new fields, both of which existing
receivers ignore. Anything that changes the meaning of the audio payload, the
framing or the `HELLO` handshake is incompatible and needs `TALKY2`, alongside
`TALKY1` for as long as shipped versions speak it.
