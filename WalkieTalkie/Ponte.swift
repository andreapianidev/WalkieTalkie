//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - Ponte.swift
//  Talky
//
//  Il ponte fra telefoni vicini: A parla con C passando da B. Ogni telefono
//  suona quello che riceve e lo ritrasmette ai propri peer, una tratta in meno
//  ogni volta. Serve dove la portata di un telefono non basta: concerti,
//  campeggi, piste da sci.
//
//  La stessa intestazione viaggia su Multipeer (in testa al Float32, vedi
//  `IntestazioneMultipeer`) e su TALKY1 (come campi in piu' di AUDIO_META), cosi'
//  un iPhone fa da ponte anche fra un iPhone e un Android o un Mac.
//  Gemella del Mac in macTalky/Core/Ponte.swift, di Android in protocol/Trasmissione.kt.

import Foundation

/// Una trasmissione PTT come gira fra i telefoni. `nonisolated` perche' la
/// toccano anche le code di rete, non solo il main.
nonisolated struct Trasmissione {
    /// Due tratte: A -> B -> C. Di piu' moltiplica il traffico in una folla
    /// senza portare la voce molto piu' lontano. E' anche il massimo che si
    /// accetta: un ttl piu' alto in arrivo viene abbassato a questo.
    static let ttlIniziale = 2

    /// Quello che arriva da un altro telefono si taglia qui: un peer difettoso
    /// o modificato non deve poter far crescere l'intestazione senza limite.
    enum Limite {
        static let id = 64
        static let origine = 64
        static let nome = 64
        static let raggiunti = 64
        /// Audio ritrasmesso su Multipeer: 30 s di Float32 a 48 kHz.
        static let audioPonte = 48_000 * 4 * 30
    }

    let id: String
    /// uid di chi ha parlato, e il suo nome da mostrare a chi ascolta.
    let origine: String
    let nomeOrigine: String
    var ttl: Int
    /// id corti dei dispositivi che l'hanno gia' ricevuta da chi l'ha mandata:
    /// chi fa da ponte non gliela rimanda. In un gruppo dove tutti sono
    /// collegati con tutti, senza questo elenco ogni messaggio verrebbe
    /// ricopiato da ognuno a ognuno.
    var raggiunti: Set<String>

    static func nuova(nome: String) -> Trasmissione {
        Trasmissione(
            id: UUID().uuidString,
            origine: Ponte.shared.uidLocale,
            nomeOrigine: String(nome.prefix(Limite.nome)),
            ttl: ttlIniziale,
            raggiunti: [Ponte.idCorto(Ponte.shared.uidLocale)]
        )
    }

    /// Chiavi in piu' di AUDIO_META. Le versioni vecchie leggono solo le loro e
    /// ignorano queste, quindi suonano il messaggio come sempre.
    enum Chiave {
        static let id = "msgId"
        static let origine = "origin"
        static let nomeOrigine = "originName"
        static let ttl = "ttl"
        static let raggiunti = "reached"
        /// "1" quando l'audio arriva a pezzi fino ad AUDIO_END (Android).
        static let flusso = "stream"
    }

    var campi: [String: String] {
        [
            Chiave.id: id,
            Chiave.origine: origine,
            Chiave.nomeOrigine: nomeOrigine,
            Chiave.ttl: String(ttl),
            Chiave.raggiunti: raggiunti.sorted().prefix(Limite.raggiunti).joined(separator: ",")
        ]
    }

    /// nil se mancano id o ttl (il messaggio viene da una versione senza
    /// ponte) o se l'id e' fuori misura.
    init?(campi: [String: String]) {
        guard let id = campi[Chiave.id], !id.isEmpty, id.count <= Limite.id,
              let ttl = campi[Chiave.ttl].flatMap(Int.init) else { return nil }
        self.id = id
        self.origine = String((campi[Chiave.origine] ?? "").prefix(Limite.origine))
        self.nomeOrigine = String((campi[Chiave.nomeOrigine] ?? "").prefix(Limite.nome))
        self.ttl = min(ttl, Self.ttlIniziale)
        self.raggiunti = Set((campi[Chiave.raggiunti] ?? "")
            .split(separator: ",")
            .prefix(Limite.raggiunti)
            .map { Ponte.idCorto(String($0)) })
    }

    private init(id: String, origine: String, nomeOrigine: String, ttl: Int, raggiunti: Set<String>) {
        self.id = id
        self.origine = origine
        self.nomeOrigine = nomeOrigine
        self.ttl = ttl
        self.raggiunti = raggiunti
    }

    /// La copia da ritrasmettere: una tratta in meno, e chi l'aveva gia'.
    func perIlPonte(arrivataDa uid: String?) -> Trasmissione {
        var copia = self
        copia.ttl = ttl - 1
        copia.raggiunti.insert(Ponte.idCorto(Ponte.shared.uidLocale))
        copia.raggiunti.insert(Ponte.idCorto(origine))
        if let uid { copia.raggiunti.insert(Ponte.idCorto(uid)) }
        return copia
    }
}

nonisolated final class Ponte: @unchecked Sendable {
    static let shared = Ponte()

    /// Un id per avvio, lo stesso su Multipeer e TALKY1: al ponte serve solo
    /// riconoscere un dispositivo dentro una sessione, anche se lo vede da due
    /// trasporti. Cambia a ogni avvio perche' viaggia in chiaro nella ricerca
    /// dei vicini e un id fisso renderebbe il telefono riconoscibile per sempre.
    /// Chi e' gia' stato accettato si riconosce con il segreto della coppia
    /// (`CoppieFidate` in MultipeerManager.swift), non con questo.
    let uidLocale = UUID().uuidString

    private let lock = NSLock()
    /// Messaggi arrivati interi (o mandati da qui): un'altra copia e' un doppione.
    private var visti: Set<String> = []
    private var ordine: [String] = []
    /// Messaggi che stanno arrivando a pezzi: una seconda copia in parallelo si
    /// scarta, ma se questa si interrompe una copia intera e' ancora benvenuta.
    private var inCorso: Set<String> = []
    /// Bastano gli ultimi: un doppione arriva entro pochi secondi dall'originale.
    private let memoria = 256

    private init() {
        // Le build 141 e 142 tenevano un id fisso: lo si toglie.
        UserDefaults.standard.removeObject(forKey: "talky_device_uid")
    }

    static func idCorto(_ uid: String) -> String {
        String(uid.lowercased().prefix(8))
    }

    /// Per i messaggi che arrivano interi in un colpo solo (Multipeer): vero la
    /// prima volta, falso per i doppioni e per un messaggio che sta gia'
    /// arrivando da un altro trasporto.
    func primaVolta(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !visti.contains(id), !inCorso.contains(id) else { return false }
        ricordaLocked(id)
        return true
    }

    /// Un messaggio partito da qui: se torna indietro da un ponte non si suona.
    func segna(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        ricordaLocked(id)
    }

    /// Comincia ad arrivare un messaggio a pezzi (TALKY1). Falso se e' un
    /// doppione o se un'altra copia sta gia' arrivando.
    func inizia(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !visti.contains(id), !inCorso.contains(id) else { return false }
        if inCorso.count >= memoria { inCorso.removeAll() }
        inCorso.insert(id)
        return true
    }

    /// Il messaggio e' arrivato tutto: da qui le altre copie sono doppioni.
    func completa(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        inCorso.remove(id)
        ricordaLocked(id)
    }

    /// La connessione e' caduta a meta': una copia intera da un ponte passera'.
    func abbandona(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        inCorso.remove(id)
    }

    private func ricordaLocked(_ id: String) {
        guard visti.insert(id).inserted else { return }
        ordine.append(id)
        if ordine.count > memoria {
            visti.remove(ordine.removeFirst())
        }
    }
}

/// Quello che puo' viaggiare su Multipeer con l'intestazione del ponte.
nonisolated enum MessaggioMultipeer {
    /// Una trasmissione, con la voce dopo l'intestazione.
    case trasmissione(Trasmissione, audio: Data)
    /// Il segreto della coppia, mandato una volta da chi ha accettato a mano.
    case coppia(segreto: Data)
}

/// L'intestazione del ponte su Multipeer, in testa all'audio Float32.
///
/// Le versioni vecchie suonano tutto il messaggio come campioni Float32, senza
/// guardare cosa c'e' dentro. Quindi ogni parola dell'intestazione e' un Float32
/// con i due byte alti a zero: letto come campione e' un numero subnormale sotto
/// 1e-40, cioe' silenzio, e dura un paio di millisecondi. Subito dopo viene la
/// voce, intatta e allineata, che le versioni vecchie suonano come sempre.
///
/// Parole (UInt32 little-endian, solo i 16 bit bassi usati):
///   0x4B54 0x3152 ("TK" "R1") per una trasmissione, 0x4B54 0x3150 ("TK" "P1")
///   per il segreto della coppia; poi il numero di parole di testo, poi il testo
///   "k=v|k=v" due byte per parola. Il segreto parte solo verso chi annuncia il
///   ponte: una versione vecchia non lo riceve mai.
nonisolated enum IntestazioneMultipeer {
    private static let firma: UInt16 = 0x4B54
    private static let tipoTrasmissione: UInt16 = 0x3152
    private static let tipoCoppia: UInt16 = 0x3150
    /// 4 KB di testo bastano e avanzano: oltre, il messaggio non e' nostro.
    private static let massimoParole = 2048
    private static let chiaveSegreto = "s"

    static func impacchetta(_ trasmissione: Trasmissione, audio: Data) -> Data {
        intestazione(tipo: tipoTrasmissione, campi: trasmissione.campi) + audio
    }

    static func impacchettaCoppia(segreto: Data) -> Data {
        intestazione(tipo: tipoCoppia, campi: [chiaveSegreto: segreto.base64EncodedString()])
    }

    private static func intestazione(tipo: UInt16, campi: [String: String]) -> Data {
        let testo = Array(codificaCampi(campi).utf8.prefix(massimoParole * 2))
        var parole: [UInt16] = []
        parole.reserveCapacity(testo.count / 2 + 1)
        var i = 0
        while i < testo.count {
            let basso = UInt16(testo[i])
            let alto = i + 1 < testo.count ? UInt16(testo[i + 1]) : 0
            parole.append(basso | alto << 8)
            i += 2
        }

        var messaggio = Data()
        messaggio.reserveCapacity((3 + parole.count) * 4)
        for parola in [firma, tipo, UInt16(clamping: parole.count)] + parole {
            messaggio.append(contentsOf: [UInt8(parola & 0xFF), UInt8(parola >> 8), 0, 0])
        }
        return messaggio
    }

    /// nil se il messaggio e' Float32 nudo di una versione vecchia.
    static func spacchetta(_ messaggio: Data) -> MessaggioMultipeer? {
        let byte = [UInt8](messaggio.prefix(12))
        guard byte.count == 12 else { return nil }
        func parola(_ n: Int, da b: [UInt8]) -> UInt16? {
            let o = n * 4
            guard b[o + 2] == 0, b[o + 3] == 0 else { return nil }
            return UInt16(b[o]) | UInt16(b[o + 1]) << 8
        }
        guard parola(0, da: byte) == firma,
              let tipo = parola(1, da: byte), tipo == tipoTrasmissione || tipo == tipoCoppia,
              let quante = parola(2, da: byte), Int(quante) <= massimoParole else { return nil }

        let fineTesto = 12 + Int(quante) * 4
        guard messaggio.count >= fineTesto else { return nil }
        let corpo = [UInt8](messaggio.subdata(in: messaggio.startIndex + 12 ..< messaggio.startIndex + fineTesto))
        var testo: [UInt8] = []
        testo.reserveCapacity(Int(quante) * 2)
        for n in 0..<Int(quante) {
            guard let p = parola(n, da: corpo) else { return nil }
            testo.append(UInt8(p & 0xFF))
            testo.append(UInt8(p >> 8))
        }
        while testo.last == 0 { testo.removeLast() }

        guard let riga = String(bytes: testo, encoding: .utf8) else { return nil }
        let campi = decodificaCampi(riga)
        if tipo == tipoCoppia {
            guard let s = campi[chiaveSegreto].flatMap({ Data(base64Encoded: $0) }), s.count == 32 else { return nil }
            return .coppia(segreto: s)
        }
        guard let trasmissione = Trasmissione(campi: campi) else { return nil }
        let audio = messaggio.subdata(in: messaggio.startIndex + fineTesto ..< messaggio.endIndex)
        return .trasmissione(trasmissione, audio: audio)
    }

    // Stessa codifica dei campi TALKY1 (percent-encoding, "|" fra i campi).
    private static func codificaCampi(_ campi: [String: String]) -> String {
        var ammessi = CharacterSet.alphanumerics
        ammessi.insert(charactersIn: "-._~")
        return campi
            .map { "\($0.key.addingPercentEncoding(withAllowedCharacters: ammessi) ?? $0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: ammessi) ?? $0.value)" }
            .joined(separator: "|")
    }

    private static func decodificaCampi(_ riga: String) -> [String: String] {
        var campi: [String: String] = [:]
        for parte in riga.split(separator: "|") {
            guard let uguale = parte.firstIndex(of: "=") else { continue }
            let k = String(parte[..<uguale])
            let v = String(parte[parte.index(after: uguale)...])
            campi[k.removingPercentEncoding ?? k] = v.removingPercentEncoding ?? v
        }
        return campi
    }
}
