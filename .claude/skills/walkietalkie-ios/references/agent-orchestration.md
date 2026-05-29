# Orchestrazione Agenti e Skill Superpowers

Questa skill conosce e può richiamare le skill del sistema superpowers. Ecco quando e come usarle.

---

## Skill Disponibili e Quando Triggerarle

| Skill | Quando Usarla |
|---|---|
| **brainstorming** | Prima di qualsiasi lavoro creativo: nuove feature, refactor, design UI. Esplora intent, requisiti, e design prima di scrivere codice. |
| **dispatching-parallel-agents** | Quando hai 2+ task indipendenti (es. aggiungere radio E fixare un bug audio E aggiornare UI). Senza shared state. |
| **subagent-driven-development** | Per eseguire piani di implementazione con task indipendenti nella sessione corrente. |
| **writing-plans** | Prima di toccare codice per task multi-step: definisci spec, requirement, e piano prima di implementare. |
| **executing-plans** | Per eseguire un piano scritto in una sessione separata con review checkpoints. |
| **test-driven-development** | Per implementare feature/fix con test-first. Nota: il progetto non ha test esistenti. |
| **systematic-debugging** | Per bug complessi, crash, comportamenti inaspettati. Segui il processo strutturato prima di proporre fix. |
| **finishing-a-development-branch** | Quando l'implementazione è completa e devi decidere come integrare (merge, PR, cleanup). |
| **requesting-code-review** | Quando completi feature complesse o prima di mergiare. |
| **receiving-code-review** | Quando ricevi feedback su una code review. |
| **verification-before-completion** | Quando stai per dichiarare il lavoro completo. Esegui comandi di verifica prima di affermare successo. |
| **using-git-worktrees** | Per isolare feature work dalla workspace corrente. |
| **using-superpowers** | All'inizio di ogni conversazione — stabilisce come trovare e usare le skill. |

---

## Quando Orchestrate Agenti Paralleli

### Scenario 1: Aggiungere Molte Stazioni Radio

Se l'utente chiede "aggiungi 20 stazioni radio di vari paesi":
1. **Carica `writing-plans`** per strutturare il piano
2. **Carica `dispatching-parallel-agents`** per dividere il lavoro
3. Dividi per paese: ogni agente verifica e aggiunge le stazioni di un paese
4. Ogni agente legge `references/radio-system.md` per la procedura di verifica
5. Assicurati che gli ID non confliggano (assegna range: agente1=311-320, agente2=321-330, etc.)
6. Ogni agente modifica solo la sua sezione di `RadioManager.swift`

### Scenario 2: Refactor Multi-Modulo

Se il refactor tocca IAP + Theme + Ads (moduli indipendenti):
1. **Carica `writing-plans`** per il piano
2. **Carica `dispatching-parallel-agents`**
3. Agente 1: IAPManager + PaywallView
4. Agente 2: Theme system (ThemeManager, packs, views)
5. Agente 3: AdManager + ConsentManager
6. Ogni agente lavora indipendentemente, merge finale manuale

### Scenario 3: Nuova Feature Completa

Esempio: "aggiungi Apple Watch companion app":
1. **Carica `brainstorming`** — esplora requisiti, vincoli watchOS
2. **Carica `writing-plans`** — scrivi specifica e piano
3. **Carica `subagent-driven-development`** — esegui il piano con checkpoint
4. Durante l'esecuzione, usa `dispatching-parallel-agents` per parti indipendenti

---

## Pattern di Task Typici per Questo Progetto

### Task Semplice (1 file)
```
Non serve orchestrazione. Modifica diretta + build verification.
```

### Task Medio (2-4 file correlati)
```
1. Leggi i riferimenti pertinenti
2. Modifica i file sequenzialmente (controlla le dipendenze)
3. Build verification su entrambi i target
```

### Task Complesso (5+ file, moduli multipli)
```
1. Carica brainstorming e/o writing-plans
2. Definisci il piano con task indipendenti
3. Dispatcha agenti paralleli con dispatching-parallel-agents
4. Ogni agente ha il proprio reference file dalla skill
5. Merge e verifica con verification-before-completion
```

### Task di Debug
```
1. Carica systematic-debugging
2. Non proporre fix prima di capire la root cause
3. Verifica con build dopo la fix
```

---

## Convenzioni per Agenti Paralleli

Quando dispatci agenti paralleli per questo progetto, includi sempre nel prompt:

1. **Il path corretto del progetto** — usa la working directory corrente (opencode la passa automaticamente agli agenti). Non hardcodare path assoluti.

2. **Il file di riferimento pertinente** da questa skill:
   ```
   Leggi prima .opencode/skills/walkietalkie-ios/references/<file>.md
   ```

3. **Vincoli specifici del task** (es. "usa isPro esplicito", "non cambiare gli ID esistenti", "mantieni lo stile del codice esistente")

4. **Il comando di verifica** da eseguire dopo le modifiche

---

## Comunicazione tra Agenti

Gli agenti NON condividono stato. Se un agente ha bisogno di output di un altro:
- L'agente 1 scrive un file di output (o modifica il codice) e restituisce un summary
- Tu leggi il summary e lo passi all'agente 2 come input nel suo prompt

---

## Debugging con Agenti

Per bug complessi:
1. Un agente investiga la root cause (legge log, riproduce il bug, analizza il codice)
2. Tu valuti il report
3. Un secondo agente implementa la fix basata sul report
4. Build verification

Questo pattern è più efficace che cercare di fixare e investigare nello stesso contesto.
