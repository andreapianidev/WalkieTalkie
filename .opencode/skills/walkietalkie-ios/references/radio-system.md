# Sistema Radio — Stazioni, Stream, Verifica, Aggiunta

## Panoramica

310 stazioni radio hardcoded in `RadioManager.radioStations` (static `let` array in `WalkieTalkie/RadioManager.swift`).
Le stazioni sono definite come `RadioStation` struct con:
- `id: Int` — univoco, **mai riusare ID rimossi** (rompe i preferiti utente)
- `name: String` — nome visualizzato
- `country: String` — nome paese in italiano (deve matchare una chiave in `flagMap`)
- `frequency: String` — es. "102.5" o "—" per web-only
- `streamURL: String` — URL dello stream (HTTP/HTTPS)
- `genre: String` — genere musicale
- `isPro: Bool` — esplicito OGNI volta

### Regola Pro/Free

Il default storico `isPro = (id > 30)` **NON deve essere il meccanismo primario**.
Ogni nuova stazione deve specificare `isPro` esplicitamente:

```swift
// Free
RadioStation(id: 311, name: "...", country: "...", frequency: "...", streamURL: "...", genre: "...", isPro: false)

// Pro (isPro: true è il default quando non specificato, MA SPECIFICALO COMUNQUE)
RadioStation(id: 312, name: "...", country: "...", frequency: "...", streamURL: "...", genre: "...", isPro: true)
```

### Come Determinare Free vs Pro

- **Free**: grandi broadcaster pubblici nazionali, stazioni molto popolari, generi con 0 stazioni free esistenti
- **Pro**: stazioni di nicchia, paesi con già coverage free, generi ben rappresentati, content specializzato

Il bilanciamento attuale (~165 free, ~145 pro) va mantenuto approssimativamente.

---

## Procedura di Verifica Stream (OBBLIGATORIA)

**Mai aggiungere una stazione senza verificare lo stream.** Esegui questi passaggi per OGNI URL:

### Step 1: HTTP Header Check

```bash
curl -I --max-time 5 -L "<STREAM_URL>" 2>&1
```

Verifica che:
- HTTP status code sia 200, 302, 301, o 307
- Content-Type sia audio (audio/mpeg, audio/aac, application/vnd.apple.mpegurl, audio/x-mpegurl)
- Il server risponda entro 5 secondi

### Step 2: Brief Audio Test

```bash
curl --max-time 8 -L "<STREAM_URL>" -o /tmp/radio_test.mp3 2>&1 | tail -5
file /tmp/radio_test.mp3
```

Il file risultante deve essere riconosciuto come audio (MPEG ADTS, AAC, etc.), non HTML o vuoto.

### Step 3: Quality Inference

Dal Content-Type e URL, determina la qualità:
- URL contiene `.m3u8` o `/playlist` → **HLS** (più affidabile su iOS)
- Content-Type `audio/aac` o URL contiene `.aac` → **AAC**
- URL contiene `.mp3` → **MP3**
- Altro → `unknown` (evita se possibile)

La qualità HLS è preferita per iOS (adaptive bitrate, resume automatico).

### Step 4: Validazione Aggiuntiva

- Testa con un player reale (VLC o Safari) che l'audio effettivamente parta
- Verifica che lo stream non sia geo-blocked (test da IP italiano se possibile)
- Per HLS: verifica che il manifest (.m3u8) contenga segmenti validi

---

## Dove Aggiungere la Stazione nel Codice

RadioManager.swift ha blocchi MARK commentati. Inserisci nel blocco appropriato:

```
// MARK: - Free aggiuntive (mese anno) — descrizione
// Per stazioni Free aggiuntive oltre le prime 135

// MARK: - Pro aggiuntive (mese anno) — descrizione
// Per stazioni Pro aggiuntive
```

### ID Progressivi

L'ultimo ID usato è **310** (maggio 2026). Usa ID 311+ per nuove stazioni.
**Non rinumerare mai le stazioni esistenti** — gli ID sono referenziati nei preferiti UserDefaults.

### Esempio di Aggiunta

```swift
// MARK: - Free aggiuntive (maggio 2026) — nuovi broadcaster
RadioStation(id: 311, name: "Radio Esempio", country: "Italia", frequency: "100.0",
    streamURL: "https://stream.esempio.it/live", genre: "Pop", isPro: false),
RadioStation(id: 312, name: "Radio Esempio Pro", country: "Brasile", frequency: "88.5",
    streamURL: "https://stream.esempio.br/aac", genre: "World", isPro: true),
```

---

## Flag Emoji per Nuovi Paesi

Se aggiungi una stazione di un paese non ancora in `flagMap`, devi aggiungere la mappatura.
Le emoji bandiera usano i codici ISO 3166-1 alpha-2 regional indicator symbols.

`flagMap` è in `RadioManager.swift:66-87`. Aggiungi la entry:

```swift
"Paese in Italiano": "🇦🇨",  // esempio
```

---

## Fonti Affidabili per Stream URL

1. **radio-browser.info API** (https://api.radio-browser.info) — database pubblico di stream
   - Endpoint: `/json/stations/search?name=...&countrycode=...`
   - Verifica che `url_resolved` sia popolato e funzionante

2. **Siti ufficiali dei broadcaster** — cerca la pagina "come ascoltarci" o "streaming"
   - Rai: `icestreaming.rai.it`
   - BBC: `as-hls-ww-live.akamaized.net`
   - Radio France: `icecast.radiofrance.fr`
   - StreamTheWorld: `playerservices.streamtheworld.com`
   - Shoutcast: `streamingv2.shoutcast.com`

3. **Icecast directory** (https://dir.xiph.org) — directory pubblica server Icecast

4. **TuneIn** — ispeziona la pagina web per trovare lo stream URL diretto (più fragile)

### Stream URL che NON funzionano su iOS

- Stream raw TCP senza HTTP wrapper (rtmp://, rtsp://)
- Stream con referrer check o user-agent blocking
- Stream che richiedono cookie di sessione
- Stream HTTP (non HTTPS) su iOS con ATS — il progetto ha `NSAppTransportSecurity` configurato per permettere HTTP

---

## Manutenzione Stazioni Esistenti

### Stream Rotto (404 / Timeout / Geo-blocked)

1. Verifica se lo stream esiste ancora tramite radio-browser.info o il sito ufficiale
2. Se trovi un URL aggiornato, **sostituisci solo lo `streamURL`** — non cambiare ID
3. Se lo stream è defunto e nessuna alternativa esiste, commenta la riga con `// REMOVED: motivo` e lascia un gap nell'array

### Stazione Duplicata

Se trovi un duplicato:
1. Mantieni la stazione con ID più basso (per i preferiti utente)
2. Commenta la seconda con `// DUPLICATE of id XXX`

---

## Statistiche Correnti

| Categoria | Conteggio |
|---|---|
| Totale stazioni | 310 |
| Free (isPro: false) | ~165 |
| Pro (isPro: true) | ~145 |
| Paesi coperti | 55+ |
| Generi | Pop, Rock, Jazz, Classical, News, Talk, Electronic, Dance, Hip-Hop, Latin, World, Country, Metal, Reggae, Oldies, Easy, Urban, Alternative, Bollywood, J-Pop, Italian, Sport, Eclectic |
| Qualità stream | HLS (~30%), AAC (~20%), MP3 (~45%), Unknown (~5%) |
| Ultimo ID | 310 |
