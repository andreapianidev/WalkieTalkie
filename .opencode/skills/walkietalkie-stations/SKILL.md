---
name: walkietalkie-stations
description: >-
  Aggiungi, verifica e gestisci le stazioni radio di Talky (WalkieTalkie).
  Usa questa skill OGNI VOLTA che l'utente dice: "aggiungi stazione", "nuova stazione", "aggiungi radio", "aggiungi queste stazioni",
  "verifica stream", "nuova radio", "aggiungi batch stazioni", "stazioni nuove",
  o qualsiasi richiesta di aggiungere stazioni radio all'app Talky.
  Include verifica OBBLIGATORIA degli stream URL via curl, gestione ID progressivi,
  determinazione automatica di free vs Pro, e aggiornamento di tutti i file coinvolti
  (RadioManager.swift, flagMap, StationBrowserSheet, ContentView). NON usare per modifiche
  al player, alla UI, ai temi, o alla monetizzazione — quella è walkietalkie-ios o walkietalkie-themes.
  Questa skill gestisce anche il refresh di stazioni esistenti (URL scaduti, sostituzioni, fix minori).
---

# WalkieTalkie Station Manager — Skill

Aggiunge, verifica e manutiene le stazioni radio in Talky. **Workflow obbligatorio e non negoziabile.**

---

## Architettura del Sistema Stazioni

```
RadioStation (struct) → radioStations: [RadioStation] (in RadioManager.swift, riga ~117)
    ↓
StationBrowserSheet.swift → UI browser con ricerca, preferiti, recents, grouped by country/genre
ContentView.swift → comandi riproduzione (prev/next/play/pause), pulsante browse
```

### Regole Fondamentali (Mai Violare)

1. **ID sono immutabili dopo creazione.** I preferiti utente sono salvati per ID in UserDefaults. Non rinumerare mai.
2. **L'ultimo ID usato è 310** (maggio 2026). Le nuove stazioni partono da **311**.
3. **`isPro` deve essere SEMPRE esplicito** per ogni nuova stazione. Non fare mai affidamento sul default storico `id > 30`.
4. **Ogni stazione DEVE essere verificata** con curl prima di essere aggiunta. Stream morti = app che crasha silenziosamente.
5. **Mantenere il bilanciamento** ~165 free / ~145 pro (rapporto ~53/47).

---

## Procedura di Aggiunta Stazioni (OBBLIGATORIA)

### Step 1: Ricevi le Stazioni

L'utente descrive le stazioni in linguaggio naturale. Esempi:
- "Aggiungi Radio 105, Italia, 105.0, http://..."
- "Aggiungi queste radio: Nome1 Paese1 Freq1 URL1, Nome2 Paese2 Freq2 URL2..."
- "Ho trovato queste stazioni su radio-browser: ..."

Per ogni stazione, estrai:
- `name` — nome visualizzato
- `country` — in italiano, deve matchare una chiave in `flagMap`
- `frequency` — es. "102.5" o "—" per web-only
- `streamURL` — URL completo dello stream
- `genre` — genere musicale (usa generi esistenti quando possibile)
- `isPro` — determinato dalle regole qui sotto

### Step 2: Determina Free vs Pro

| Condizione | isPro |
|------------|-------|
| Broadcaster pubblico nazionale (Rai, BBC, France Inter, NRK, DR, Yle...) | `false` |
| Stazione molto popolare con milioni di ascoltatori | `false` |
| Genere con 0 stazioni free esistenti (es. se manca Jazz free) | `false` |
| Paese non ancora coperto — prima stazione del paese | `false` (se broadcaster importante) |
| Stazione di nicchia (genere saturo, paese con già coverage) | `true` |
| Stazione internet-only senza corrispettivo FM importante | `true` |
| Stream TheWorld / Shoutcast non ufficiale | `true` (salvo eccezioni) |
| Dubbio? Metti `true` | `true` |

### Step 3: Verifica Ogni Stream URL (OBBLIGATORIO)

Per OGNI URL, esegui:

```bash
# Header check — deve rispondere 200/302/301/307 e Content-Type audio
curl -I --max-time 5 -L "<STREAM_URL>" 2>&1
```

**Criteri di accettazione:**
- HTTP status: 200, 302, 301, o 307 (NO 404, 403, 500, timeout)
- `Content-Type` deve iniziare con `audio/`, `application/vnd.apple.mpegurl`, o `audio/x-mpegurl`
- Server deve rispondere entro 5 secondi

Se un URL non supera → **comunica all'utente che la stazione è stata SALTATA** con il motivo. Non aggiungere stazioni con URL non verificati.

Per HLS (.m3u8), verifica anche che il manifest contenga segmenti:
```bash
curl --max-time 5 -L "<M3U8_URL>" 2>&1 | head -20
# Deve contenere #EXTINF o #EXT-X-STREAM-INF
```

### Step 4: Determina Qualità Stream

| Pattern URL | Qualità |
|-------------|---------|
| `.m3u8` o `/playlist` | HLS (preferita su iOS) |
| `.aac` | AAC |
| `.mp3` | MP3 |
| altro | unknown (evita) |

La qualità è **derivata automaticamente** dal codice in `RadioStation.quality` — non devi specificarla.

### Step 5: Assegna ID e Scegli il Blocco

L'ultimo ID è **310**. Assegna ID progressivi (311, 312, 313...).

Scegli il MARK blocco corretto in `RadioManager.swift`:

| Situazione | Blocco |
|------------|--------|
| Nuove stazioni Free | `// MARK: - Free aggiuntive (mese anno) — descrizione` |
| Nuove stazioni Pro | `// MARK: - Pro aggiuntive (mese anno) — descrizione` |

**Regola**: se il mese corrente è diverso dall'ultimo MARK presente, crea un NUOVO blocco. Altrimenti, aggiungi al blocco esistente.

### Step 6: Genera il Codice Swift

Formato esatto per ogni stazione:

```swift
RadioStation(id: 311, name: "Nome Stazione", country: "Italia", frequency: "102.5",
    streamURL: "https://stream.url/live", genre: "Pop", isPro: false),
```

Note importanti:
- `country` deve matchare ESATTAMENTE una chiave in `flagMap`. Se il paese non esiste, devi prima aggiungere la flag emoji (Step 7).
- Se la frequenza è "—" (web-only), la UI mostra il genre in uppercase via `displayLabel`.
- L'ultima stazione del blocco/array NON ha virgola finale. Le altre sì.

### Step 7: flagMap per Nuovi Paesi

Se aggiungi una stazione di un paese non ancora in `flagMap` (righe 66-87 di RadioManager.swift), devi:

1. Trovare il codice ISO 3166-1 alpha-2 del paese
2. Aggiungere la entry in ordine alfabetico:
```swift
"Paese in Italiano": "🇽🇽",
```
3. Usare la regional indicator emoji corretta (es. "🇰🇷" per Corea del Sud)

### Step 8: Output Finale

Dopo aver verificato TUTTE le stazioni, genera il report completo:

```
## ✅ Stazioni aggiunte con successo (N)

| # | Nome | Paese | Free/Pro | Qualità |
|---|------|-------|----------|---------|
| 311 | Radio Esempio | Italia | Free | HLS |

### 📝 Codice da incollare
[blocco Swift pronto]

### ⚠️ Stazioni saltate (M)
[elenco con motivi]

### 📋 Modifiche aggiuntive
- flagMap: aggiunto "Corea del Sud": "🇰🇷" (se applicabile)
```

---

## Manutenzione Stazioni Esistenti

### Stream Rotto
1. Verifica lo stream con `curl -I --max-time 5 -L "<URL>"`
2. Se non funziona, cerca su radio-browser.info o sito ufficiale un URL sostitutivo
3. **Sostituisci solo `streamURL`** — non cambiare ID
4. Se defunto senza alternativa, commenta con `// REMOVED: data - motivo`

### Duplicato
1. Mantieni la stazione con ID più basso (minore impatto sui preferiti)
2. Commenta la seconda con `// DUPLICATE of id XXX`

---

## Struttura RadioManager.swift (Righe Rilevanti)

| Contenuto | Righe |
|-----------|-------|
| `RadioStation` struct | 21-88 |
| `flagMap` | 66-87 |
| `radioStations` array | 117-563 |
| Free Italia + Europa (id 1-30) | 117-155 |
| Pro internazionali (id 31-135) | 156-318 |
| Free aggiuntive (id 136-143) | 319-328 |
| Pro aggiuntive (id 144-209) | 329-419 |
| Free round 3 (id 210-230) | 420-455 |
| Pro round 3 (id 231-241) | 456-468 |
| Free round 4 (id 242-249) | 469-486 |
| Pro round 4 (id 250-267) | 487-512 |
| Free round 5 (id 268-277) | 513-524 |
| Pro round 5 (id 278-290) | 525-539 |
| Free round 6 (id 291-297) | 540-548 |
| Pro round 6 (id 298-310) | 549-563 |
| `playStation()` | ~680-740 |
| `setupNowPlayingInfo()` | ~1044-1055 |
| `teardownPlayer()` | ~1178 |
| KVO observer | ~1120-1156 |

---

## Fonti Affidabili per Stream URL

1. **radio-browser.info API**: `https://api.radio-browser.info/json/stations/search?name=...&countrycode=...`
   - Verifica che `url_resolved` sia popolato (preferito a `url`)
2. **Siti ufficiali**: cerca "ascoltaci in streaming" o "listen live"
3. **Icecast directory**: `https://dir.xiph.org`
4. **TuneIn**: ispeziona pagina web per URL diretto (fragile)

### URL che NON funzionano su iOS
- `rtmp://`, `rtsp://` — raw TCP senza HTTP
- Stream con referrer check o user-agent blocking (AVPlayer non manda referrer)
- Stream che richiedono cookie di sessione
- HTTP funziona (ATS è configurato per permesso), ma HTTPS è preferito

---

## Verifica Rapida Dopo l'Aggiunta

Per verificare che il codice sia corretto, l'utente dovrà buildare. Il progetto non ha test unitari, quindi la verifica è:

```bash
xcodebuild -project "WalkieTalkie.xcodeproj" -scheme WalkieTalkie -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

---

## Riferimenti Incrociati

- **UI Stazioni** (StationBrowserSheet, ContentView, grouped views): usa `walkietalkie-ios` skill con references `ui-systems.md`
- **Player, KVO, Now Playing**: `walkietalkie-ios` skill con reference `radio-system.md`
- **Temi, Paywall**: `walkietalkie-themes` skill
- **Modifiche AI alla UI, onboarding**: `walkietalkie-ios` skill
