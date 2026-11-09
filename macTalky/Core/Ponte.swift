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
    /// Due tratte: A -> B -> C.
    static let ttlIniziale = 2

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
            raggiunti: Set(([origine] + destinatari).map(Ponte.idCorto))
        )
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

    /// nil se il messaggio viene da una versione senza ponte.
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
/// arriva diretto e passando da un ponte. Toccata da `WalkieEngine.queue`.
nonisolated final class Ponte: @unchecked Sendable {
    private let lock = NSLock()
    private var visti: Set<String> = []
    private var ordine: [String] = []
    private let memoria = 256

    static func idCorto(_ uid: String) -> String {
        String(uid.lowercased().prefix(8))
    }

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
