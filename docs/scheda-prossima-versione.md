# Scheda App Store iOS per la versione dopo la 2.47

Preparata il 26 settembre 2026, mentre la 2.47 (build 109) era in attesa di revisione
con descrizione e parole chiave bloccate. Va applicata alla prima versione iOS in
preparazione dopo la 2.47 (nel progetto e' gia' 2.48). Il testo promozionale qui sotto
e' invece gia' live sulla 2.47, perche' si puo' cambiare anche durante la revisione.

I testi pronti da applicare sono anche in `docs/scheda-prossima-versione.json`
(chiavi: `description`, `keywords`, `promotional_text`, `whats_new`, `marketing_url`).
Si applicano con `apps_update_metadata` lingua per lingua, oppure con un PATCH su
`/v1/appStoreVersionLocalizations/{id}`. Il campo copyright non si tocca.

## Da dove vengono i fatti scritti in scheda

Tutto quello che la scheda promette e' stato letto nel codice, non supposto.

| Affermazione | Dove si verifica |
|---|---|
| iPhone con iPhone: Wi-Fi e Bluetooth diretti, senza rete | `MultipeerManager.swift`: `MCSession` + `MCNearbyServiceAdvertiser`/`Browser`, servizio `walkie-talkie`. Multipeer usa Wi-Fi di infrastruttura, Wi-Fi peer-to-peer e Bluetooth |
| Il messaggio parte al rilascio del tasto | `stopTransmitting()` chiama `sendAccumulatedAudio()`: l'audio viene accumulato mentre si tiene premuto e inviato tutto insieme, `.reliable` |
| Mac (e le altre piattaforme) solo sulla stessa rete Wi-Fi | `TalkyCrossPlatformManager.swift`: `NWListener` TCP pubblicato via Bonjour, senza `includePeerToPeer`, quindi solo rete locale condivisa |
| Fino a 8 dispositivi | limite di `MCSession` |
| Portata tipica 10-30 m | valore tipico di Multipeer tra due iPhone (Bluetooth circa 10 m, Wi-Fi diretto qualche decina di metri in campo libero). Le recensioni parlano di circa 10 m: e' la stima prudente, non un massimo |
| Oltre 300 stazioni da oltre 80 paesi | `RadioManager.swift`: 343 stazioni, 82 paesi |

## Cosa cambia rispetto alla 2.47 e perche'

- **Le prime righe dicono il beneficio e come funziona.** In en-US, de-DE e pt-BR la
  descrizione si apriva con la licenza GitHub: ora la licenza e' in fondo, prima del
  blocco legale, in tutte le lingue.
- **Tolte le promesse che il codice non mantiene.** "Crittografata" (la sessione e'
  `encryptionPreference: .optional` e il canale TCP verso Mac non e' cifrato),
  "tempo reale" (il messaggio parte al rilascio), "migliaia di stazioni" (sono 343),
  "stima della distanza" (il radar con metri e posizioni casuali e' stato tolto
  dall'app nella 2.48 build 99),
  "progetto open source" in ko/ja/tr: il file `LICENSE` e' PolyForm Noncommercial
  1.0.0, che non e' una licenza open source (vieta l'uso commerciale). In tutte le
  lingue la scheda dice quindi "codice pubblico su GitHub", con il link al
  repository, "localizzata in italiano, inglese e spagnolo" in ko/ja (sono 14 lingue).
- **Detto chiaro che Talky non e' una ricetrasmittente**: non parla con walkie-talkie
  PMR o CB. E' la risposta diretta alle recensioni "radio finta".
- **Nessun prezzo scritto a mano.** La prova gratuita e' citata senza durata, cosi'
  resta vera anche se l'offerta cambia su App Store Connect.
- **Parole chiave**: tolte `fm`, `scanner`, `cb`, `ham`, `am`, onde corte, che
  attiravano chi cerca una radio vera. Aggiunte le varianti `walkietalkie` (tutto
  attaccato), `ptt`, `offline` dove mancavano. Nessuna parola ripete titolo
  (`Talky`, `Walkie`, `Talkie`, `Radio`) o sottotitolo della stessa lingua, niente
  spazi dopo le virgole, tutte entro 100 caratteri.
- **URL di marketing**: `https://www.andreapiani.com`, gia' impostato cosi' su tutte
  le lingue della 2.47. Da lasciare com'e'.
- **Note di versione**: solo cose utili all'utente, nessuna frase sulla pubblicita'.
  Descrivono le modifiche delle build 2.48 (98 e 99): Esplora senza distanze
  inventate, schermate che scorrono su iPhone 8 e SE, schermata principale piu'
  compatta, prova gratuita mostrata solo a chi puo' averla. Se nella versione entra altro, vanno aggiornate.

## Testi per lingua

### en-US

**Parole chiave** (97 caratteri)

```
walkietalkie,ptt,offline,intercom,two way,signal,nearby,bluetooth,hiking,camping,kids,family,free
```

**Testo promozionale** (gia' live sulla 2.47, 154 caratteri)

```
Talk to people nearby with no cell signal and no internet. iPhones connect directly over Wi-Fi and Bluetooth, typical range 10-30 m. Everyone needs Talky.
```

**Novita' di questa versione**

```
• Explore no longer shows made-up distances: the radar with meters and random positions is gone, replaced by a plain list of the devices found and their real status.
• Explore and Connections now scroll on iPhone 8, SE and other small screens, so no button stays hidden under the bottom bar.
• The main screen is more compact on small screens.
• The Pro screen shows the free trial only if your Apple ID can actually get it, and the button says so.
```

**Descrizione** (1989 caratteri)

```
Talk to the people around you at the press of a button, with no cell signal and no internet. Talky connects iPhones directly to each other over Wi-Fi and Bluetooth: hold the button, speak, release, and your message reaches everyone in the channel.

HOW IT WORKS, WITH NO SURPRISES
• Everyone needs Talky open, with Wi-Fi and Bluetooth turned on. You do not need to be connected to a network.
• Typical range between two iPhones: 10-30 meters. More outdoors with a clear line of sight, less through walls and floors.
• On the same Wi-Fi network it works wherever the network reaches, including with Talky for Mac.
• Hold to talk: your message is sent the moment you release the button.
• Up to 8 devices connected at the same time.
• Talky is not a radio transceiver: it does not talk to PMR or CB walkie-talkies, only to other devices running Talky.

INTERNET RADIO
More than 300 stations from over 80 countries, streamed over the internet (this part needs a connection). Your iPhone has no FM receiver: the frequency shown next to a station is the one that broadcaster uses on air in its own country.

TALKY PRO
Talky is free with ads. Talky Pro removes the ads and adds all stations, recordings of your transmissions, private channels with a password, themes, history, sleep timer and equalizer. The yearly plan includes a free trial if you have not used one before, and there is also a one-time purchase with no subscription.

Talky's code is public on GitHub, under the PolyForm Noncommercial 1.0.0 license: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Talky Pro subscription auto-renews at the end of each period unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account at confirmation of purchase. You can manage and cancel your subscription in your Apple ID Settings.
```

### it

**Parole chiave** (97 caratteri)

```
walkietalkie,ricetrasmittente,ptt,offline,interfono,bluetooth,escursioni,campeggio,bambini,gratis
```

**Testo promozionale** (gia' live sulla 2.47, 168 caratteri)

```
Parla con chi ti è vicino senza rete cellulare e senza internet. Gli iPhone si collegano via Wi-Fi e Bluetooth, portata tipica 10-30 m. Serve Talky su tutti i telefoni.
```

**Novita' di questa versione**

```
• Esplora non mostra più distanze inventate: il radar con i metri e le posizioni casuali è sparito, al suo posto l'elenco dei dispositivi trovati con il loro stato reale.
• Su iPhone 8, SE e altri schermi piccoli le schermate Esplora e Connessioni ora scorrono: nessun pulsante resta nascosto sotto la barra in basso.
• La schermata principale è più compatta sugli schermi piccoli.
• La schermata Pro mostra la prova gratuita solo se il tuo Apple ID può davvero averla, e il pulsante lo dice chiaramente.
```

**Descrizione** (1943 caratteri)

```
Parla con chi ti sta vicino premendo un tasto, senza rete cellulare e senza internet. Talky collega gli iPhone direttamente tra loro via Wi-Fi e Bluetooth: tieni premuto, parla, rilascia, e il messaggio arriva a tutti quelli nel canale.

COME FUNZIONA, SENZA SORPRESE
• Tutti devono avere Talky aperta, con Wi-Fi e Bluetooth attivi. Non serve essere collegati a una rete.
• Portata tipica tra due iPhone: da 10 a 30 metri. Di più all'aperto e senza ostacoli, meno attraverso muri e solai.
• Sulla stessa rete Wi-Fi funziona ovunque arrivi la rete, anche con Talky per Mac.
• Tieni premuto per parlare: il messaggio parte appena rilasci il tasto.
• Fino a 8 dispositivi collegati insieme.
• Talky non è una ricetrasmittente: non comunica con walkie-talkie PMR o CB, solo con altri dispositivi che usano Talky.

RADIO INTERNET
Oltre 300 stazioni da più di 80 paesi, in streaming via internet (per questa parte serve la connessione). L'iPhone non ha un ricevitore FM: la frequenza indicata accanto a una stazione è quella su cui l'emittente trasmette nel suo paese.

TALKY PRO
Talky è gratuita con pubblicità. Talky Pro toglie la pubblicità e aggiunge tutte le stazioni, la registrazione delle trasmissioni, canali privati con password, temi, cronologia, sleep timer ed equalizzatore. Il piano annuale include una prova gratuita per chi non l'ha già usata, e c'è anche un acquisto unico, senza abbonamento.

Il codice di Talky è pubblico su GitHub, con licenza PolyForm Noncommercial 1.0.0: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Talky Pro subscription auto-renews at the end of each period unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account at confirmation of purchase. You can manage and cancel your subscription in your Apple ID Settings.
```

### de-DE

**Parole chiave** (99 caratteri)

```
walkietalkie,funkgerät,ptt,offline,sprechfunk,netz,funkloch,bluetooth,wandern,camping,kinder,gratis
```

**Testo promozionale** (gia' live sulla 2.47, 167 caratteri)

```
Sprich mit Menschen in der Nähe, ohne Mobilfunk und ohne Internet. iPhones verbinden sich direkt per WLAN und Bluetooth, Reichweite meist 10-30 m. Alle brauchen Talky.
```

**Novita' di questa versione**

```
• Entdecken zeigt keine erfundenen Entfernungen mehr: Das Radar mit Metern und zufälligen Positionen ist weg, stattdessen gibt es eine Liste der gefundenen Geräte mit ihrem echten Status.
• Entdecken und Verbindungen lassen sich auf iPhone 8, SE und anderen kleinen Bildschirmen jetzt scrollen: Keine Taste bleibt mehr unter der unteren Leiste verborgen.
• Der Hauptbildschirm ist auf kleinen Bildschirmen kompakter.
• Der Pro-Bildschirm zeigt die Gratis-Testphase nur, wenn deine Apple-ID sie wirklich bekommt, und die Taste sagt es klar.
```

**Descrizione** (2052 caratteri)

```
Sprich per Knopfdruck mit den Menschen in deiner Nähe, ohne Mobilfunk und ohne Internet. Talky verbindet iPhones direkt miteinander über WLAN und Bluetooth: Taste halten, sprechen, loslassen, und deine Nachricht erreicht alle im Kanal.

SO FUNKTIONIERT ES, OHNE ÜBERRASCHUNGEN
• Alle brauchen Talky geöffnet, mit eingeschaltetem WLAN und Bluetooth. Eine Verbindung zu einem Netzwerk ist nicht nötig.
• Typische Reichweite zwischen zwei iPhones: 10-30 Meter. Mehr im Freien bei freier Sicht, weniger durch Wände und Decken.
• Im selben WLAN funktioniert es überall, wo das Netz hinreicht, auch mit Talky für Mac.
• Zum Sprechen gedrückt halten: Die Nachricht wird gesendet, sobald du die Taste loslässt.
• Bis zu 8 Geräte gleichzeitig verbunden.
• Talky ist kein Funkgerät: Es spricht nicht mit PMR- oder CB-Funkgeräten, nur mit anderen Geräten, auf denen Talky läuft.

INTERNETRADIO
Mehr als 300 Sender aus über 80 Ländern, gestreamt über das Internet (dafür ist eine Verbindung nötig). Das iPhone hat keinen UKW-Empfänger: Die Frequenz neben einem Sender ist die, auf der er in seinem Land ausstrahlt.

TALKY PRO
Talky ist kostenlos mit Werbung. Talky Pro entfernt die Werbung und bietet alle Sender, Aufnahmen deiner Übertragungen, private Kanäle mit Passwort, Designs, Verlauf, Sleep-Timer und Equalizer. Das Jahresabo enthält eine kostenlose Testphase, falls du noch keine genutzt hast, und es gibt auch einen Einmalkauf ohne Abo.

Der Code von Talky ist öffentlich auf GitHub, unter der Lizenz PolyForm Noncommercial 1.0.0: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Das Talky-Pro-Abonnement verlängert sich am Ende jeder Laufzeit automatisch, sofern es nicht mindestens 24 Stunden vor Ablauf der aktuellen Periode gekündigt wird. Die Zahlung wird bei Kaufbestätigung über dein Apple-ID-Konto abgerechnet. Du kannst dein Abonnement in den Einstellungen deiner Apple-ID verwalten und kündigen.
```

### es-ES

**Parole chiave** (97 caratteri)

```
walkietalkie,ptt,offline,intercomunicador,red,cobertura,bluetooth,senderismo,camping,niños,gratis
```

**Testo promozionale** (gia' live sulla 2.47, 160 caratteri)

```
Habla con quien tienes cerca sin cobertura móvil y sin internet. Los iPhone se conectan por Wi-Fi y Bluetooth, alcance típico de 10-30 m. Todos necesitan Talky.
```

**Novita' di questa versione**

```
• Explorar ya no muestra distancias inventadas: el radar con metros y posiciones aleatorias desaparece y en su lugar está la lista de dispositivos encontrados con su estado real.
• En iPhone 8, SE y otras pantallas pequeñas, Explorar y Conexiones ahora se desplazan: ningún botón queda oculto bajo la barra inferior.
• La pantalla principal es más compacta en pantallas pequeñas.
• La pantalla Pro muestra la prueba gratuita solo si tu Apple ID puede obtenerla de verdad, y el botón lo indica claramente.
```

**Descrizione** (1968 caratteri)

```
Habla con quien tienes cerca pulsando un botón, sin cobertura móvil y sin internet. Talky conecta los iPhone directamente entre sí por Wi-Fi y Bluetooth: mantén pulsado, habla, suelta, y tu mensaje llega a todos los del canal.

CÓMO FUNCIONA, SIN SORPRESAS
• Todos necesitan tener Talky abierta, con Wi-Fi y Bluetooth activados. No hace falta estar conectado a una red.
• Alcance típico entre dos iPhone: de 10 a 30 metros. Más al aire libre y sin obstáculos, menos a través de paredes y techos.
• En la misma red Wi-Fi funciona en toda la zona que cubre la red, también con Talky para Mac.
• Mantén pulsado para hablar: el mensaje se envía en cuanto sueltas el botón.
• Hasta 8 dispositivos conectados a la vez.
• Talky no es un transmisor de radio: no se comunica con walkie-talkies PMR o CB, solo con otros dispositivos que usan Talky.

RADIO POR INTERNET
Más de 300 emisoras de más de 80 países, en streaming por internet (para esta parte hace falta conexión). El iPhone no tiene receptor de FM: la frecuencia que aparece junto a una emisora es la que usa en antena en su país.

TALKY PRO
Talky es gratis con anuncios. Talky Pro quita los anuncios y añade todas las emisoras, la grabación de tus transmisiones, canales privados con contraseña, temas, historial, temporizador de apagado y ecualizador. El plan anual incluye una prueba gratuita si aún no la has usado, y también hay una compra única, sin suscripción.

El código de Talky es público en GitHub, con la licencia PolyForm Noncommercial 1.0.0: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Talky Pro subscription auto-renews at the end of each period unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account at confirmation of purchase. You can manage and cancel your subscription in your Apple ID Settings.
```

### fr-FR

**Parole chiave** (94 caratteri)

```
talkiewalkie,ptt,hors ligne,offline,intercom,réseau,bluetooth,randonnée,camping,enfant,gratuit
```

**Testo promozionale** (gia' live sulla 2.47, 164 caratteri)

```
Parlez aux personnes proches sans réseau mobile ni internet. Les iPhone se relient en Wi-Fi et Bluetooth, portée typique de 10-30 m. Tout le monde doit avoir Talky.
```

**Novita' di questa versione**

```
• Explorer n'affiche plus de distances inventées : le radar avec des mètres et des positions aléatoires a disparu, remplacé par la liste des appareils trouvés avec leur état réel.
• Sur iPhone 8, SE et les autres petits écrans, Explorer et Connexions défilent désormais : aucun bouton ne reste caché sous la barre du bas.
• L'écran principal est plus compact sur les petits écrans.
• L'écran Pro n'affiche l'essai gratuit que si votre identifiant Apple peut vraiment en profiter, et le bouton l'indique clairement.
```

**Descrizione** (2082 caratteri)

```
Parlez aux personnes autour de vous d'une simple pression, sans réseau mobile et sans internet. Talky relie les iPhone directement entre eux par Wi-Fi et Bluetooth : maintenez, parlez, relâchez, et votre message arrive à tout le canal.

COMMENT ÇA MARCHE, SANS SURPRISE
• Tout le monde doit avoir Talky ouverte, avec le Wi-Fi et le Bluetooth activés. Pas besoin d'être connecté à un réseau.
• Portée typique entre deux iPhone : de 10 à 30 mètres. Plus en plein air sans obstacle, moins à travers les murs et les planchers.
• Sur le même réseau Wi-Fi, elle fonctionne partout où le réseau arrive, y compris avec Talky pour Mac.
• Maintenez pour parler : le message part dès que vous relâchez le bouton.
• Jusqu'à 8 appareils connectés en même temps.
• Talky n'est pas un émetteur-récepteur radio : elle ne communique pas avec les talkies-walkies PMR ou CB, seulement avec d'autres appareils qui utilisent Talky.

RADIO INTERNET
Plus de 300 stations de plus de 80 pays, en streaming par internet (cette partie demande une connexion). L'iPhone n'a pas de récepteur FM : la fréquence affichée à côté d'une station est celle sur laquelle elle émet dans son pays.

TALKY PRO
Talky est gratuite avec publicité. Talky Pro retire la publicité et ajoute toutes les stations, l'enregistrement de vos transmissions, des canaux privés avec mot de passe, des thèmes, l'historique, une minuterie de veille et un égaliseur. L'offre annuelle inclut un essai gratuit si vous n'en avez pas déjà profité, et il existe aussi un achat unique, sans abonnement.

Le code de Talky est public sur GitHub, sous licence PolyForm Noncommercial 1.0.0 : https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Talky Pro subscription auto-renews at the end of each period unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account at confirmation of purchase. You can manage and cancel your subscription in your Apple ID Settings.
```

### pt-BR

**Parole chiave** (97 caratteri)

```
walkietalkie,radinho,comunicador,ptt,offline,intercomunicador,bluetooth,trilha,acampamento,grátis
```

**Testo promozionale** (gia' live sulla 2.47, 159 caratteri)

```
Fale com quem está perto sem sinal de celular e sem internet. Os iPhones se conectam por Wi-Fi e Bluetooth, alcance típico de 10-30 m. Todos precisam do Talky.
```

**Novita' di questa versione**

```
• Explorar não mostra mais distâncias inventadas: o radar com metros e posições aleatórias saiu, e no lugar fica a lista dos aparelhos encontrados com o status real.
• No iPhone 8, SE e outras telas pequenas, Explorar e Conexões agora rolam: nenhum botão fica escondido sob a barra inferior.
• A tela principal ficou mais compacta em telas pequenas.
• A tela Pro só mostra o teste grátis se o seu ID Apple pode mesmo recebê-lo, e o botão diz isso claramente.
```

**Descrizione** (1974 caratteri)

```
Fale com quem está perto apertando um botão, sem sinal de celular e sem internet. O Talky conecta os iPhones diretamente entre si por Wi-Fi e Bluetooth: segure, fale, solte, e sua mensagem chega a todos no canal.

COMO FUNCIONA, SEM SURPRESAS
• Todos precisam estar com o Talky aberto, com Wi-Fi e Bluetooth ligados. Não é preciso estar conectado a uma rede.
• Alcance típico entre dois iPhones: de 10 a 30 metros. Mais ao ar livre e sem obstáculos, menos através de paredes e lajes.
• Na mesma rede Wi-Fi funciona em toda a área que a rede cobre, inclusive com o Talky para Mac.
• Segure para falar: a mensagem é enviada assim que você solta o botão.
• Até 8 aparelhos conectados ao mesmo tempo.
• O Talky não é um rádio transmissor: ele não fala com walkie-talkies PMR ou PX, só com outros aparelhos que usam o Talky.

RÁDIO PELA INTERNET
Mais de 300 estações de mais de 80 países, via streaming pela internet (esta parte precisa de conexão). O iPhone não tem receptor FM: a frequência mostrada ao lado de uma estação é a que aquela emissora usa no ar em seu país.

TALKY PRO
O Talky é grátis com anúncios. O Talky Pro remove os anúncios e acrescenta todas as estações, gravação das suas transmissões, canais privados com senha, temas, histórico, timer de desligamento e equalizador. O plano anual inclui um teste grátis para quem ainda não usou, e também há uma compra única, sem assinatura.

O código do Talky é público no GitHub, sob a licença PolyForm Noncommercial 1.0.0: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

A assinatura Talky Pro é renovada automaticamente ao final de cada período, a menos que seja cancelada com pelo menos 24 horas de antecedência do fim do período atual. O pagamento é cobrado na sua conta Apple ID na confirmação da compra. Você pode gerenciar e cancelar sua assinatura nos Ajustes do seu Apple ID.
```

### ja

**Parole chiave** (87 caratteri)

```
ウォーキートーキー,無線機,インカム,プッシュトゥトーク,ptt,オフライン,圏外,bluetooth,キャンプ,登山,子供,防災,無料,wifi,家族,スキー,サイクリング
```

**Testo promozionale** (gia' live sulla 2.47, 82 caratteri)

```
携帯の電波もネットもなしで、近くの人と話せます。iPhone同士をWi-FiとBluetoothで直接接続、通信距離は通常10〜30m。全員にTalkyが必要です。
```

**Novita' di questa versione**

```
• 「探す」画面で作り物の距離を表示しなくなりました。メートル表示とランダムな位置のレーダーをやめ、見つかったデバイスと実際の状態を一覧で表示します。
• iPhone 8やSEなど小さな画面で、「探す」と「接続」の画面がスクロールできるようになり、下のバーにボタンが隠れなくなりました。
• 小さな画面でメイン画面をコンパクトにしました。
• Pro画面では、お使いのApple IDが実際に受けられる場合だけ無料トライアルを表示し、ボタンにもはっきり表示します。
```

**Descrizione** (1076 caratteri)

```
ボタンを押すだけで、近くにいる人と話せます。携帯の電波もインターネットも不要です。TalkyはWi-FiとBluetoothでiPhone同士を直接つなぎます。押したまま話して、離せば、チャンネルの全員にメッセージが届きます。

しくみ（わかりやすく正直に）
• 全員がTalkyを開き、Wi-FiとBluetoothをオンにしておく必要があります。ネットワークへの接続は不要です。
• iPhone 2台の間の通信距離は、通常10〜30メートルです。見通しのよい屋外ではもっと届き、壁や床をはさむと短くなります。
• 同じWi-Fiネットワーク内なら、ネットワークの届く範囲どこでも使えます。Mac版Talkyとも話せます。
• 押している間に話し、ボタンを離した瞬間にメッセージが送信されます。
• 最大8台まで同時に接続できます。
• Talkyは無線機ではありません。特定小電力トランシーバーやCB無線とは通信できず、Talkyを使っている端末どうしでのみ話せます。

インターネットラジオ
80か国以上、300局以上をインターネット経由で配信します（この機能には接続が必要です）。iPhoneにFMチューナーはありません。局の横の周波数は、その局が自国の電波で使っている周波数です。

TALKY PRO
Talkyは広告付きで無料です。Talky Proでは広告がなくなり、すべての局、送信内容の録音、パスワード付きプライベートチャンネル、テーマ、履歴、スリープタイマー、イコライザーが使えます。年額プランには、まだ使ったことのない方向けの無料トライアルがあり、サブスクリプションなしの買い切りも用意しています。

TalkyのコードはGitHubで公開されています（PolyForm Noncommercial 1.0.0ライセンス）: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Talky Proのサブスクリプションは、期間終了の24時間前までに解約しない限り、各期間の終了時に自動更新されます。購入確認時にApple IDアカウントに課金されます。サブスクリプションの管理・解約はApple IDの設定から行えます。
```

### ko

**Parole chiave** (80 caratteri)

```
워키토키,ptt,푸시투토크,오프라인,인터콤,블루투스,bluetooth,등산,캠핑,어린이,비상,무료,근거리,와이파이,wifi,가족,자전거,스키,팀
```

**Testo promozionale** (gia' live sulla 2.47, 95 caratteri)

```
휴대폰 신호도 인터넷도 없이 가까운 사람과 대화하세요. iPhone끼리 Wi-Fi와 Bluetooth로 직접 연결, 일반 거리 10~30m. 모두 Talky가 필요합니다.
```

**Novita' di questa versione**

```
• 탐색 화면에서 지어낸 거리를 더 이상 보여 주지 않습니다. 미터 표시와 무작위 위치의 레이더를 없애고, 찾은 기기와 실제 상태를 목록으로 보여 줍니다.
• iPhone 8, SE 등 작은 화면에서 탐색과 연결 화면을 스크롤할 수 있어, 하단 바 아래에 버튼이 가려지지 않습니다.
• 작은 화면에서 메인 화면을 더 간결하게 만들었습니다.
• Pro 화면은 Apple ID로 실제 받을 수 있을 때만 무료 체험을 표시하고, 버튼에도 분명히 알려 줍니다.
```

**Descrizione** (1169 caratteri)

```
버튼 하나로 가까이 있는 사람과 대화하세요. 휴대폰 신호도, 인터넷도 필요 없습니다. Talky는 Wi-Fi와 Bluetooth로 iPhone끼리 직접 연결합니다. 누르고 말한 뒤 손을 떼면 채널의 모두에게 메시지가 전달됩니다.

작동 방식, 솔직하게
• 모두 Talky를 열고 Wi-Fi와 Bluetooth를 켜 두어야 합니다. 네트워크에 연결할 필요는 없습니다.
• iPhone 두 대 사이의 일반적인 거리: 10~30미터. 탁 트인 야외에서는 더 멀리, 벽이나 층을 사이에 두면 더 짧아집니다.
• 같은 Wi-Fi 네트워크에서는 네트워크가 닿는 곳 어디서나 작동하며, Mac용 Talky와도 대화할 수 있습니다.
• 누르고 있는 동안 말하세요. 버튼에서 손을 떼는 순간 메시지가 전송됩니다.
• 최대 8대까지 동시에 연결됩니다.
• Talky는 무전기가 아닙니다. 생활무전기나 CB 무전기와는 통신하지 않으며, Talky를 사용하는 기기끼리만 대화합니다.

인터넷 라디오
80개국 이상, 300개 이상의 방송국을 인터넷 스트리밍으로 제공합니다(이 기능에는 인터넷 연결이 필요합니다). iPhone에는 FM 수신기가 없으며, 방송국 옆에 표시된 주파수는 해당 방송국이 자국에서 송출하는 주파수입니다.

TALKY PRO
Talky는 광고와 함께 무료입니다. Talky Pro는 광고를 없애고 모든 방송국, 송신 녹음, 비밀번호가 있는 개인 채널, 테마, 기록, 슬립 타이머, 이퀄라이저를 제공합니다. 연간 플랜에는 아직 사용하지 않은 분을 위한 무료 체험이 포함되어 있으며, 구독 없는 1회 구매도 있습니다.

Talky의 코드는 PolyForm Noncommercial 1.0.0 라이선스로 GitHub에 공개되어 있습니다: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Talky Pro 구독은 현재 기간 종료 최소 24시간 전에 취소하지 않으면 각 기간이 끝날 때 자동 갱신됩니다. 구매 확인 시 Apple ID 계정으로 요금이 청구됩니다. 구독은 Apple ID 설정에서 관리 및 취소할 수 있습니다.
```

### zh-Hans

**Parole chiave** (75 caratteri)

```
对讲,步话机,一键通,ptt,离线,无网,蓝牙,户外,徒步,登山,露营,儿童,应急,近距离,免费,通话,手台,局域网,wifi,家庭,团队,骑行,滑雪
```

**Testo promozionale** (gia' live sulla 2.47, 78 caratteri)

```
没有手机信号、没有网络，也能和身边的人通话。iPhone 之间通过 Wi-Fi 和蓝牙直接连接，典型距离 10 到 30 米。每个人都需要安装 Talky。
```

**Novita' di questa versione**

```
• “探索”页面不再显示编造的距离：带米数和随机位置的雷达已移除，改为列出找到的设备及其真实状态。
• 在 iPhone 8、SE 等小屏幕上，“探索”和“连接”页面现在可以滚动，按钮不会再被底部栏挡住。
• 小屏幕上的主界面更紧凑。
• Pro 页面只在你的 Apple 账户确实能获得免费试用时才显示，按钮上也会写清楚。
```

**Descrizione** (857 caratteri)

```
按一下按钮，就能和身边的人通话，不需要手机信号，也不需要互联网。Talky 通过 Wi-Fi 和蓝牙把 iPhone 直接连在一起：按住、说话、松开，消息就会送到频道里的每个人。

工作方式，说清楚
• 每个人都要打开 Talky，并开启 Wi-Fi 和蓝牙。不需要连接任何网络。
• 两台 iPhone 之间的典型距离：10 到 30 米。空旷的户外更远，隔着墙壁和楼板会更近。
• 在同一个 Wi-Fi 网络中，网络覆盖到的地方都能用，也能和 Mac 版 Talky 通话。
• 按住说话：松开按钮的那一刻消息就会发出。
• 最多 8 台设备同时连接。
• Talky 不是无线电对讲机：它不能和 PMR 或 CB 对讲机通话，只能和其他安装了 Talky 的设备通话。

网络电台
来自 80 多个国家的 300 多个电台，通过互联网播放（这部分需要联网）。iPhone 没有 FM 接收器：电台旁显示的频率，是该电台在其所在国家使用的播出频率。

TALKY PRO
Talky 免费使用，含广告。Talky Pro 去除广告，并提供全部电台、通话录音、带密码的私人频道、主题、历史记录、睡眠定时器和均衡器。年度方案为还没用过试用的用户提供免费试用，另有一次性购买，无需订阅。

Talky 的代码公开在 GitHub 上，采用 PolyForm Noncommercial 1.0.0 许可证：https://github.com/andreapianidev/WalkieTalkie

使用条款 (EULA)：https://walkie-talky.vercel.app/terms
隐私政策：https://walkie-talky.vercel.app/privacy
Cookie 政策：https://walkie-talky.vercel.app/cookies

Talky Pro 订阅会在每个周期结束时自动续订，除非在当期结束前至少 24 小时取消。款项将在您确认购买时从您的 Apple ID 账户扣除。您可以在 Apple ID 设置中管理或取消订阅。
```

### zh-Hant

**Parole chiave** (76 caratteri)

```
對講,步話機,一鍵通,ptt,離線,無網,藍牙,戶外,徒步,登山,露營,兒童,應急,近距離,免費,通話,手台,區域網路,wifi,家庭,團隊,騎行,滑雪
```

**Testo promozionale** (gia' live sulla 2.47, 79 caratteri)

```
沒有手機訊號、沒有網路，也能和身邊的人通話。iPhone 之間透過 Wi-Fi 和藍牙直接連線，典型距離 10 到 30 公尺。每個人都需要安裝 Talky。
```

**Novita' di questa versione**

```
• 「探索」頁面不再顯示編造的距離：帶公尺數和隨機位置的雷達已移除，改為列出找到的裝置及其真實狀態。
• 在 iPhone 8、SE 等小螢幕上，「探索」和「連線」頁面現在可以捲動，按鈕不會再被底部列擋住。
• 小螢幕上的主畫面更精簡。
• Pro 頁面只在你的 Apple 帳號確實能獲得免費試用時才顯示，按鈕上也會寫清楚。
```

**Descrizione** (858 caratteri)

```
按一下按鈕，就能和身邊的人通話，不需要手機訊號，也不需要網路。Talky 透過 Wi-Fi 和藍牙把 iPhone 直接連在一起：按住、說話、放開，訊息就會送到頻道裡的每個人。

運作方式，說清楚
• 每個人都要開啟 Talky，並打開 Wi-Fi 和藍牙。不需要連上任何網路。
• 兩台 iPhone 之間的典型距離：10 到 30 公尺。空曠的戶外更遠，隔著牆壁和樓板會更近。
• 在同一個 Wi-Fi 網路中，網路涵蓋的地方都能使用，也能和 Mac 版 Talky 通話。
• 按住說話：放開按鈕的那一刻訊息就會送出。
• 最多 8 台裝置同時連線。
• Talky 不是無線電對講機：它無法和 PMR 或 CB 對講機通話，只能和其他安裝了 Talky 的裝置通話。

網路電台
來自 80 多個國家的 300 多個電台，透過網路播放（這部分需要連網）。iPhone 沒有 FM 接收器：電台旁顯示的頻率，是該電台在其所在國家使用的播出頻率。

TALKY PRO
Talky 免費使用，含廣告。Talky Pro 移除廣告，並提供全部電台、通話錄音、有密碼的私人頻道、主題、歷史紀錄、睡眠定時器和等化器。年度方案為尚未使用過試用的使用者提供免費試用，另有一次性購買，無需訂閱。

Talky 的程式碼公開在 GitHub 上，採用 PolyForm Noncommercial 1.0.0 授權：https://github.com/andreapianidev/WalkieTalkie

使用條款 (EULA)：https://walkie-talky.vercel.app/terms
隱私政策：https://walkie-talky.vercel.app/privacy
Cookie 政策：https://walkie-talky.vercel.app/cookies

Talky Pro 訂閱會於每個週期結束時自動續訂，除非在當期結束前至少 24 小時取消。款項將於您確認購買時從您的 Apple ID 帳戶扣除。您可以在 Apple ID 設定中管理或取消訂閱。
```

### th

**Parole chiave** (93 caratteri)

```
วิทยุสื่อสาร,วอล์คกี้ทอล์คกี้,ออฟไลน์,อินเตอร์คอม,บลูทูธ,bluetooth,เดินป่า,แคมป์ปิ้ง,เด็ก,ฟรี
```

**Testo promozionale** (gia' live sulla 2.47, 143 caratteri)

```
คุยกับคนใกล้ ๆ ได้โดยไม่ต้องใช้สัญญาณมือถือหรืออินเทอร์เน็ต iPhone เชื่อมต่อกันโดยตรงผ่าน Wi-Fi และบลูทูธ ระยะทั่วไป 10-30 ม. ทุกคนต้องมี Talky
```

**Novita' di questa versione**

```
• หน้าสำรวจไม่แสดงระยะทางที่แต่งขึ้นอีกแล้ว เรดาร์ที่มีเมตรและตำแหน่งสุ่มถูกเอาออก แทนด้วยรายการอุปกรณ์ที่พบพร้อมสถานะจริง
• บน iPhone 8, SE และหน้าจอขนาดเล็กอื่น ๆ หน้าสำรวจและการเชื่อมต่อเลื่อนได้แล้ว ปุ่มจะไม่ถูกซ่อนใต้แถบด้านล่างอีก
• หน้าจอหลักกระชับขึ้นบนหน้าจอขนาดเล็ก
• หน้าจอ Pro จะแสดงการทดลองใช้ฟรีเฉพาะเมื่อ Apple ID ของคุณได้รับจริง และปุ่มก็บอกไว้ชัดเจน
```

**Descrizione** (1734 caratteri)

```
คุยกับคนที่อยู่ใกล้ ๆ ได้ด้วยการกดปุ่มเดียว ไม่ต้องใช้สัญญาณมือถือและไม่ต้องใช้อินเทอร์เน็ต Talky เชื่อมต่อ iPhone เข้าหากันโดยตรงผ่าน Wi-Fi และบลูทูธ กดค้าง พูด แล้วปล่อย ข้อความจะถึงทุกคนในช่อง

วิธีการทำงาน แบบตรงไปตรงมา
• ทุกคนต้องเปิด Talky ไว้ และเปิด Wi-Fi กับบลูทูธ โดยไม่จำเป็นต้องเชื่อมต่อเครือข่ายใด ๆ
• ระยะทั่วไประหว่าง iPhone สองเครื่อง: 10 ถึง 30 เมตร ไกลกว่านั้นในที่โล่งกลางแจ้ง และสั้นลงเมื่อมีผนังหรือพื้นกั้น
• เมื่ออยู่ในเครือข่าย Wi-Fi เดียวกัน ใช้ได้ทุกที่ที่เครือข่ายไปถึง รวมถึงกับ Talky บน Mac
• กดค้างเพื่อพูด ข้อความจะถูกส่งทันทีที่คุณปล่อยปุ่ม
• เชื่อมต่อได้พร้อมกันสูงสุด 8 เครื่อง
• Talky ไม่ใช่วิทยุสื่อสาร จึงคุยกับวิทยุสื่อสาร PMR หรือ CB ไม่ได้ คุยได้เฉพาะกับอุปกรณ์อื่นที่ใช้ Talky

วิทยุออนไลน์
สถานีมากกว่า 300 แห่งจากกว่า 80 ประเทศ สตรีมผ่านอินเทอร์เน็ต (ส่วนนี้ต้องใช้การเชื่อมต่อ) iPhone ไม่มีตัวรับสัญญาณ FM ความถี่ที่แสดงข้างสถานีคือความถี่ที่สถานีนั้นใช้ออกอากาศในประเทศของตน

TALKY PRO
Talky ใช้ได้ฟรีโดยมีโฆษณา Talky Pro จะเอาโฆษณาออกและเพิ่มทุกสถานี การบันทึกการส่งสัญญาณ ช่องส่วนตัวพร้อมรหัสผ่าน ธีม ประวัติ ตัวตั้งเวลาปิด และอีควอไลเซอร์ แผนรายปีมีช่วงทดลองใช้ฟรีสำหรับผู้ที่ยังไม่เคยใช้ และยังมีแบบซื้อครั้งเดียวโดยไม่ต้องสมัครสมาชิก

โค้ดของ Talky เปิดเป็นสาธารณะบน GitHub ภายใต้สัญญาอนุญาต PolyForm Noncommercial 1.0.0: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Talky Pro subscription auto-renews at the end of each period unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account at confirmation of purchase. You can manage and cancel your subscription in your Apple ID Settings.
```

### tr

**Parole chiave** (99 caratteri)

```
telsiz,walkietalkie,ptt,push to talk,çevrimdışı,offline,intercom,bluetooth,kamp,doğa,çocuk,ücretsiz
```

**Testo promozionale** (gia' live sulla 2.47, 158 caratteri)

```
Mobil şebeke ve internet olmadan yakınınızdakilerle konuşun. iPhone'lar Wi-Fi ve Bluetooth ile doğrudan bağlanır, tipik menzil 10-30 m. Herkeste Talky olmalı.
```

**Novita' di questa versione**

```
• Keşfet artık uydurma mesafeler göstermiyor: metreli ve rastgele konumlu radar kaldırıldı, yerine bulunan cihazların gerçek durumlarıyla bir liste geldi.
• iPhone 8, SE ve diğer küçük ekranlarda Keşfet ve Bağlantılar artık kaydırılabiliyor: hiçbir düğme alttaki çubuğun altında gizli kalmıyor.
• Ana ekran küçük ekranlarda daha derli toplu.
• Pro ekranı ücretsiz denemeyi yalnızca Apple Kimliğiniz gerçekten alabiliyorsa gösteriyor ve düğme bunu açıkça belirtiyor.
```

**Descrizione** (1883 caratteri)

```
Yakınınızdakilerle tek tuşla konuşun; mobil şebeke ve internet gerekmez. Talky, iPhone'ları Wi-Fi ve Bluetooth üzerinden birbirine doğrudan bağlar: basılı tutun, konuşun, bırakın; mesajınız kanaldaki herkese ulaşır.

NASIL ÇALIŞIR, SÜRPRIZSIZ
• Herkesin Talky'yi açık tutması, Wi-Fi ve Bluetooth'u açması gerekir. Bir ağa bağlı olmanız gerekmez.
• İki iPhone arasındaki tipik menzil: 10-30 metre. Açık alanda engelsiz ortamda daha fazla, duvar ve kat arasında daha az.
• Aynı Wi-Fi ağında, ağın ulaştığı her yerde çalışır; Mac için Talky ile de.
• Konuşmak için basılı tutun: mesaj, tuşu bıraktığınız anda gönderilir.
• Aynı anda en fazla 8 cihaz bağlanabilir.
• Talky bir telsiz cihazı değildir: PMR veya CB telsizlerle konuşamaz, yalnızca Talky kullanan diğer cihazlarla konuşur.

İNTERNET RADYOSU
80'den fazla ülkeden 300'ü aşkın istasyon, internet üzerinden yayın (bu bölüm için bağlantı gerekir). iPhone'da FM alıcısı yoktur: bir istasyonun yanında görünen frekans, o yayıncının kendi ülkesinde kullandığı frekanstır.

TALKY PRO
Talky reklamlı olarak ücretsizdir. Talky Pro reklamları kaldırır; tüm istasyonları, yayınlarınızın kaydını, şifreli özel kanalları, temaları, geçmişi, uyku zamanlayıcısını ve ekolayzırı ekler. Yıllık plan, daha önce kullanmadıysanız ücretsiz deneme içerir; ayrıca aboneliksiz tek seferlik satın alma da vardır.

Talky'nin kodu, PolyForm Noncommercial 1.0.0 lisansıyla GitHub'da herkese açıktır: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Talky Pro aboneliği, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece her dönem sonunda otomatik olarak yenilenir. Ödeme, satın alma onayında Apple ID hesabınızdan tahsil edilir. Aboneliğinizi Apple ID Ayarlarınızdan yönetebilir ve iptal edebilirsiniz.
```

### vi

**Parole chiave** (93 caratteri)

```
walkietalkie,ptt,push to talk,ngoại tuyến,offline,intercom,bluetooth,trẻ em,cắm trại,miễn phí
```

**Testo promozionale** (gia' live sulla 2.47, 163 caratteri)

```
Nói chuyện với người ở gần mà không cần sóng di động hay Internet. iPhone kết nối trực tiếp qua Wi-Fi và Bluetooth, tầm thường gặp 10-30 m. Mọi người cần có Talky.
```

**Novita' di questa versione**

```
• Khám phá không còn hiển thị khoảng cách bịa ra: radar có mét và vị trí ngẫu nhiên đã được bỏ, thay bằng danh sách thiết bị tìm thấy cùng trạng thái thật.
• Trên iPhone 8, SE và các màn hình nhỏ khác, màn hình Khám phá và Kết nối giờ đã cuộn được: không còn nút nào bị che dưới thanh phía dưới.
• Màn hình chính gọn hơn trên màn hình nhỏ.
• Màn hình Pro chỉ hiển thị dùng thử miễn phí khi Apple ID của bạn thực sự nhận được, và nút bấm ghi rõ điều đó.
```

**Descrizione** (1813 caratteri)

```
Nói chuyện với người ở gần chỉ bằng một nút bấm, không cần sóng di động và không cần Internet. Talky kết nối trực tiếp các iPhone với nhau qua Wi-Fi và Bluetooth: giữ nút, nói, thả ra, và tin nhắn đến mọi người trong kênh.

CÁCH HOẠT ĐỘNG, NÓI RÕ RÀNG
• Mọi người cần mở Talky, bật Wi-Fi và Bluetooth. Không cần kết nối vào mạng nào.
• Tầm hoạt động thường gặp giữa hai iPhone: 10-30 mét. Xa hơn ở ngoài trời thoáng, gần hơn khi có tường và sàn nhà chắn.
• Trong cùng một mạng Wi-Fi, ứng dụng hoạt động ở mọi nơi mạng phủ tới, kể cả với Talky cho Mac.
• Giữ để nói: tin nhắn được gửi ngay khi bạn thả nút.
• Tối đa 8 thiết bị kết nối cùng lúc.
• Talky không phải máy bộ đàm vô tuyến: không liên lạc được với bộ đàm PMR hay CB, chỉ với các thiết bị khác đang dùng Talky.

RADIO INTERNET
Hơn 300 đài từ hơn 80 quốc gia, phát trực tuyến qua Internet (phần này cần kết nối mạng). iPhone không có bộ thu FM: tần số hiển thị cạnh một đài là tần số mà đài đó phát sóng ở nước của họ.

TALKY PRO
Talky miễn phí và có quảng cáo. Talky Pro bỏ quảng cáo và thêm tất cả các đài, ghi âm các lần truyền, kênh riêng có mật khẩu, giao diện, lịch sử, hẹn giờ tắt và bộ chỉnh âm. Gói năm có dùng thử miễn phí cho người chưa từng dùng, và còn có gói mua một lần, không cần đăng ký.

Mã nguồn của Talky được công khai trên GitHub, theo giấy phép PolyForm Noncommercial 1.0.0: https://github.com/andreapianidev/WalkieTalkie

Terms of Use (EULA): https://walkie-talky.vercel.app/terms
Privacy Policy: https://walkie-talky.vercel.app/privacy
Cookie Policy: https://walkie-talky.vercel.app/cookies

Talky Pro subscription auto-renews at the end of each period unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account at confirmation of purchase. You can manage and cancel your subscription in your Apple ID Settings.
```
