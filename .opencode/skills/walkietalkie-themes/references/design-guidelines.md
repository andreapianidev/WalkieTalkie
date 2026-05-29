# Design Guidelines — Palette e Stile

Regole per generare palette coerenti con lo stile esistente di Talky.

## Principi Generali

1. **Dark first** — tutti i 19 temi sono su fondo scuro. Light mode è gestita dagli asset catalog separatamente
2. **Accento brillante** — un solo colore saturo che emerge dallo sfondo scuro
3. **Leggibilità** — testo primario ≥ 0.88 bianco, secondario ~65%
4. **Coerenza** — i gradienti sono subtly, non urlanti (differenza 10-20% tra top e bottom)
5. **Personalità** — ogni tema deve sentirsi diverso, non solo una tonalità diversa

## Palette Generator

Quando l'utente chiede un tema, usa queste regole per generare la palette completa:

### 1. Scegli Accent Color
Colore saturo che definisce il tema. Deve funzionare sia su sfondo scuro che su surface.

Range usati nei temi esistenti:
- **Rossi/Arance**: rgb(1.0, 0.25..0.4, 0.05..0.2) — wildfire, sunset
- **Verdi**: rgb(0.0..0.4, 0.5..1.0, 0.2..0.3) — forest, submarine, hacker
- **Blu**: rgb(0.0..0.5, 0.45..0.9, 0.9..1.0) — ocean, aurora, arctic
- **Viola**: rgb(0.5..0.85, 0.1..0.3, 0.85..0.9) — midnight, cyberpunk, blackHole
- **Gialli/Oro**: rgb(0.65..1.0, 0.4..0.8, 0.0..0.2) — default, hamRadio
- **Rosa/Magenta**: rgb(1.0, 0.08..0.41, 0.58..0.71) — retro80s, festival

### 2. Deriva Background

| Stile | Regola |
|-------|--------|
| `.solid` | RGB < 0.10, tonalità che suggerisce il tema |
| `.gradient` | Top 10-20% più scuro di Bottom. Entrambi nella tonalità del tema ma molto spenti |
| `.animated` | Sfondo statico + Canvas overlay. Usa gradient o solid come base |

### 3. Deriva Surface

- **`.elevated`**: surfaceColor ~1.8-2.5x brighter di backgroundPrimary (ma sempre scuro, < 0.20)
- **`.cyber`**: surfaceColor ~1.5-2x brighter, con effetto "vetro"
- **`.flat`**: surfaceColor ~1.3-1.5x brighter, minimale

### 4. Deriva Testo

- **textPrimary**: accentColor desaturato + schiarito, o bianco con leggera tinta
  - Esempio ocean: `rgb(0.90, 0.95, 1.0)` — bianco con leggero blu
  - Esempio sunset: `rgb(1.0, 0.94, 0.90)` — bianco con leggero arancio
- **textSecondary**: stessa tonalità di textPrimary ma ~65% opacità o RGB ~0.55-0.65

### 5. Deriva Glow

- accentColor con opacità 0.14-0.26
- Più alto per temi cyber/vivaci (cyberpunk 0.25, retro80s 0.24)
- Più basso per temi sobri (military 0.14, vintageRadio 0.16, arctic 0.16)
- `nil` solo per stealth (tema volutamente senza glow)

### 6. Scegli Icona

Scegli SF Symbol che evochi il tema. Preferisci `*.fill` variants. Pattern dai temi esistenti:

| Tema | Icona |
|------|-------|
| default | `circle.fill` |
| ocean | `water.waves` |
| forest | `leaf.fill` |
| sunset | `sun.horizon.fill` |
| midnight | `moon.stars.fill` |
| military | `shield.lefthalf.filled` |
| retro80s | `sparkles` |
| vintageRadio | `dial.high.fill` |
| cyberpunk | `bolt.fill` |
| stealth | `eye.slash.fill` |
| aurora | `cloud.sun.fill` |
| submarine | `dot.radiowaves.left.and.right` |
| hamRadio | `antenna.radiowaves.left.and.right` |
| festival | `party.popper.fill` |
| blackHole | `circle.dashed` |
| galaxy | `sparkles` |
| hacker | `terminal.fill` |
| wildfire | `flame.fill` |
| arctic | `snowflake` |

### 7. Scegli Font

| Font | Vibrazione | Esempi |
|------|-----------|--------|
| `nil` (system) | Neutro, pulito | Default, Ocean, Forest, Sunset, Midnight |
| `"Courier New"` | Militare, tecnico, industriale | Military, Stealth, HamRadio, Wildfire |
| `"Courier"` | Retro tech, vintage computer | Retro80s |
| `"Georgia"` | Elegante, naturale, classico | VintageRadio, Aurora, Arctic |
| `"Menlo"` | Cyber, tech, moderno, hacker | Cyberpunk, Festival, Hacker |

### 8. Scegli Sound Pack

| Sound Pack | Vibrazione | Esempi |
|-----------|-----------|--------|
| `nil` | Silenzioso | Default, Ocean, Forest, Sunset, Midnight |
| `"morse"` | Militare, tattico | Military |
| `"synth"` | Retrowave, synthwave | Retro80s |
| `"glitch"` | Cyberpunk, digitale, hacker | Cyberpunk, Hacker |
| `"sonar"` | Subacqueo, radar, sonar | Submarine |
| `"radio"` | Radioamatore, vintage | HamRadio |

### 9. Scegli Card Style

| Style | Quando usarlo |
|-------|--------------|
| `.flat` | Temi minimal, militari, stealth, hacker (nessuna ombra) |
| `.elevated` | Default, temi naturali, caldi, vintage (ombra standard) |
| `.cyber` | Temi "vetro", scifi, cyber, notturni (stroke + gradiente verticale) |

## Vincoli Tecnici

- Colori in `Color(red:green:blue:)` con valori 0-1 Double (mai hex)
- `Color.white.opacity(0.65)` per textSecondary default
- `accentGlow` sempre `accentColor.opacity(X)` dove X è 0.14-0.26
- Per `.gradient`: gradientTop = backgroundPrimary scurito, gradientBottom = surfaceColor
- GPU shader: solo per `backgroundStyle == .animated`

## Design Review Checklist

Prima di finalizzare un tema, verifica:

- [ ] Accent color: abbastanza saturo da emergere sullo sfondo scuro?
- [ ] Testo primario: abbastanza chiaro? (≥ 0.88 bianco o equivalente)
- [ ] Testo secondario: contrasto sufficiente? (~65% del primario)
- [ ] Glow: opacità nella finestra 0.14-0.26? (non sparire, non abbagliare)
- [ ] Icona: rappresenta il tema? (non mettere `flame.fill` su un tema artico)
- [ ] Font: coerente con la personalità? (non mettere Menlo su un tema vintage)
- [ ] Sound: se presente, ha senso col tema? (non mettere morse su festival)
- [ ] Card style: matcha la vibrazione? (non mettere flat su un tema festivo)

Questi controlli possono essere delegati a `frontend-design-open` per una revisione esterna.
