# Talky come client della Free Radio Network (FRN)

Ricerca del 9 novembre 2026. Solo ricerca e lettura di pagine web: nessun contatto con nessuno, nessuna connessione ai server FRN.

## In breve

- La rete e' viva nel 2026, ma oggi la tiene in piedi **una sola persona**: Dirk Rasmussen (Bad Neuenahr-Ahrweiler, Germania), che gestisce il "sistema DE" su freeradionetwork.de. Il fondatore, Edwin PA7FRN (Paesi Bassi), dall'8 agosto 2024 ha spento il suo SystemManager e lo ha rediretto su quello di Dirk.
- Il protocollo e' pubblicato a grandi linee dal fondatore ("aperto a ogni sviluppatore che voglia scrivere un client FRN"), e ci sono implementazioni open source da cui ricavare i dettagli (SvxLink in C++, Freakin' per Android, frn-py, Net::FRN).
- **Non esiste un client per iPhone, iPad o Mac.** Il client Java di Dirk dice espressamente "macOS non ancora supportato", il suo GRNClient e' solo Android. Talky sarebbe il primo.
- Il rischio vero non e' tecnico: e' che Dirk a dicembre 2025 ha pensato di chiudere tutto per il peso del supporto agli utenti, e blocca le versioni vecchie dei client. Un'app iOS che porta utenti nuovi senza il suo consenso puo' essere bloccata in un attimo, o peggio fargli perdere la pazienza. Il permesso va chiesto a lui, prima di scrivere codice.

---

## 1. Chi gestisce FRN oggi e stato della rete

### Le persone

| Chi | Ruolo | Fonte |
|---|---|---|
| **Edwin, PA7FRN** (Paesi Bassi) | Ha creato FRN (client, server e SystemManager originali, "sistema EU"). Il cognome non e' pubblicato. | [de.wikipedia, Free Radio Network](https://de.wikipedia.org/wiki/Free_Radio_Network); [Funkamateur 3/2025, p. 244](https://freeradionetwork.de/assets/files/Funkamateur_2025_03_S44.pdf) |
| **Dirk Rasmussen** (Unterstr. 13, 53474 Bad Neuenahr-Ahrweiler, DE) | Gestisce il "sistema alternativo DE" (SystemManager riscritto in Java dal 2016-2017, database utenti suo), il sito freeradionetwork.de, e ha scritto i nuovi programmi: Java FRN_Client, FRN_Server, FRN_Crosslink, GRNClient per Android. Oggi e' di fatto il gestore della rete. | [Impressum](https://freeradionetwork.de/impressum.html); [home DE](https://freeradionetwork.de/); [GRNClient](https://freeradionetwork.de/grnclient.html) |
| **Valerij Savchuk** (Russia) | Autore di FRNClientConsole e della suite AlterFRN (client e server), usata dentro il client Java di Dirk; nel 2022 ha avviato un SystemManager russo separato (`sysman.lpd-net.ru:10025`). | [Funkamateur 3/2025](https://freeradionetwork.de/assets/files/Funkamateur_2025_03_S44.pdf); [forum, "One more FRN System manager"](http://www.radiohobby.nl/viewtopic.php?f=24&t=3819) |

Nota: il manuale dell'EU e il protocollo non citano nessun nome ne' email. Lo dice [Funkamateur 3/2025](https://freeradionetwork.de/assets/files/Funkamateur_2025_03_S44.pdf): "Am 8. August 2024 hat Edwin als Betreiber des Original-FRN-Systems (EU) die Internetadresse seines Systemmanager-Servers, der seitdem offline ist, auf die Internetadresse des Systemmanager-Servers des alternativen FRN-Systems (DE) umgeleitet." Confermato dalla [home di freeradionetwork.de](https://freeradionetwork.de/).

### Siti, server di sistema, contatti

- Sito originale (fermo, fa da archivio): https://freeradionetwork.eu . Ultimi programmi scaricabili: FRN Client 2014 [003], FRN Server 2014 [004] ([downloads](https://freeradionetwork.eu/downloads.htm)). Il link al client Android punta a gnuradionetwork.org, dominio oggi parcheggiato (redirect a ww1., connessione rifiutata).
- Sito attivo: https://freeradionetwork.de (build del sito 2026.11.07, cioe' aggiornato due giorni fa).
- SystemManager:
  - `sysman.freeradionetwork.de:10025` (primario);
  - `sysman.freeradionetwork.eu:10025` (dal 2024 rimanda al DE);
  - `sysman.lpd-net.ru:10025` (rete russa indipendente).
  Fonte: [PP5PK/FRNServer, sezione FRN System Managers](https://github.com/PP5PK/FRNServer); [ModuleFrn.conf](https://manpages.ubuntu.com/manpages/noble/man5/ModuleFrn.conf.5.html); [forum](http://www.radiohobby.nl/viewtopic.php?f=24&t=3819).
- Contatti:
  - modulo di contatto: https://freeradionetwork.de/kontakt.html (nessuna email pubblicata sulla pagina; chiede software, versione, sistema operativo, identificativo FRN) ([kontakt](https://freeradionetwork.de/kontakt.html));
  - `helpdesk@freeradionetwork.de`, citata solo per lo sblocco degli account bloccati ([please_read](https://freeradionetwork.de/please_read.html));
  - forum storico: http://www.radiohobby.nl/viewforum.php?f=42 , quasi fermo (ultimo messaggio in "FRN Algemeen" del 5/11/2022, in "FRN Hardware" del 21/11/2024) ([forum](http://www.radiohobby.nl/viewforum.php?f=42));
  - il gruppo Facebook e' stato chiuso il 7/11/2026 ([news](https://freeradionetwork.de/news.html));
  - c'e' un assistente di supporto con IA dal 17/8/2026 ([news](https://freeradionetwork.de/news.html)).

### E' attiva nel 2026? Si'.

Dalla [pagina news](https://freeradionetwork.de/news.html), solo nel 2026:
- Java FRN_Server da 4.12.0 (3/2) a 4.15.0 (13/8); Java FRN_Client 5.03.2-5.04.0 (ultima il 25/10/2026);
- GRNClient Android 6.00.4 (23/1), 6.00.5 (9/3), 6.01.1 (8/6), solo Android 14 e successivi;
- guasti DNS e manutenzioni del SystemManager (26/1, 5-6/5, 17/10), segno che il servizio e' in uso;
- email di sistema nella lingua dell'utente secondo GeoIP: DE, AT, CH, ES, MX, PT, BR, IT, PL, FR (1/3), poi VE, PA, AR, NL, BE, DK, FI, SI, HU, GR, RU (3/3).

Segnali di fatica, sempre dalle [news](https://freeradionetwork.de/news.html):
- 11/12/2025: "Ich überlege mittlerweile ernsthaft das FRN System nach nunmehr fast 10 Jahren intensiver Fortentwicklung [...] abzuschalten" (stava pensando seriamente di spegnere il sistema DE/EU);
- 17/12/2025: resta acceso, ma "Ich werde mich aus dem tagtäglichen Endnutzer-Support ab jetzt deutlich zurückziehen!";
- 19/2/2026: il client Java non avra' piu' funzioni nuove (solo correzioni), per via del componente russo FRNClientConsole integrato;
- 29/9/2025: disturbi ripetuti al SystemManager da IP russi, con contromisure.

### Numeri

Non c'e' un conteggio ufficiale di utenti. Quello che si trova:
- **Server:** l'elenco statico sul sito EU ne conta circa 90 (69 nella prima parte e 21 nella seconda della pagina) ([gateway_network.php](https://freeradionetwork.eu/gateway_network.php)). Un sito tedesco parlava di "oltre 60 server nazionali e internazionali" ([cq.sk](https://cq.sk/en/free-radio-network)). Ogni server ha fino a 32 stanze ([ModuleFrn.conf](https://manpages.ubuntu.com/manpages/noble/man5/ModuleFrn.conf.5.html)).
- **Gateway radio:** l'elenco EU, fermo a una fotografia di inizio 2022 (data piu' recente "off line since 15-02-2022"), ne conta 414, di cui 275 accesi ([gateway_repeaters.php](https://freeradionetwork.eu/gateway_repeaters.php)). Il conteggio e' stato fatto a mano dallo strumento di lettura: va preso come ordine di grandezza.
- L'elenco vivo sta nel FRN Browser (https://tools.freeradionetwork.de:43448/FRN_Browser/), un'applicazione GWT che non si legge senza eseguirla: non l'ho misurato. Il dato vero si ottiene con il comando `SM` al SystemManager, che pero' significa collegarsi al loro server (non fatto, per la regola di questa ricerca).

---

## 2. Il protocollo e le implementazioni

### Documentazione

Il fondatore ha pubblicato una specifica "preliminare" ([frnprotocol.htm](https://freeradionetwork.eu/frnprotocol.htm)): "The protocol with version number 2012000 was the first to be open for every developer who would like to implement a FRN Client program". Versione corrente nel documento: 2014000. Il documento dice "The codec and audio format will be explained later", e non lo spiega mai.

Come funziona, unendo la specifica e il codice di SvxLink ([QsoFrn.h](https://github.com/sm0svx/svxlink/blob/master/src/svxlink/modules/frn/QsoFrn.h), [QsoFrn.cpp](https://github.com/sm0svx/svxlink/blob/master/src/svxlink/modules/frn/QsoFrn.cpp)):

- **Trasporto:** TCP in chiaro, nessuna cifratura. UDP non e' usato ([please_read](https://freeradionetwork.de/please_read.html)).
- **SystemManager** (porta 10025), comandi testuali:
  - `IG:` registrazione: nominativo e nome, email, banda/canale, descrizione, paese, citta'. Risposta `OK`: la password arriva per email.
  - `DP:` chiede una "password dinamica" partendo da email e password principale (consigliata al posto della principale).
  - `SM` restituisce l'albero server, stanze, client ("System explorer"), da interrogare circa una volta al minuto.
- **Login al server FRN:** una riga `CT:` con tag in stile XML:
  - `<VX>` versione, `<EA>` email, `<PW>` password, `<ON>` "NOMINATIVO, Nome", `<CL>` tipo client (0 crosslink, 1 gateway, 2 PC only);
  - `<BC>` banda/canale ("PC Only" per noi), `<DS>` descrizione, `<NN>` paese, `<CT>` citta', `<NT>` stanza.
  - Risposta: ultima versione rilasciata, poi livello di accesso (`OWNER`, `NETOWNER`, `ADMIN`, `OK`, `WRONG`, `BLOCK`).
- **Ciclo:** `P` (poll e keepalive, timer 5 s in SvxLink); il server risponde con un byte di tipo:
  - 0 idle, 1 "puoi trasmettere", 2 blocco voce, 3 lista client, 4 messaggio di testo;
  - 5-10: nomi delle stanze, elenchi admin, accessi, blocchi, silenziati, modalita' di accesso.
- **Trasmissione:** `TX0` chiede il turno, si aspetta il byte 1, poi `TX1` seguito da 325 byte di voce per pacchetto; al rilascio del PTT si svuota il buffer e si chiude.
- **Moderazione lato server:** blocca/sblocca, silenzia/riattiva, admin, liste di accesso e di trasmissione per stanza (`BC:`, `MC:`, `AA:`, `AT:` e altri).
- **Audio:** **GSM 06.10 in formato WAV49** (quello "Microsoft GSM"), 8 kHz mono. Ogni coppia di frame occupa 65 byte e un pacchetto ne contiene 5, cioe' 325 byte = 1600 campioni = 200 ms ([QsoFrn.h](https://github.com/sm0svx/svxlink/blob/master/src/svxlink/modules/frn/QsoFrn.h): `FRAME_COUNT = 5`, `GSM_FRAME_SIZE = 65 // WAV49 has 65`, `FRN_AUDIO_PACKET_SIZE = FRAME_COUNT*GSM_FRAME_SIZE`). Ritardo percepito circa 1 s ([cq.sk](https://cq.sk/en/free-radio-network)).
- **Password in chiaro sulla rete:** SvxLink la mette nel tag `<PW>` cosi' com'e', su TCP semplice. Lo dice anche il README di Freakin': "the FRN protocol IS NOT ENCRYPTED. This means that your password is transmitted in clear text" ([Freakin](https://github.com/TheMetallists/Freakin)).

### Implementazioni open source

| Progetto | Linguaggio | Licenza | Ultimo aggiornamento | Completezza | Codec | Autenticazione |
|---|---|---|---|---|---|---|
| [SvxLink ModuleFrn](https://github.com/sm0svx/svxlink/tree/master/src/svxlink/modules/frn) (modulo di sh123, 2014) | C++ | GPL v2 o successiva | mantenuto dentro SvxLink | Client completo per gateway: login, RX, TX, lista client, riconnessione con attesa crescente (5 s fino a 2 min, massimo 10 tentativi). Non fa la registrazione: la si fa a parte. Circa 1000 righe. | libgsm, WAV49 | `EMAIL_ADDRESS` e `DYN_PASSWORD` in configurazione ([ModuleFrn.conf](https://manpages.ubuntu.com/manpages/noble/man5/ModuleFrn.conf.5.html)); la registrazione si fa dal client desktop o con netcat verso `sysman.freeradionetwork.eu:10025` |
| [Freakin'](https://github.com/TheMetallists/Freakin) | Java e C++ (NDK), Android | il README dice GPL v3, ma nel repository non c'e' un file LICENSE | maggio 2025 | Client Android: FSClient, FSServer, vocoder GSM nativo, filtri audio | libgsm (JNI) | email e password nell'app, in chiaro |
| [frn-py](https://github.com/george-hopkins/frn-py) | Python | LGPL v3 | dicembre 2015, "Experimental" | Protocollo comune e SystemManager (dump e server finto), niente audio | n/d | n/d |
| [Net::FRN](https://metacpan.org/pod/Net::FRN) (Alexander Frolov) | Perl | non indicata | 0.06, luglio 2011 | client "fully functional"; server e auth server no | gestori onGSM e onPCM | parametri Callsign, Email, Password |
| [OpenRepeater MODULE_Free_Radio_Network](https://github.com/OpenRepeater/MODULE_Free_Radio_Network) | PHP | nessuna | 2019 | interfaccia di configurazione per SvxLink | n/d | n/d |

Programmi chiusi, non utilizzabili come codice:
- **GRNClient** (Android, Dirk Rasmussen, nato da GFRNClient 0.0c di Maurizio Porrato): "Diese Software ist NICHT Open Source!", con divieto di decompilare e di ridistribuire l'APK. Ha sostituito libgsm con un codec GSM in Java puro ([grnclient](https://freeradionetwork.de/grnclient.html)).
- **Java FRN_Client** di Dirk, basato su FRNClientConsole: download solo dal suo sito ([frn_client](https://freeradionetwork.de/frn_client.html)).
- **AlterFRN** di Valerij Savchuk: binari solo su http://alterfrn.ucoz.ru (oggi risponde 503) e in un [mirror archiviato](https://github.com/cjemorton/AlterFRN-Mirror).

Conseguenza per Talky: il codice SvxLink e' GPL e non va copiato in un'app chiusa sullo Store. Si scrive un'implementazione propria leggendo la specifica (e usando SvxLink solo come riferimento per capire il comportamento). Per il codec si usa **libgsm** (licenza permissiva della TU Berlin, Degener e Bormann, compatibile con lo Store) con l'opzione `GSM_OPT_WAV49`.

### Registrazione e regole sui nominativi (sistema DE)

Da [please_read](https://freeradionetwork.de/please_read.html):
- Identita' = nominativo + nome + email + password FRN. La password **non la sceglie l'utente**: la assegna il sistema e la manda per email (anche per recuperarla si ripete la richiesta con gli stessi dati).
- Niente email usa e getta. Nominativo+nome ed email devono essere unici; la stessa email con un altro nominativo sovrascrive l'account vecchio.
- Dal 1/1/2025, per le registrazioni nuove:
  - nominativo tutto maiuscolo, cifre, spazio, trattino o barra; niente nominativi di un solo carattere o solo numerici;
  - nome con le iniziali maiuscole;
  - niente `. , ; ! $ < >`; maiuscole e minuscole contano.
  - Forma finale: `"NOMINATIVO, Nome"`.
- Account cancellato dopo 6 mesi di inattivita' (2 mesi sul vecchio EU).
- Stessa identita' su due connessioni insieme: no, salvo su server diversi (dall'11/6/2023).
- Blocco automatico: oltre 50 connessioni fallite il client e' bloccato per 30 minuti; dopo 48 blocchi il blocco diventa permanente e si toglie solo su richiesta. Per Talky questo vuol dire: fermarsi su `WRONG` o `BLOCK`, mai riprovare in automatico con credenziali sbagliate.

---

## 3. Regole d'uso e client di terzi

- Il fondatore ha aperto il protocollo ai client di terzi nel 2012 ([frnprotocol.htm](https://freeradionetwork.eu/frnprotocol.htm)). Sul sito DE non ho trovato una regola scritta che vieti o ammetta i client di terzi, ne' una procedura per gli sviluppatori.
- **Client di terzi tollerati, di fatto:**
  - SvxLink e' in Debian e Ubuntu da anni ([manpage](https://manpages.ubuntu.com/manpages/noble/man5/ModuleFrn.conf.5.html));
  - AlterFRN e la rete russa convivono, e il FRN_Server di Dirk si collegava anche al SystemManager russo;
  - Dirk costruisce i suoi programmi sopra FRNClientConsole, un componente di terzi.
- **Casi di blocco:**
  - dal 1/2/2025 Dirk blocca l'accesso alle versioni troppo vecchie del suo client Java ("ist der Zugang zum FRN System für stark veraltete Installationen meines Java FRN_Client ab heute gesperrt!") ([news](https://freeradionetwork.de/news.html));
  - contromisure contro il traffico anomalo da IP russi (29/9/2025);
  - nel 2026 ha chiuso lo sviluppo del client Java proprio per il componente russo.
  Quindi blocca in base alla versione e all'origine: un client nuovo dipende dalla sua tolleranza.
- **Regole d'uso** ([manuale client EU](https://freeradionetwork.eu/frn_client_user_manual.htm)):
  - "Do not use abusive language and do not block the network";
  - "If we catch you misbehaving, your account will be blocked";
  - i gateway devono usare CTCSS o DCS e solo apparati legali nel proprio paese.
- **Germania:** dal 1/10/2025 sono vietati i gateway con apparati Freenet, e dal dicembre 2025 anche quelli PMR 446 ([news](https://freeradionetwork.de/news.html); [Funkamateur 3/2025](https://freeradionetwork.de/assets/files/Funkamateur_2025_03_S44.pdf)). Talky deve presentarsi solo come **"PC Only" (CL=2)**, mai come gateway o crosslink.
- **Per l'App Store** (linea guida 1.2 sui contenuti degli utenti):
  - servono segnalazione e blocco degli utenti dentro l'app;
  - la moderazione la fanno i proprietari delle stanze con i comandi del protocollo, come nella decisione del 9/11/2026 sui Mumble pubblici.
- **Da chiedere a Dirk** (sono i punti della bozza):
  - quale stringa di versione `VX` usare, e se vuole un identificativo che distingua Talky;
  - se la registrazione si puo' fare dall'app (comando `IG:`);
  - quanto spesso interrogare il SystemManager;
  - chi da' supporto agli utenti iPhone. La risposta da offrire: Andrea, cosi' Dirk non ha carico in piu'.

---

## 4. Pubblico e paesi

- Pubblico: appassionati di CB, PMR 446, LPD/SRD, Freenet, FRS, e ormai anche radioamatori; utenti da PC e gateway verso radio vere ([de.wikipedia](https://de.wikipedia.org/wiki/Free_Radio_Network); [Funkamateur](https://freeradionetwork.de/assets/files/Funkamateur_2025_03_S44.pdf)). Anche protezione civile: un admin di "FRN ITALY" nel 2022 scriveva "we use that system for civil protection comunication also" ([forum](http://www.radiohobby.nl/viewtopic.php?f=24&t=3820)).
- Gateway per paese (fotografia EU di inizio 2022, conteggio a mano, [gateway_repeaters.php](https://freeradionetwork.eu/gateway_repeaters.php)):

| Paese | Gateway (accesi) |
|---|---|
| Polonia | 131 (92) |
| Spagna | 64 (45) |
| Germania | 60 (39), oggi probabilmente meno per i divieti del 2025 |
| Italia | 42 (26) |
| Russia | 33 (20) |
| Portogallo | 15 (12) |
| Grecia, Regno Unito | 11 ciascuno |
| Austria, Svizzera, Ungheria, Messico | da 5 a 9 |
| USA | 1 (1) |

- Stanze e server per le lingue che ci interessano ([gateway_network.php](https://freeradionetwork.eu/gateway_network.php), elenco statico):
  - **Italia:**
    - `freeitalyvoip.ddns.net` (stanza "Free Italy Voip");
    - `italyfreegroup.ddns.net` ("Ham Radio", "Stanza Italia");
    - `pmrcbitalia.ddns.net` ("Italia");
    - `master.srservice.it` ("Italiano").
  - **Germania:**
    - `deutschlandservers.de` ("German"); `funknetzdeutschland.ddns.net` ("Cb-Funk", "Pmr-Freenet");
    - `bayernfunk.com`, `frn.fun-funk.net`, `stuttgart-frn.leitungsen.de`, `voice.frn-mittelsachsen.de`, `straubing-funk.de` e altri;
    - in Svizzera `frn.wasnlos.ch` ("Deutsch").
  - **Spagna:**
    - `1a-funkfeuer.org` ("Conferencias Spain"); `bandaciudadana.sytes.net` ("Sala Cb");
    - `laradiocb.sytes.net` ("Laradiocb 27mhz"); `spainhamradio.ddns.net` ("Cb-Pmr");
    - `radiodemadrid.no-ip.org` ("Pmr"); `romeodeltaoscar.ddns.net` ("Galicia").
  - **USA:** solo `cb27usa.ddns.net` ("Cb Radio"). Gli Stati Uniti sono quasi assenti.
  - **Inglese:** `001english-eu.ddns.net` ("English"), `voip.freeradionetwork.nl` ("World").
  - **Brasile:** server "Brazil" su AlterFRN ([PP5PK/FRNServer](https://github.com/PP5PK/FRNServer)).
- Attenzione: l'elenco e' statico e vecchio. Quali di queste stanze sono vive oggi si vede solo dal SystemManager o dal FRN Browser.

---

## 5. Valutazione per Talky

**Ha senso?** Si', con il permesso. E' l'unica rete vocale pensata proprio per CB e PMR senza patente, ha stanze in italiano e spagnolo, e su iPhone, iPad e Mac non c'e' nessun client. Dentro Talky si lega bene al canale CB (dalla stanza "Cb" alla radio vera, attraverso i gateway). Limiti:
- pubblico di nicchia e anziano;
- USA quasi assenti;
- in Germania i gateway sono in calo per legge;
- la qualita' audio e' quella del GSM a 8 kHz (voce "da telefono vecchio") con circa un secondo di ritardo.

**Rischio principale:**
- la rete dipende da una persona stanca del supporto, che blocca i client per versione;
- se Talky porta centinaia di utenti iPhone che sbagliano registrazione o maiuscole, il carico finisce su di lui, e lui puo' bloccare Talky o chiudere la rete;
- secondo rischio, tecnico: la password viaggia in chiaro (va scritto nell'app e nella privacy policy).

**Quanto codice:** un client "PC Only" in Swift, scritto da zero, circa 1500-2500 righe, piu' libgsm (C, circa 6000 righe gia' scritte da includere). I pezzi:
- connessione TCP con Network.framework e macchina a stati del protocollo (login, poll, RX, TX, lista client, messaggi): circa 600-900 righe;
- SystemManager (registrazione `IG:`, password dinamica `DP:`, elenco `SM`): circa 200-300 righe;
- audio: AVAudioEngine a 48 kHz, conversione a 8 kHz, GSM WAV49 in pacchetti da 200 ms, buffer anti-scatti in ricezione: circa 300-400 righe;
- interfaccia: elenco server e stanze, registrazione guidata con controllo del formato del nominativo, PTT, chi parla, segnala/blocca: circa 500-800 righe.

Tempo indicativo: 1-2 settimane di lavoro, prove di Andrea escluse.

**A chi mandare la bozza:** a **Dirk Rasmussen** tramite il modulo https://freeradionetwork.de/kontakt.html (e' l'unico canale pubblicato; `helpdesk@freeradionetwork.de` e' indicata solo per gli sblocchi). Il suo sito e' in tedesco: conviene incollare il testo tedesco con l'inglese sotto. Edwin PA7FRN non serve: il suo sistema e' spento e rediretto. Nessuna email e' stata mandata.

---

## 6. Bozza dell'email

### Versione inglese (da mandare)

**Subject:** Talky for iPhone and Mac: may I add an FRN client?

Hello Dirk,

My name is Andrea Piani. I am an independent developer.

I make Talky, a walkie talkie and radio scanner app on the App Store for iPhone, iPad and Mac. Many of its users love CB and PMR, and FRN is the network made for them.

I would like to add FRN to Talky, as a simple "PC Only" client. As far as I know there is no FRN client for iOS or macOS yet.

Before I write any code, I want to ask you if this is welcome, and on which conditions.

If you agree, I would:
- follow your registration rules (callsign and name format, real email, password assigned by the system);
- connect only as "PC Only", never as a gateway or crosslink;
- use the protocol version and client identification you tell me, and update when you ask;
- stop on WRONG or BLOCK, and never retry with wrong credentials;
- keep polling of the System Manager low;
- show your rules and a link to your site inside the app;
- answer the support questions of Talky users myself, so they do not reach you.

A few questions:
1. Is a third party client for iPhone and Mac acceptable to you?
2. Which version string (VX) should Talky send? Would you like a distinct client name?
3. May the app send the registration request (IG:) itself, or should users register with your tools?
4. Is there anything else you want me to respect?

If you prefer that I do not do it, I will respect that.

Thank you for keeping FRN alive all these years.

Best regards,
Andrea Piani · andreapiani.dev@gmail.com · https://www.andreapiani.com

### Versione tedesca (da incollare sopra l'inglese nel modulo, se si vuole)

**Betreff:** Talky für iPhone und Mac: darf ich einen FRN Client einbauen?

Hallo Dirk,

mein Name ist Andrea Piani. Ich bin unabhängiger Entwickler.

Ich entwickle Talky, eine Walkie-Talkie- und Funkscanner-App im App Store für iPhone, iPad und Mac. Viele Nutzer sind CB- und PMR-Fans, und FRN ist das Netz für genau diese Leute.

Ich möchte FRN in Talky einbauen, als einfachen "PC Only" Client. Soweit ich weiß, gibt es noch keinen FRN Client für iOS oder macOS.

Bevor ich Code schreibe, frage ich dich: Ist das erwünscht, und zu welchen Bedingungen?

Wenn du einverstanden bist, würde ich:
- deine Registrierungsregeln einhalten (Format von Rufzeichen und Name, echte E-Mail, vom System vergebenes Passwort);
- nur als "PC Only" verbinden, nie als Gateway oder Crosslink;
- die Protokollversion und Client-Kennung nutzen, die du mir nennst, und auf Wunsch aktualisieren;
- bei WRONG oder BLOCK aufhören und nie mit falschen Daten neu verbinden;
- den System Manager nur selten abfragen;
- deine Regeln und einen Link zu deiner Seite in der App zeigen;
- den Support für Talky-Nutzer selbst übernehmen, damit nichts bei dir landet.

Ein paar Fragen:
1. Ist ein Client von Dritten für iPhone und Mac für dich in Ordnung?
2. Welche Versionskennung (VX) soll Talky senden? Möchtest du einen eigenen Client-Namen?
3. Darf die App die Registrierung (IG:) selbst senden, oder sollen sich Nutzer mit deinen Programmen registrieren?
4. Gibt es noch etwas, das ich beachten soll?

Wenn du lieber nicht möchtest, respektiere ich das.

Danke, dass du FRN all die Jahre am Leben hältst.

Viele Grüße,
Andrea Piani · andreapiani.dev@gmail.com · https://www.andreapiani.com

### Versione italiana (per Andrea, stesso contenuto)

**Oggetto:** Talky per iPhone e Mac: posso aggiungere un client FRN?

Ciao Dirk,

mi chiamo Andrea Piani e sono uno sviluppatore indipendente.

Faccio Talky, un'app walkie talkie e scanner radio su App Store per iPhone, iPad e Mac. Molti dei suoi utenti sono appassionati di CB e PMR, e FRN e' la rete nata per loro.

Vorrei aggiungere FRN a Talky, come semplice client "PC Only". Per quanto ne so, non esiste ancora un client FRN per iOS o macOS.

Prima di scrivere codice ti chiedo se e' gradito, e a quali condizioni.

Se sei d'accordo, io:
- rispetterei le tue regole di registrazione (formato di nominativo e nome, email vera, password assegnata dal sistema);
- mi collegherei solo come "PC Only", mai come gateway o crosslink;
- userei la versione del protocollo e l'identificativo del client che mi indichi, aggiornandoli quando lo chiedi;
- mi fermerei su WRONG o BLOCK, senza mai riprovare con credenziali sbagliate;
- interrogherei il System Manager il meno possibile;
- mostrerei nell'app le tue regole e un collegamento al tuo sito;
- risponderei io alle domande di assistenza degli utenti Talky, cosi' non arrivano a te.

Qualche domanda:
1. Un client di terzi per iPhone e Mac per te va bene?
2. Che stringa di versione (VX) deve mandare Talky? Vuoi un nome di client distinto?
3. L'app puo' mandare da sola la richiesta di registrazione (IG:), o gli utenti devono registrarsi con i tuoi programmi?
4. C'e' altro che vuoi che rispetti?

Se preferisci di no, lo rispetto.

Grazie per tenere viva FRN da tutti questi anni.

Un saluto,
Andrea Piani · andreapiani.dev@gmail.com · https://www.andreapiani.com

---

## Cosa non ho potuto verificare

- Numero di utenti e stanze vive oggi: servirebbe il comando `SM` al SystemManager o il FRN Browser eseguito in un browser. Non l'ho fatto.
- Se Dirk abbia mai detto pubblicamente si' o no a un client iOS: nelle news e nelle pagine lette non c'e' niente su iOS, iPhone o Apple.
- La specifica del sistema DE potrebbe differire dalla 2014000 pubblicata da Edwin. Le news del 2025 parlano di un "cambio di protocollo" sul sistema russo, e la 4.14.0 del server di Dirk ha rifatto la gestione delle richieste di connessione. Va chiesto a lui.
