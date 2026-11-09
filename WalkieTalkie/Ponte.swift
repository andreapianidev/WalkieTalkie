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
    /// senza portare la voce molto piu' lontano.
    static let ttlIniziale = 2

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
            nomeOrigine: nome,
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
            Chiave.raggiunti: raggiunti.sorted().joined(separator: ",")
        ]
    }

    /// nil se mancano id o ttl: il messaggio viene da una versione senza ponte.
    init?(campi: [String: String]) {
        guard let id = campi[Chiave.id], !id.isEmpty,
              let ttl = campi[Chiave.ttl].flatMap(Int.init) else { return nil }
        self.id = id
        self.origine = campi[Chiave.origine] ?? ""
        self.nomeOrigine = campi[Chiave.nomeOrigine] ?? ""
        self.ttl = ttl
        self.raggiunti = Set((campi[Chiave.raggiunti] ?? "").split(separator: ",").map(String.init))
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

    /// Un id per installazione, lo stesso su Multipeer e TALKY1. Fisso fra un
    /// avvio e l'altro perche' serve anche a riconoscere chi e' gia' stato
    /// accettato una volta. E' un UUID a caso, non dice niente del telefono.
    let uidLocale: String

    private let lock = NSLock()
    private var visti: Set<String> = []
    private var ordine: [String] = []
    /// Bastano gli ultimi: un doppione arriva entro pochi secondi dall'originale.
    private let memoria = 256

    private init() {
        let chiave = "talky_device_uid"
        if let salvato = UserDefaults.standard.string(forKey: chiave) {
            uidLocale = salvato
        } else {
            uidLocale = UUID().uuidString
            UserDefaults.standard.set(uidLocale, forKey: chiave)
        }
    }

    static func idCorto(_ uid: String) -> String {
        String(uid.lowercased().prefix(8))
    }

    /// Vero la prima volta che si vede questo id, falso per i doppioni. Lo
    /// stesso messaggio puo' arrivare due volte: diretto e passando da un ponte.
    func primaVolta(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !visti.contains(id) else { return false }
        visti.insert(id)
        ordine.append(id)
        if ordine.count > memoria {
            visti.remove(ordine.removeFirst())
        }
        return true
    }
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
///   0x4B54 0x3152 ("TK" "R1"), numero di parole di testo, poi il testo
///   "k=v|k=v" dei campi di `Trasmissione`, due byte per parola.
nonisolated enum IntestazioneMultipeer {
    private static let firma: [UInt16] = [0x4B54, 0x3152]

    static func impacchetta(_ trasmissione: Trasmissione, audio: Data) -> Data {
        let testo = Array(codificaCampi(trasmissione.campi).utf8)
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
        messaggio.reserveCapacity((firma.count + 1 + parole.count) * 4 + audio.count)
        for parola in firma + [UInt16(parole.count)] + parole {
            messaggio.append(contentsOf: [UInt8(parola & 0xFF), UInt8(parola >> 8), 0, 0])
        }
        messaggio.append(audio)
        return messaggio
    }

    /// nil se il messaggio e' Float32 nudo di una versione vecchia.
    static func spacchetta(_ messaggio: Data) -> (trasmissione: Trasmissione, audio: Data)? {
        let byte = [UInt8](messaggio.prefix(12))
        guard byte.count == 12 else { return nil }
        func parola(_ n: Int, da b: [UInt8]) -> UInt16? {
            let o = n * 4
            guard b[o + 2] == 0, b[o + 3] == 0 else { return nil }
            return UInt16(b[o]) | UInt16(b[o + 1]) << 8
        }
        guard parola(0, da: byte) == firma[0], parola(1, da: byte) == firma[1],
              let quante = parola(2, da: byte) else { return nil }

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

        guard let riga = String(bytes: testo, encoding: .utf8),
              let trasmissione = Trasmissione(campi: decodificaCampi(riga)) else { return nil }
        let audio = messaggio.subdata(in: messaggio.startIndex + fineTesto ..< messaggio.endIndex)
        return (trasmissione, audio)
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
