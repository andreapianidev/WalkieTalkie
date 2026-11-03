//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - StationHealth.swift
//  Talky (iOS e Mac)
//
//  L'elenco delle radio si aggiorna da solo: una stazione che non parte due
//  volte di fila sparisce dall'elenco per sette giorni, poi riceve un'altra
//  possibilita'. Basta che suoni una volta perche' il conto si azzeri. Cosi'
//  le stazioni chiuse spariscono senza aspettare un aggiornamento dell'app, e
//  quelle bloccate in un paese (le australiane fuori dall'Australia) spariscono
//  solo per chi non le riceve.

import Foundation

nonisolated final class StationHealth: @unchecked Sendable {
    static let shared = StationHealth()

    private let key = "radio_station_failures"
    private let rest: TimeInterval = 7 * 24 * 3600
    private let lock = NSLock()
    /// id -> (fallimenti di fila, ultimo fallimento)
    private var failures: [Int: (count: Int, last: Date)] = [:]

    private init() {
        let stored = UserDefaults.standard.dictionary(forKey: key) as? [String: [Double]] ?? [:]
        for (id, v) in stored where v.count == 2 {
            if let n = Int(id) { failures[n] = (Int(v[0]), Date(timeIntervalSince1970: v[1])) }
        }
    }

    /// La stazione e' a riposo: non si mostra.
    func isResting(_ id: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let f = failures[id] else { return false }
        return f.count >= 2 && Date().timeIntervalSince(f.last) < rest
    }

    func failed(_ id: Int) {
        lock.lock()
        let count = (failures[id]?.count ?? 0) + 1
        failures[id] = (count, Date())
        lock.unlock()
        save()
    }

    func played(_ id: Int) {
        lock.lock()
        let had = failures.removeValue(forKey: id) != nil
        lock.unlock()
        if had { save() }
    }

    private func save() {
        lock.lock()
        let out = Dictionary(uniqueKeysWithValues: failures.map { (String($0.key), [Double($0.value.count), $0.value.last.timeIntervalSince1970]) })
        lock.unlock()
        UserDefaults.standard.set(out, forKey: key)
    }
}
