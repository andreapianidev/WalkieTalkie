# Android radio stream audit — 2026-08-02

The complete Android catalog was probed from the command line with redirects
enabled and bounded connection/read timeouts.

- Catalog entries: 343
- Streams responding on the first full probe: 333
- Streams failing or timing out on the first full probe: 10
- Catalog entries after remediation: 343

Nine failed or unreliable endpoints were replaced with streams that returned
audio or a valid HLS playlist during the verification pass. VOV1 timed out in
the first pass but returned a valid partial HLS response on retry, so its
existing endpoint was retained. Magic FM NZ also passed direct verification and
was intentionally left unchanged.

| Station | Replacement stream |
| --- | --- |
| Galgalatz | `https://glzicylv01.bynetcdn.com/glglz_mp3` |
| Latvijas Radio 2 | `https://muste.latvijasradio.lv/shoutcast/mp4:lr2a.stream/playlist.m3u8` |
| Sveriges Radio P1 | `https://live1.sr.se/p1-mp3-96` |
| MNM | `https://quantumcast.vrtcdn.be/mnm/mp3-128/quantumcast.vrtcdn.be/` |
| RTL2 France | `https://icecast.rtl2.fr/rtl2-1-44-128` |
| Deep House Radio | `https://deephouse-radio.com/api/stream/free` |
| Fun Radio France | `https://icecast.funradio.fr/fun-1-44-128` |
| L.A. Mega | `https://usest-mcp1.golivestream.net:19360/lamega981fm/lamega981fm.m3u8` |
| ABC Lounge Radio | `https://str1.openstream.co/589` |

`RadioCatalogHealthTest` preserves the catalog count and prevents these retired
URLs from being reintroduced. This network probe is a point-in-time result;
third-party radio endpoints can change independently of the app.
