## ⚠️ Stazione saltata

| Campo | Valore |
|-------|--------|
| Nome | Radio Fantasma |
| Paese | Italia |
| Frequenza | — |
| URL | `https://questa-url-non-esiste-proprio.niente/live` |
| Genere | Pop |

### 🔍 Risultato verifica curl

```bash
$ curl -I --max-time 5 -L "https://questa-url-non-esiste-proprio.niente/live" 2>&1
curl: (6) Could not resolve host: questa-url-non-esiste-proprio.niente
```

### ❌ Decisione: NON aggiungere

La stazione **Radio Fantasma** NON è stata aggiunta.

### Motivo del rifiuto

Il dominio `questa-url-non-esiste-proprio.niente` non esiste — DNS resolution failed (errore curl 6). Nessuna connessione TCP è stata stabilita, quindi non è stato possibile ottenere né uno status HTTP né un Content-Type.

Secondo i criteri di accettazione della skill:
- ❌ HTTP status: assente (nessuna risposta)
- ❌ `Content-Type`: assente (nessuna risposta)
- ❌ Tempo di risposta: DNS non risolto entro 5 secondi

La skill impone: *"Se un URL non supera → comunica all'utente che la stazione è stata SALTATA con il motivo. Non aggiungere stazioni con URL non verificati."*
