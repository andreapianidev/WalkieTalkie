# Android radio stream audit — 2026-08-02

The complete Android catalog was probed from the command line with redirects
enabled and bounded connection/read timeouts.

- Catalog entries: 343
- Streams responding before remediation: 337
- Streams failing before remediation: 6
- Catalog entries after remediation: 343

The six failed endpoints were replaced with working HTTPS streams from the
station or network website:

| Station | Replacement stream |
| --- | --- |
| Magic FM NZ | Renamed to Magic Essential 70s; `https://playerservices.streamtheworld.com/api/livestream-redirect/JOSEQUAVO_S01.m3u8` |
| Latvijas Radio 2 | `https://muste.latvijasradio.lv/shoutcast/mp4:lr2a.stream/playlist.m3u8` |
| RTL2 France | `https://icecast.rtl2.fr/rtl2-1-44-128` |
| Deep House Radio | `https://deephouse-radio.com/api/stream/free` |
| Fun Radio France | `https://icecast.funradio.fr/fun-1-44-128` |
| L.A. Mega | `https://usest-mcp1.golivestream.net:19360/lamega981fm/lamega981fm.m3u8` |

`RadioCatalogHealthTest` preserves the catalog count and prevents these retired
URLs from being reintroduced. This network probe is a point-in-time result;
third-party radio endpoints can change independently of the app.
