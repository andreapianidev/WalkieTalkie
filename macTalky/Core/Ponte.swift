//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - Ponte.swift
//  macTalky
//
//  Porta macOS del ponte A-B-C (WalkieTalkie/Ponte.swift su iOS,
//  protocol/Trasmissione.kt su Android). Il Mac parla solo TALKY1, quindi qui
//  manca l'intestazione Multipeer: id, mittente e tratte viaggiano come campi
//  in piu' di AUDIO_META, che le versioni vecchie ignorano.

import Foundation

/// Una trasmissione PTT come gira fra i dispositivi.
nonisolated struct Trasmissione {
    /// Due tratte: A -> B -> C. E' anche il massimo accettato in arrivo.
    static let ttlIniziale = 2

    /// Quello che arriva da un altro dispositivo si taglia qui: un peer
    /// difettoso o modificato non deve far crescere i campi senza limite.
    enum Limite {
        static let id = 64
        static let origine = 64
        static let nome = 64
        static let raggiunti = 64
    }

    let id: String
    let origine: String
    let nomeOrigine: String
    var ttl: Int
    /// id corti di chi l'ha gia' ricevuta direttamente: il ponte non gliela rimanda.
    var raggiunti: Set<String>

    enum Chiave {
        static let id = "msgId"
        static let origine = "origin"
        static let nomeOrigine = "originName"
        static let ttl = "ttl"
        static let raggiunti = "reached"
        static let flusso = "stream"
    }

    static func nuova(origine: String, nome: String, destinatari: [String]) -> Trasmissione {
        Trasmissione(
            id: UUID().uuidString,
            origine: origine,
            nomeOrigine: nome,
            ttl: ttlIniziale,
            raggiunti: Set(([origine] + destinatari).prefix(Limite.raggiunti).map(Ponte.idCorto))
        )
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

    /// nil se il messaggio viene da una versione senza ponte o se l'id e' fuori misura.
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

    /// La copia da ritrasmettere: una tratta in meno, e chi l'ha gia'.
    func perIlPonte(locale: String, arrivataDa uid: String?, destinatari: [String]) -> Trasmissione {
        var copia = self
        copia.ttl = ttl - 1
        let gia = [locale, origine] + (uid.map { [$0] } ?? []) + destinatari
        copia.raggiunti.formUnion(gia.map(Ponte.idCorto))
        return copia
    }
}

/// Memoria degli ultimi id visti, per scartare i doppioni: lo stesso messaggio
/// arriva diretto e passando da un ponte. Un id conta come visto solo quando il
/// messaggio e' arrivato tutto: se una connessione cade a meta', la copia intera
/// da un altro ponte deve ancora passare. Toccata da `WalkieEngine.queue`.
nonisolated final class Ponte: @unchecked Sendable {
    private let lock = NSLock()
    private var visti: Set<String> = []
    private var ordine: [String] = []
    private var inCorso: Set<String> = []
    private let memoria = 256

    static func idCorto(_ uid: String) -> String {
        String(uid.lowercased().prefix(8))
    }

    /// Vero la prima volta per un messaggio che arriva intero; falso per i
    /// doppioni e per uno che sta gia' arrivando da un'altra connessione.
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

    /// Comincia ad arrivare un messaggio: falso se e' un doppione o se un'altra
    /// copia sta gia' arrivando.
    func inizia(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !visti.contains(id), !inCorso.contains(id) else { return false }
        if inCorso.count >= memoria { inCorso.removeAll() }
        inCorso.insert(id)
        return true
    }

    func completa(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        inCorso.remove(id)
        ricordaLocked(id)
    }

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
