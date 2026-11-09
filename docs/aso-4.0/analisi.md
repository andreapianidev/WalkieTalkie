# Talky 4.0, analisi ASO e scelta dei nomi

Misure del 9 novembre 2026, app 6748584483 (iOS e Mac, stessa scheda). Fonti: iTunes Search API (primi 200 risultati, posizione del trackId), suggerimenti di ricerca dell'App Store (MZSearchHints, con lo strumento `aso.py`), Google Trends (connettore keyword-suggest), App Store Connect in sola lettura. Nessuna scrittura su ASC.

Lo storico grezzo e' in `/Users/andreapiani/Prototipi/aso-expert/storico/talky-tutti-2026-11-09.json`: e' la base da confrontare 7 e 28 giorni dopo l'uscita della 4.0.

## In breve

- **Il nome mette nel titolo il termine forte di ogni paese accanto a "Walkie Talkie"**, che resta dove porta gia' traffico (US, GB, CA, IT, DE, BR, ES, MX, TR, VN, ID, MY). Dove la gente cerca nella sua lingua (Giappone, Corea, Cina, Taiwan, Thailandia, Polonia) la parola locale va nel nome e "walkie talkie" scende nelle keyword o nel sottotitolo.
- **"CB Radio" entra nel nome in inglese**: in USA Talky e' 19a per "cb radio" (popolarita' 62) e chi sta davanti e' debole (CB TALK con 169 valutazioni). Nel titolo, nella forma esatta, e' il termine con piu' margine.
- **Tedesco: "Walkie Talkie" resta nel nome**, con CB-Funk accanto e Funkgerät nel sottotitolo. I numeri sono nella sezione dedicata.
- **Il collo di bottiglia vero resta il voto** (circa 2 stelle su 23 valutazioni, quasi tutte "non si collegano"). Le posizioni migliorano col titolo giusto, ma senza voto sopra 3,5 la conversione resta bassa: le 3 risposte alle recensioni e l'aiuto al collegamento della 4.0 contano quanto il nome.

## Come leggere i numeri

- **Posizione**: posto di Talky tra i primi 200 della iTunes Search API per quel termine e quel paese. Segue da vicino la ricerca vera ma non e' identica (la ricerca reale e' personalizzata e ha l'annuncio in testa). "oltre 200" vuol dire non trovata.
- **Popolarita'**: stima 0-100 dai suggerimenti di ricerca (dopo quante lettere il termine compare). **"1" non vuol dire che nessuno lo cerca**: vuol dire che i suggerimenti non lo propongono. Succede con i termini a due parole in ordine non abituale ("cb radio" in Italia, dove si scrive "radio cb") e soprattutto **in coreano, dove il metodo non funziona** (l'hangul si compone per sillabe e i prefissi non danno suggerimenti): per la Corea vale solo Google Trends.
- **Difficolta'**: 0-100 dai primi 10 risultati (valutazioni, termine nel titolo, voto). Sotto 40 si entra con il titolo.

## La scelta dei nomi, lingua per lingua

| Locale | Nome proposto | Car. | Perche' |
|---|---|---|---|
| en-US, en-GB, en-AU, en-CA | Talky: Walkie Talkie, CB Radio | 30 | US: walkie talkie 15a (pop 64, diff 81, leader con 93.000 valutazioni), cb radio 19a (pop 62, diff 51, leader con 169). GB cb radio 33a, CA 79a, AU 30a. Il termine CB ha leader deboli ovunque: e' quello che si guadagna mettendolo esatto nel titolo. Google US: ham radio 85, walkie talkie 82, cb radio 37 |
| it | Talky: Walkie Talkie, Radio CB | 30 | walkie talkie 12a (pop 70), radio cb 5a (pop 33); "cb radio" in Italia non e' suggerito, si cerca "radio cb". Google IT: walkie talkie 86, baracchino 40, radio cb 26 |
| de-DE | Talky: Walkie Talkie, CB-Funk | 29 | vedi sezione sul tedesco |
| fr-FR | Talky: Talkie-walkie, Radio CB | 30 | in Francia si scrive nei due ordini (Google 68 contro 68); con le due parole nel titolo Apple le combina in entrambi gli ordini. talkie walkie 10a, walkie talkie 12a, radio cb 11a |
| fr-CA | Talky: Walkie-talkie, Radio CB | 30 | in Quebec si dice walkie-talkie; la stessa scheda e' indicizzata anche in Canada insieme all'inglese |
| es-ES, es-MX | Talky: Walkie Talkie, Radio CB | 30 | ES walkie talkie 13a (pop 74), radio cb 10a; MX 17a e 10a. es-MX in piu' conta anche negli Stati Uniti |
| pt-BR | Talky: Walkie Talkie, Rádio PX | 30 | walkie talkie 12a (pop 76); "rádio px" con accento 3a, "radio px" senza accento 70a: Apple non li unisce, quindi "radio" senza accento va nelle keyword |
| ja | Talky トランシーバー・無線機・CB無線 | 22 | 無線機 pop 84, diff 19, Talky 10a solo dalle keyword: entra nel titolo. トランシーバー 15a (pop 70). cb無線 4a. "walkie talkie" in Giappone pop 54, 9a: resta indicizzato dalla scheda inglese |
| ko | Talky 무전기·워키토키·CB 라디오 | 21 | Google KR: 무전기 84 contro 워키토키 10. Talky 5a per 무전기 e 12a per 워키토키 dalle sole keyword (popolarita' App Store non misurabile in coreano) |
| zh-Hans | Talky 对讲机・无线电・CB 电台 | 19 | Cina: 对讲机 29a (pop 84, diff 62, leader forti), 无线电 non in classifica (pop 66, diff 23), 业余无线电 27a (pop 78). Il mercato cinese non e' tra i primi per download: e' un nome di presidio |
| zh-Hant | Talky 對講機・無線電・CB 電台 | 19 | Taiwan (274 download): 對講機 4a (pop 92), 無線電 3a (pop 84) gia' oggi; nel titolo puntano al podio. "walkie talkie" (pop 50, 5a) passa nelle keyword |
| th | Talky: วิทยุสื่อสาร, CB | 23 | วิทยุสื่อสาร 3a (pop 66); "walkie talkie" scritto in inglese e' molto cercato (pop 64, 13a) e va nel sottotitolo. "วอ" (pop 72) e' ambiguo, in testa ci sono app di pagamento: scartato |
| vi | Talky: Bộ đàm, Walkie Talkie | 28 | bộ đàm pop 60, diff 23, Talky 15a: nel titolo dovrebbe salire molto. Google VN: bộ đàm 78 contro walkie talkie 4,5 |
| tr | Talky: Telsiz, Walkie Talkie | 28 | telsiz pop 64, diff 37, ma Talky e' solo 132a; walkie talkie 11a. Google TR: telsiz 87 contro 2,5. E' il guadagno piu' grande tra le lingue gia' attive |
| ms (nuova) | Talky: Walkie Talkie, Radio CB | 30 | Malesia: walkie talkie 7a (pop 68), radio cb 9a |
| id (nuova) | Talky: Walkie Talkie, Radio HT | 30 | Indonesia: "ht" pop 82 (5a), "radio ht" 2a, handy talky 6a (pop 58). Con "Talky" nel nome e "handy" nelle keyword Apple puo' comporre "handy talky" |
| pl (nuova) | Talky: Krótkofalówka, CB Radio | 30 | Polonia: cb radio pop 88, diff 27, 18a; krótkofalówka 2a (pop 60). Google PL: cb radio 86, walkie talkie 48, krótkofalówka 33. walkie talkie (7a) va nel sottotitolo |

Il nome e il sottotitolo stanno in App Info e valgono per iPhone e Mac insieme: nel JSON sono ripetuti per piattaforma solo per comodita'.

## Il tedesco: "Walkie Talkie" nel nome si' o no?

**Si', resta.** Nome proposto `Talky: Walkie Talkie, CB-Funk` (29), sottotitolo `Funkgerät, Kurzwelle, Scanner` (29).

| Termine (DE) | Pop. App Store | Difficolta' | Talky oggi | Da dove arriva oggi | Google DE |
|---|---|---|---|---|---|
| walkie talkie | 72 | 60 | 18a | nome | 54,5 |
| funkgerät | 58 | 36 | 6a | solo keyword | 58,2 |
| cb funk | 78 | 24 | 11a | sottotitolo | 20,7 |
| cb radio | 64 | 30 | 17a | nome (Radio) + sottotitolo | n/d |
| kurzwelle | n/d | 13 | 10a | sottotitolo | n/d |
| amateurfunk | 58 | 33 | oltre 200 | keyword | n/d |
| sprechfunk | n/d | 49 | 30a | keyword | 5,1 |

Il ragionamento:
- La proposta `Talky: Funkgerät & CB-Funk` sposterebbe in alto due termini su cui Talky e' gia' 6a e 11a, ma toglierebbe dal titolo **il termine con piu' traffico misurato dopo cb funk** (walkie talkie, 72) su cui Talky e' 18a con concorrenti forti (ten ten 45.000 valutazioni, All Talk 5.000). Fuori dal titolo scenderebbe.
- Con `Walkie Talkie, CB-Funk` nel nome e `Funkgerät` nel sottotitolo **nessuno dei tre perde campo e due salgono**: cb funk passa da sottotitolo a titolo, funkgerät da keyword a sottotitolo. La versione senza Walkie Talkie fa salire gli stessi due, ma fa scendere il terzo.
- Su Google i due termini sono alla pari (58 contro 54,5): il dato non basta a togliere quello che oggi porta Talky in prima pagina.
- "CB-Funk" con il trattino viene gia' spezzato da Apple in "cb" e "funk" (oggi Talky e' 11a per "cb funk" con "CB-Funk" nel sottotitolo).
- C'era anche `Talky Funkgerät, Walkie Talkie` (30, senza i due punti): tiene i due termini piu' cercati ma lascia cb funk (78, difficolta' 24, il piu' facile da vincere) nel sottotitolo. E' l'alternativa valida se si vuole Funkgerät nel titolo; da rimisurare dopo 28 giorni.

Una cautela nel testo: nella descrizione tedesca la frase "Talky ist kein Funkgerät" sarebbe andata in contrasto con il nome. E' diventata "Talky sendet nicht selbst per Funk: Es spricht nicht mit PMR- oder CB-Funkgeräten".

## Sottotitoli e keyword

Regole seguite: nessuna parola del nome o del sottotitolo ripetuta nelle keyword (controllato da script, con normalizzazione), virgole senza spazi, niente nomi di concorrenti, niente "best/top/migliore", niente "app", "free", "gratis".

| Locale | Sottotitolo | Perche' |
|---|---|---|
| en-* | Ham, shortwave & SDR scanner | ham radio pop 52 (diff 44, Talky fuori dai 200), shortwave radio 42 (fuori), sdr 66 (81a): con "Radio" nel titolo Apple compone "ham radio" e "shortwave radio". In GB ham radio e' 54a con difficolta' 27 |
| it | Baracchino, onde corte, SDR | baracchino pop 62, diff 35, Talky 56a dalle sole keyword |
| de-DE | Funkgerät, Kurzwelle, Scanner | vedi sopra |
| fr-* | Radioamateur et ondes courtes | radioamateur pop 44, difficolta' 11, Talky 69a; ondes courtes gia' 3a |
| es-* | Radioaficionado y onda corta | radioaficionado pop 44, difficolta' 1, Talky 13a |
| pt-BR | Radinho, radioamador e HF | radinho pop 52 (14a), radioamador 44 (15a), difficolta' sotto 30 |
| ja | インカム・アマチュア無線・短波 | インカム pop 76 (fuori dai 200, diff 44, leader con 53 valutazioni), アマチュア無線 pop 76 (57a, diff 29) |
| ko | 아마추어 무선·단파 실시간 수신 | radioamatore e onde corte, in parole correnti |
| zh-Hans | 业余短波实时收听，免网络通话 | 业余 + 无线电 del nome compone 业余无线电 (pop 78, 27a) |
| zh-Hant | 業餘短波即時收聽，免網路通話 | 業餘無線電 5a, 短波 5a |
| th | Walkie Talkie ไม่ต้องใช้เน็ต | walkie talkie (pop 64) scritto in caratteri latini, come lo cercano in Thailandia |
| vi | Nghe CB, sóng ngắn trực tiếp | sóng ngắn oggi 132a |
| tr | Bas konuş, CB ve kısa dalga | bas konuş pop 52 (16a, diff 26); "amatör" nelle keyword con "Telsiz" del nome compone amatör telsiz (pop 60, 70a) |
| ms | Tanpa internet, amatur & HF | in Malesia i termini locali non sono suggeriti (pop 1): il sottotitolo dice il beneficio |
| id | Tanpa internet, CB, HF, SDR | con "Radio" del nome compone radio cb (9a) |
| pl | Walkie talkie bez internetu | walkie talkie pop 64, Talky 7a |

Scelte particolari nelle keyword:
- **en-GB, en-AU, en-CA** hanno "amateur" al posto di "kids": en-GB e' indicizzato anche in Italia, Germania, Francia e Spagna, dove "kids" in inglese non serve.
- **es-MX** porta tre parole inglesi (amateur, receiver, nearby) perche' negli Stati Uniti la scheda es-MX si somma a quella inglese.
- **zh-Hant** tiene "walkie,talkie" nelle keyword: a Taiwan Talky e' 5a per "walkie talkie" grazie al nome di oggi, e il nome nuovo non lo contiene piu'.
- **pt-BR** ha "radio" senza accento: "radio px" e' 70a, "rádio px" 3a.
- **ko** "생활무전기" e' una parola diversa da 무전기 del nome (radio PMR, Google 6,5).

## Gli altri testi

- **Descrizione**: parte dal walkie che funziona senza internet tra telefoni vicini (con l'aiuto al collegamento e l'invito), poi le stanze private, poi lo scanner CB/HF/POC con la novita' del parlare sul POC, poi la radio (335 stazioni da 80 paesi, conteggio da `statico.py` e da `RadioManager.swift`), widget e controlli, Pro (settimanale, annuale con prova, Lifetime), codice su GitHub, blocco legale. Su Mac la parte walkie dice rete locale, barra spaziatrice e niente pubblicita'.
- Le descrizioni iOS stanno tutte sotto 4.000 caratteri (le piu' lunghe sono fr-FR, fr-CA ed es-MX, fra 3.980 e 3.995 caratteri: c'e' poco margine per aggiunte); per starci in francese, tedesco e malese la riga "A schermo: spettro e cascata" e' tolta solo su iOS.
- **Blocco legale**: come oggi, link su `www.andreapiani.com/talky/` (in italiano `/talky/it/`, in spagnolo `/talky/es/`), non su `walkie-talky.vercel.app` come diceva il brief: quei due indirizzi oggi rispondono con un 308 verso le pagine su andreapiani.com, e la regola del 3 novembre vuole i link legali sul dominio nostro. Le pagine tradotte esistono solo in it ed es (verificato con curl: de e fr danno 404). Rispetto a oggi i titoli dei link sono tradotti anche in ja, ko, pt-BR e tr, che avevano "Terms of Use (EULA)" in inglese, e la frase sul rinnovo dice che Lifetime non si rinnova.
- **Testo promozionale**: apre con la novita' della 4.0 (stanze private), poi walkie e scanner. Si puo' cambiare anche a versione in revisione.
- **What's New**: 5 righe su iOS (stanze, POC, collegamento e invito, iPhone che trova il Mac, pubblicita' che sparisce con Pro e nell'ora senza annunci), 4 su Mac (stanze, POC dal Mac, interfaccia Mac in 14 lingue, iPhone che trova il Mac). Fuori dal testo e' rimasta la riga "Scrivimi dalle Impostazioni", che c'e' nel What's New oggi caricato: se Andrea la vuole, e' la sesta riga.

## Cose da sapere prima di applicare

1. **Lingue nuove senza schermate.** Le 8 lingue nuove (ms, es-MX, fr-CA, en-GB, en-AU, en-CA, id, pl) vanno create sia su iOS sia su Mac e hanno bisogno di schermate nella loro lingua prima dell'invio (regola del 3 novembre). Per id e pl l'app non e' ancora tradotta: o si aspetta la traduzione, o queste due lingue si aggiungono con la versione successiva. I nomi dei menu citati nelle descrizioni id e pl (Keamanan, Bezpieczeństwo) vanno allineati con la traduzione dell'app.
2. **Promozionale e What's New** si caricano nella versione; nome e sottotitolo in App Info `eed7fd32-37e0-4625-b2df-da37c73f16a3` (quella in PREPARE_FOR_SUBMISSION). Versioni 4.0: iOS `d70fc249-0d89-4815-8670-550834583531`, Mac `3f9c62cd-4b5f-4959-b08f-54dd63c21116`. Entrambe hanno gia' `releaseType: AFTER_APPROVAL`.
3. **Privacy URL** per le lingue nuove: en e le altre `/talky/privacy/`, es-MX `/talky/es/privacy/` (nel JSON c'e' il campo `privacyPolicyUrl`).
4. **Parole inglesi in titoli non inglesi**: "Walkie Talkie" in th, vi, tr, ms, id, pl e' il termine che la gente digita in quei paesi (misurato), non un pezzo di testo lasciato in inglese.
5. **Controllo a 7 e 28 giorni** dall'uscita: rilanciare `misura.py` (in questa cartella di lavoro) o `aso.py rank` sugli stessi termini e confrontarlo con lo storico. Non c'e' nessun controllo acceso che lo faccia da solo.

## Cosa non ho potuto misurare

- **La popolarita' vera di Apple Ads** (5-100): serve l'account Apple Ads, qui c'e' solo la stima dai suggerimenti.
- **La Corea**: i suggerimenti non funzionano con l'hangul, ho solo Google Trends e le posizioni.
- **Impressioni e conversione per paese** da App Store Connect Analytics: non lette in questo giro (servono i report Analytics, che vanno chiesti e arrivano il giorno dopo).
- **La posizione personalizzata** che vede un utente vero: l'API non ha annunci e non conosce la storia dell'utente.
- **L'effetto del nome nuovo**: si vede solo dopo l'uscita, a 7 e 28 giorni.

## I dati, paese per paese

Ordinati per download set-nov. "oltre 200" = Talky non e' tra i primi 200.

### Stati Uniti (US), download set-nov: 827

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 15 | 64 | 81 | Walkie Talkie - All Talk App (93178); Zello Walkie Talkie (35570); Walkie-Talkie - Friends Chat (1944) |
| cb radio | 19 | 62 | 51 | CB TALK (169); CB Radio Live (3); CitizenBand Radio (1) |
| walkie talkie offline | 14 | 32 | 52 | Walkie Talkie Offline (8); Walkie Talkie - All Talk App (93178); Zello Walkie Talkie (35570) |
| walkie talkie no internet | 28 | 1 | 53 | Zello Walkie Talkie (35571); Talk Hit! Walkie Talkie (5962); DirectTalk (Walkie Talkie P2P) (11) |
| ham radio | oltre 200 | 52 | 44 | SwR - Global Radio (8); HamSphere 5.0 (8); RepeaterBook (248) |
| shortwave radio | oltre 200 | 42 | 37 | Echo: Global SDR Receiver (36); SwR - Global Radio (8); Radio Garden Live (2313) |
| sdr | 81 | 66 | 47 | Echo: Global SDR Receiver (36); Spectral Bands: SDR Client (0); CoronaSDR: RTL-SDR Client (10) |
| push to talk | oltre 200 | 44 | 54 | Zello Walkie Talkie (35571); Verizon Push to Talk Plus (56); T-Mobile Direct Connect (45) |
| intercom | 169 | 42 | 56 | Intercom Conversations (173); Intercom App Type B (1425); Voice Intercom for Sonos (2080) |
| two way radio | oltre 200 | 46 | 41 | Two Way : Walkie Talkie (358); Zello Walkie Talkie (35570); Online Walkie Talkie Pro (742) |
| radio scanner | oltre 200 | 1 | 76 | Police Scanner Radio & Fire (538743); 5-0 Radio Pro Police Scanner (89851); Rdio Scanner (85) |
| internet radio | oltre 200 | 24 | 69 | TuneIn Radio: Music & Sports (1124898); Radio Online ManyFM (77); Internet Radio , Web Tuner (169) |
| ham | oltre 200 | 1 | 60 | H&M (244135); Ham Radio Toolbox (201); Ham (5) |
| shortwave | oltre 200 | 54 | 57 | ShortsWave: Watch Drama Series (31358); Shortwave - AI Email (757); Echo: Global SDR Receiver (36) |
| walkie talkie app | 15 | 1 | 70 | Zello Walkie Talkie (35571); Walkie Talkie - All Talk App (93183); Online Walkie Talkie Pro (742) |
| push to talk walkie talkie | 54 | 1 | 55 | Walkie Talkie - All Talk App (93183); Voxer Walkie Talkie Messenger (1827); Talk Hit! Walkie Talkie (5965) |

### Brasile (BR), download set-nov: 431

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 12 | 76 | 56 | Walkie Talkie Offline (18); Walkie Talkie - All Talk App (1910); Zello Walkie Talkie (6154) |
| radio px | 70 | 39 | 36 | Online Walkie Talkie Pro (83); Zello Walkie Talkie (6154); Online Walkie Talkie Lite (3) |
| rádio px | 3 | 39 | 45 | Online Walkie Talkie Pro (83); Zello Walkie Talkie (6154); Talky - Walkie Talkie, Radio (1) |
| cb radio | 18 | 1 | 28 | CB TALK (57); CB Radio 2015 (Light) (0); Police Scanner Radio & Fire (70) |
| radioamador | 15 | 44 | 19 | Online Walkie Talkie Pro (83); CB TALK (57); Zello Walkie Talkie (6154) |
| radinho | 14 | 52 | 27 | Online Walkie Talkie Pro (83); Walkie Talkie - All Talk App (1910); Zello Walkie Talkie (6154) |
| radio amador | 26 | 39 | 27 | Online Walkie Talkie Pro (83); CB TALK (57); Zello Walkie Talkie (6154) |

### Canada (CA), download set-nov: 318

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 8 | 64 | 61 | Walkie Talkie - All Talk App (6885); Zello Walkie Talkie (2106); ten ten - your friends, on tap (29491) |
| cb radio | 79 | 64 | 30 | CitizenBand Radio (0); CB TALK (17); CB Radio Live (0) |
| walkie talkie offline | 5 | 42 | 44 | Walkie Talkie Offline (4); Walkie Talkie - All Talk App (6885); Zello Walkie Talkie (2106) |
| talkie walkie | 10 | 1 | 51 | Walkie Talkie - All Talk App (6885); ten ten - your friends, on tap (29491); Talk Hit! Walkie Talkie (308) |

### Taiwan (TW), download set-nov: 274

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| 對講機 | 4 | 92 | 36 | Zello Walkie Talkie (5205); 對講機, 與您的朋友交談, 保持聯繫, 數字語音電台聊天 (123); 對話機-手機實時對講機 (0) |
| walkie talkie | 5 | 50 | 49 | Walkie Talkie - All Talk App (110); Zello Walkie Talkie (5205); 對講機, 與您的朋友交談, 保持聯繫, 數字語音電台聊天 (123) |
| cb電台 | oltre 200 | 1 | 0 | 警用电台直播扫描 (0) |
| 無線電 | 3 | 84 | 18 | Zello Walkie Talkie (5205); 對講機, 與您的朋友交談, 保持聯繫, 數字語音電台聊天 (123); Talky - Walkie Talkie, Radio (3) |
| 業餘無線電 | 5 | 1 | 17 | 字母業餘無線電 (0); 哈友会-业余无线电 (0); 业余无线电考试题库 (0) |
| 對講 | 42 | 80 | 55 | Zello Walkie Talkie (5205); 维迈通多多 - 摩托车对讲 (13); 對講機, 與您的朋友交談, 保持聯繫, 數字語音電台聊天 (123) |
| 短波 | 5 | 1 | 15 | SWAtlas - 短波探索器 (0); 哈友会-业余无线电 (0); 摩爾斯電碼的業餘無線電愛好者 (1) |

### Indonesia (ID), download set-nov: 219

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 7 | 66 | 51 | Walkie Talkie - All Talk App (928); Zello Walkie Talkie (669); Online Walkie Talkie Pro (21) |
| ht | 5 | 82 | 29 | HelloTalk - Language Learning (1713); Online Walkie Talkie Pro (21); Zello Walkie Talkie (669) |
| handy talky | 6 | 58 | 23 | Zello Walkie Talkie (669); Online Walkie Talkie Pro (21); Walkie Talkie - All Talk App (928) |
| radio ht | 2 | 39 | 34 | Online Walkie Talkie Pro (21); Talky - Walkie Talkie, Radio (0); Walkie Talkie - All Talk App (928) |
| radio cb | 9 | 1 | 23 | CB Radio 2015 (Light) (1); CB TALK (4); CB (0) |
| radio amatir | oltre 200 | 1 | 10 | Alphabet for ham radio (0); Morse code for ham radio (1); Robot72 - ISS SSTV Decoder (0) |
| walkie talkie offline | 53 | 46 | 26 | Walkie Talkie Offline (0); Zello Walkie Talkie (669); Walkie Talkie - All Talk App (928) |

### Francia (FR), download set-nov: 206

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| talkie walkie | 10 | 1 | 56 | Walkie Talkie - All Talk App (59131); ten ten - your friends, on tap (153556); Walkie Talkie Intercom App (126) |
| walkie talkie | 12 | 18 | 64 | Walkie Talkie - All Talk App (59131); Walkie Talkie Intercom App (126); Zello Talkie Walkie (1486) |
| radio cb | 11 | 33 | 29 | CB TALK (65); CB Radio 2015 (Light) (1); Online Walkie Talkie Pro (31) |
| cb radio | 16 | 1 | 36 | CB TALK (65); CB Radio Live (0); Police Scanner Radio & Fire (118) |
| cibi | oltre 200 | 1 | 20 | Services bancaires CIBC (10); CIB (3); Yuka - Scan de produits (296138) |
| radioamateur | 69 | 44 | 11 | Ham Mixer Mobile (0); HamQRG: Relais Radioamateurs (4); HamSphere 5.0 (0) |
| ondes courtes | 3 | 1 | 15 | UVB-76 : station ondes courtes (0); SWListener: Ondes Courtes (3); Talky - Walkie Talkie, Radio (1) |
| talkie walkie sans internet | oltre 200 | 1 | 11 | Money Walkie (9633); Interphone : parlez sans 5G (0); OSHI: Messagerie hors ligne (9) |

### Filippine (PH), download set-nov: 180

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 8 | 72 | 53 | Walkie Talkie - All Talk App (1990); buz - voice connects (6405); Walkie Talkie Intercom App (26) |
| radio | 12 | 68 | 81 | Radio Philippines - Live AM FM (32028); Radio App (432); Simple Radio: FM & AM Stations (4681) |
| cb radio | 13 | 1 | 23 | Police Scanner Radio & Fire (32); CB Radio Chat (0); CB Radio 2015 (Light) (0) |

### India (IN), download set-nov: 180

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 12 | 62 | 53 | Walkie Talkie - All Talk App (788); ten ten - your friends, on tap (33393); Walkie Talkie: Talk to Friends (13) |
| cb radio | 12 | 1 | 23 | Police Scanner Radio & Fire (20); CB Radio Chat (0); CB Radio 2015 (Light) (0) |
| walkie talkie offline | 24 | 42 | 37 | Walkie Talkie Offline (0); Walkie Talkie - All Talk App (788); ten ten - your friends, on tap (33393) |

### Germania (DE), download set-nov: 172

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 18 | 72 | 60 | Walkie Talkie - All Talk App (5086); ten ten - your friends, on tap (45229); Walkie Talkie Intercom App (95) |
| funkgerät | 6 | 58 | 36 | Funkgerät (2358); Mini Walkie Talkie Funk (1); Walkie Talkie - All Talk App (5086) |
| cb funk | 11 | 78 | 24 | CB TALK (207); CB Radio 2015 (Light) (1); TR Talk (57) |
| cb radio | 17 | 64 | 30 | CB TALK (207); Police Scanner Radio & Fire (227); CB Radio Live (0) |
| sprechfunk | 30 | 1 | 49 | Flugfunktrainer (399); BZF Flugfunk Fragenkatalog (891); Funkpilot , BZF Sprechfunk (1) |
| amateurfunk | oltre 200 | 58 | 33 | 50Ohm (27); Funkprüfung , Amateurfunk (5); Ionaut , Ham Radio (4) |
| kurzwelle | 10 | 1 | 13 | UVB-76: Zahlensender (0); HamQRG: Amateurfunk-Relais (2); FUNKAMATEUR - Die Zeitschrift (13) |
| walkie talkie offline | 16 | 44 | 45 | Walkie Talkie Offline (2); Walkie Talkie - All Talk App (5086); Offline Walkie-Talkie (0) |
| funk | oltre 200 | 74 | 63 | FUNK - Deine Tarif-App (10991); CB TALK (207); freenet Mobilfunk (47851) |
| funkgerät ohne internet | oltre 200 | 1 | 6 | MeshMeet: Video ohne Internet (0); NearVox (0) |
| walkie talkie ohne internet | oltre 200 | 1 | 4 | Offline Walkie-Talkie (0); MeshMeet: Video ohne Internet (0); NearVox (0) |

### Thailandia (TH), download set-nov: 160

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| วิทยุสื่อสาร | 3 | 66 | 21 | Wordang วอ.แดง - Walkie Talkie (2); Walkie-Talkie for Best Friends (58); Talky - Walkie Talkie, Radio (1) |
| วอ | oltre 200 | 72 | 69 | TrueMoney - Pay & Earn Coins (71181); buz - voice connects (12749); Zello Walkie Talkie (5313) |
| walkie talkie | 13 | 64 | 54 | Walkie Talkie - All Talk App (283); Zello Walkie Talkie (5313); buz - voice connects (12749) |
| วิทยุ | oltre 200 | 80 | 54 | Thai Radio: Thailand FM Online (90328); Thai Radio วิทยุ & พอดแคสต์ (6893); Radio App (721) |
| วิทยุ cb | oltre 200 | 1 | 0 | n/d |
| วิทยุสมัครเล่น | 6 | 1 | 14 | Ham Radio Bank (0); Morse code for ham radio (1); Alphabet for ham radio (2) |

### Italia (IT), download set-nov: 142

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 12 | 70 | 56 | Walkie Talkie - All Talk App (1415); Zello Walkie Talkie (599); ten ten - your friends, on tap (34285) |
| radio cb | 5 | 33 | 36 | CB TALK (219); CB Radio 2015 (Light) (1); Police Scanner Radio & Fire (98) |
| cb radio | 12 | 1 | 32 | CB TALK (219); CB Radio 2015 (Light) (1); Police Scanner Radio & Fire (98) |
| ricetrasmittente | 3 | 46 | 14 | Walkie-Talkie - сhat di amici (19); buz - voice connects (294); Talky - Walkie Talkie, Radio (0) |
| baracchino | 56 | 62 | 35 | CB TALK (219); CB Radio 2015 (Light) (1); Online Walkie Talkie Pro (20) |
| radioamatore | 13 | 1 | 14 | Quiz Radioamatori (73); HamQRG: Ponti Radioamatoriali (18); Ham Radio Bank (2) |
| onde corte | 6 | 1 | 21 | UVB-76: radio a onde corte (0); BESTSECRET (6391); Etere.AI (0) |
| walkie talkie offline | 7 | 52 | 41 | Walkie Talkie Offline (1); Walkie Talkie - All Talk App (1415); ten ten - your friends, on tap (34285) |
| walkie talkie senza internet | oltre 200 | 1 | 13 | Interfono: parla senza 5G (0); Walkie-Talkie Offline (0); MeshMeet: Video senza Internet (0) |

### Regno Unito (GB), download set-nov: 115

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 14 | 70 | 63 | Walkie Talkie - All Talk App (4115); Walkie Talkie Intercom App (40); Zello Walkie Talkie (1845) |
| cb radio | 33 | 64 | 42 | CB TALK (116); CB Radio Live (0); CitizenBand Radio (0) |
| walkie talkie offline | 15 | 44 | 41 | Walkie Talkie Offline (3); Walkie Talkie - All Talk App (4115); Zello Walkie Talkie (1845) |
| ham radio | 54 | 54 | 27 | CitizenBand Radio (0); HamSphere 5.0 (1); Radio Society of Great Britain (11) |

### Polonia (PL), download set-nov: 108

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| krótkofalówka | 2 | 60 | 28 | Online Walkie Talkie Pro (6); Talky - Walkie Talkie, Radio (0); ten ten - your friends, on tap (20455) |
| walkie talkie | 7 | 64 | 53 | Walkie Talkie - All Talk App (204); ten ten - your friends, on tap (20455); Walkie Talkie: Talk to Friends (4) |
| cb radio | 18 | 88 | 27 | CB TALK (11); CB Radio 2015 (Light) (1); CitizenBand Radio (0) |
| cb | oltre 200 | 1 | 51 | CB TALK (11); CB Mode (0); Walkie Talkie CB (1) |
| radio cb | 4 | 1 | 23 | CB TALK (11); CB (2); CB Line (0) |
| krótkofalowiec | oltre 200 | 1 | 4 | Robot72 - ISS SSTV Decoder (2); Morse Code AI: Train & Compete (1); HamTalk (0) |

### Spagna (ES), download set-nov: 105

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 13 | 74 | 57 | Walkie Talkie - All Talk (1379); Zello Walkie Talkie (4197); ten ten - your friends, on tap (16321) |
| radio cb | 10 | 33 | 29 | CB TALK (51); CB Radio 2015 (Light) (0); Police Scanner, Wildfire Radio (36) |
| emisora | oltre 200 | 1 | 53 | Radios Colombia: Radio en Vivo (11024); TuneIn Radio: noticias AM FM (48437); FM Radio (933) |
| walkie talkie sin internet | 8 | 1 | 32 | Zello Walkie Talkie (4197); Walkie Talkie - All Talk (1379); Walkie Talkie Intercom App (23) |
| radioaficionado | 13 | 44 | 1 | HamExam (3); CQ Board (0); Calculadoras y herramientas RF (0) |
| onda corta | 8 | 1 | 22 | HamQRG: Repetidores de Radio (3); SWListener: Guía Onda Corta (1); morse código de radio de jamón (2) |

### Messico (MX), download set-nov: 83

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 17 | 70 | 60 | Walkie Talkie - All Talk App (5098); Zello Walkie Talkie (8176); Online Walkie Talkie Pro (127) |
| radio cb | 10 | 33 | 32 | CB TALK (19); CB Radio 2015 (Light) (2); CB (0) |
| radio de banda civil | oltre 200 | 1 | 0 | n/d |
| radio | oltre 200 | 74 | 86 | Radio FM México en Vivo (89156); RadioApp - A Simple Radio (7934); TuneIn Radio: noticias, música (82813) |

### Australia (AU), download set-nov: n/d

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 17 | 68 | 58 | Walkie Talkie - All Talk App (1844); Zello Walkie Talkie (484); ten ten - your friends, on tap (7175) |
| cb radio | 30 | 64 | 40 | CB TALK (7); CB Radio Chat (8); Online Walkie Talkie Pro (17) |
| uhf cb | 24 | 1 | 28 | XRS Connect (82); CB Radio 2015 (Light) (3); CB Radio Box (1) |

### Giappone (JP), download set-nov: n/d

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| トランシーバー | 15 | 70 | 43 | トランシーバー - つながる、どこでも。 (2); Zello Walkie Talkie (974); トランシーバーWalkieTalkieBaby (41) |
| 無線 | oltre 200 | 86 | 41 | トランシーバー - つながる、どこでも。 (2); 警察無線スキャナー + (0); Zello Walkie Talkie (974) |
| cb無線 | 4 | 1 | 3 | CB (2); アマチュア無線のためのアルファベット (0); HamLogJP - 無線交信ログ帳 (0) |
| 無線機 | 10 | 84 | 19 | トランシーバー - つながる、どこでも。 (2); Online Walkie Talkie Pro (3); Zello Walkie Talkie (974) |
| walkie talkie | 9 | 54 | 50 | Walkie Talkie - All Talk App (127); Walkie Talkie Offline (0); Zello Walkie Talkie (974) |
| インカム | oltre 200 | 76 | 44 | 歩いてポイントが貯まるポイ活アプリ-ポイントインカム (3713); Buddycom(バディコム) - トランシーバー,インカム (53); DOUSHI インカム通話 (8) |
| アマチュア無線 | 57 | 76 | 29 | 4級3級アマチュア無線 予想問題集 2026年版 (4); HAM交信サポート - アマチュア無線のログアプリ (20); Mona Radio (0) |
| 短波 | 42 | 1 | 51 | SWAtlas - 短波エクスプローラー (1); UVB-76: 終末の短波ラジオ (1); １日バイト！単発日払い・日給手渡しバイト求人｜１日ジョブスポ (3) |
| トランシーバー アプリ | 56 | 1 | 29 | Voxer トランシーバー PTT (16); ぐるかむ - トランシーバー,インカムアプリ (86); トランシーバー - つながる、どこでも。 (2) |

### Corea del Sud (KR), download set-nov: n/d

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| 무전기 | 5 | 1 | 22 | 제로톡 무전기 - 워키토키 (0); Zello Walkie Talkie (247); 워키토키- Walkie-Talkie voice chat (80) |
| 워키토키 | 12 | 1 | 30 | 워키토키- Walkie-Talkie voice chat (80); Watch (559); 워키토끼 (0) |
| cb 라디오 | 7 | 1 | 24 | CB Radio 2015 (Light) (0); 햄 라디오 알파벳 (0); CB (0) |
| walkie talkie | 6 | 54 | 42 | Walkie Talkie - All Talk App (59); Online Walkie Talkie Pro (1); Zello Walkie Talkie (247) |

### Vietnam (VN), download set-nov: n/d

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| bộ đàm | 15 | 60 | 23 | Walkie-Talkie for Best Friends (33); Walkie Talkie: Talk to Friends (6); Online Walkie Talkie Pro (10) |
| walkie talkie | 15 | 56 | 51 | Walkie Talkie - All Talk App (181); Walkie-Talkie for Best Friends (33); Walkie Talkie: Talk to Friends (6) |
| bo dam | 91 | 1 | 42 | Walkie-Talkie for Best Friends (33); Authenticator: Secure Vault (0); Google Drive , online backup (1346311) |
| máy bộ đàm | 45 | 1 | 59 | Google Drive , online backup (1346311); Authenticator: Secure Vault (0); Google Authenticator (198032) |
| sóng ngắn | 132 | 1 | 52 | StardustTV - Short Drama&Movie (35303); OCTO by CIMB Vietnam (994); Bridge - River Crossing IQ (2) |

### Turchia (TR), download set-nov: n/d

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| telsiz | 132 | 64 | 37 | Telsiz Ses Efektleri (13); Zello Walkie Talkie (5882); CB TALK (123) |
| walkie talkie | 11 | 68 | 55 | Walkie Talkie - All Talk App (294); Zello Walkie Talkie (5882); Online Walkie Talkie Pro (25) |
| bas konuş | 16 | 52 | 26 | Zello Walkie Talkie (5882); TalkLink: Walkie Talkie PTT (2); Türk Talk (100) |
| kısa dalga | 3 | 1 | 9 | Morse code for ham radio (0); Eddy Surf Report (0); Talky - Walkie Talkie, Radio (0) |
| amatör telsiz | 70 | 60 | 42 | Amatör Telsiz Sınavı (2); Amatör Telsiz Bankası (33); Amatör Telsizcilik (68) |
| cb telsiz | 6 | 1 | 19 | CB TALK (123); Police Scanner Radio Live (0); Two Way : Walkie Talkie (29) |

### Malesia (MY), download set-nov: n/d

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| walkie talkie | 7 | 68 | 52 | buz - voice connects (8380); Zello Walkie Talkie (1628); Walkie Talkie - All Talk App (281) |
| walkie talkie offline | 24 | 48 | 37 | Walkie Talkie Offline (0); Zello Walkie Talkie (1628); Walkie Talkie - All Talk App (281) |
| radio cb | 9 | 1 | 20 | CB (0); CB TALK (0); CB Radio 2015 (Light) (1) |
| radio amatur | oltre 200 | 1 | 16 | Amateur Radio Toolkit (1); Alphabet for ham radio (0); Ham Radio Prep (1) |
| walkie talkie tanpa internet | oltre 200 | 1 | 0 | Talk Nearby - intercom (no 5G) (0); MeshMeet: Offline Video Call (0); Microphone: stream to speakers (0) |

### Cina (CN), download set-nov: n/d

| Termine | Posizione Talky | Popolarita' (0-100) | Difficolta' | Primi risultati (valutazioni) |
|---|---|---|---|---|
| 对讲机 | 29 | 84 | 62 | 微泡泡-工作对讲机 (16080); 南山对讲 - 手机APP对讲机 (243); 密度空间-地图对讲机 (37662) |
| walkie talkie | 5 | 48 | 31 | Walkie Talkie: Talk to Friends (4); 对讲机, 与您的朋友交谈, 保持联系, 数字语音电台聊天 (21); WalkieTalkie PTT (0) |
| cb电台 | oltre 200 | 1 | 6 | CB (1); 警用电台直播扫描 (0); Pod2Swim (0) |
| 无线电 | oltre 200 | 66 | 23 | 超级手台 (0); 哈友会-业余无线电 (17); 业余无线电考试题库 (7) |
| 业余无线电 | 27 | 78 | 26 | 业余无线电考试题库 (7); 哈友会-业余无线电 (17); 智慧火腿 (2) |
| 对讲 | oltre 200 | 84 | 72 | 南山对讲 - 手机APP对讲机 (243); 微泡泡-工作对讲机 (16082); 滔滔对讲 (198) |