//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - plan.md

# Piano di Sviluppo WalkieTalkie

## To Do
- [ ] Testare la stabilità della trasmissione audio dopo le modifiche
- [ ] Ottimizzare la qualità audio e ridurre la latenza
- [ ] Implementare indicatori visivi per lo stato della connessione
- [ ] Aggiungere gestione errori più dettagliata per l'utente

## Done
- [x] Risolto errore `AVAudioEngine` startup (codice 2003329396) in `MultipeerManager.swift`
  - Rimossa connessione diretta tra `inputNode` e `mainMixerNode` in `setupAudio()`
  - Aggiunto `audioEngine.prepare()` prima di `audioEngine.start()` in `startTransmitting()`
- [x] Risolto crash "Failed to create tap due to format mismatch" in `MultipeerManager.swift`
  - Utilizzato formato nativo dell'input node direttamente invece di formato standardizzato
  - Semplificato `accumulateAudioDataWithConversion()` rimuovendo conversioni non necessarie
- [x] Risolto errore hardware audio (errore -10868) in `MultipeerManager.swift`
  - Aggiunta configurazione parametri audio specifici in `setupAudio()` (sample rate, canali, buffer)
  - Implementata strategia di ricreazione completa dell'audio engine in `startTransmitting()`
  - Aggiunta gestione robusta del reset della sessione audio con pause temporali
  - Risolti errori di compilazione con gestione corretta delle variabili audioEngine

## Notes
- Decisione: Utilizzare ricreazione completa dell'audio engine invece di riutilizzo per evitare problemi di stato
- Problema risolto: L'errore -10868 era causato da conflitti tra formato hardware e configurazione dell'audio engine
- Strategia: Reset completo della sessione audio con pause temporali per permettere la riconfigurazione hardware