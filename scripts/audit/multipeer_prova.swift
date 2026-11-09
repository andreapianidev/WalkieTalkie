// Un finto secondo iPhone che parla Multipeer, per provare dal Mac l'app vera
// sul telefono, il caso "due iPhone non si trovano" delle recensioni.
//
// Fa quello che fa un altro Talky: si annuncia su "walkie-talkie" con le
// stesse chiavi (deviceName, channel, uid), cerca gli altri, invita il primo
// trovato con il canale nel context come fa `invitePeer`, e a collegamento
// fatto manda un La di un secondo nel formato dell'app (Float32 mono, nessuna
// intestazione) piu' un HEARTBEAT.
//
// Uso:  swift scripts/audit/multipeer_prova.swift [secondi] [canale]
// Sul canale pubblico l'iPhone chiede di accettare l'invito: va toccato
// "Accetta" sul telefono. Esce con 1 se il collegamento non riesce.

import Foundation
import MultipeerConnectivity

let durata = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 60 : 60
let canale = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "public"

final class Prova: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    let io = MCPeerID(displayName: "Talky Prova Mac")
    lazy var sessione = MCSession(peer: io, securityIdentity: nil, encryptionPreference: .optional)
    lazy var browser = MCNearbyServiceBrowser(peer: io, serviceType: "walkie-talkie")
    lazy var advertiser = MCNearbyServiceAdvertiser(
        peer: io,
        discoveryInfo: ["deviceName": "Talky Prova Mac", "channel": canale, "uid": UUID().uuidString],
        serviceType: "walkie-talkie")
    var trovati: [MCPeerID: [String: String]] = [:]
    var invitato: MCPeerID?
    var collegato = false
    var inizio = Date()

    func log(_ s: String) {
        print(String(format: "%5.1fs ", Date().timeIntervalSince(inizio)) + s)
        fflush(stdout)
    }

    func parti() {
        sessione.delegate = self
        browser.delegate = self
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        log("annuncio e cerco su walkie-talkie, canale \(canale)")
    }

    // MARK: browser
    func browser(_ b: MCNearbyServiceBrowser, foundPeer p: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        trovati[p] = info ?? [:]
        log("trovato \(p.displayName) info=\(info ?? [:])")
        guard invitato == nil, (info?["channel"] ?? "public") == canale else { return }
        invitato = p
        log("invito \(p.displayName): sul telefono tocca Accetta")
        b.invitePeer(p, to: sessione, withContext: canale.data(using: .utf8), timeout: 30)
    }

    func browser(_ b: MCNearbyServiceBrowser, lostPeer p: MCPeerID) {
        log("perso \(p.displayName)")
    }

    func browser(_ b: MCNearbyServiceBrowser, didNotStartBrowsingForPeers e: Error) {
        log("ERRORE il browser non parte: \(e)")
    }

    // MARK: advertiser
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer p: MCPeerID,
                    withContext c: Data?, invitationHandler h: @escaping (Bool, MCSession?) -> Void) {
        let ch = c.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        log("invito ricevuto da \(p.displayName), canale nel context: \(ch), accetto")
        h(true, sessione)
    }

    func advertiser(_ a: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer e: Error) {
        log("ERRORE l'annuncio non parte: \(e)")
    }

    // MARK: sessione
    func session(_ s: MCSession, peer p: MCPeerID, didChange stato: MCSessionState) {
        let nome = [MCSessionState.notConnected: "non collegato", .connecting: "in collegamento", .connected: "COLLEGATO"][stato] ?? "?"
        log("sessione con \(p.displayName): \(nome)")
        guard stato == .connected else { return }
        collegato = true
        // Un secondo di La a 440 Hz, Float32 mono a 48 kHz: e' il formato che
        // `AudioManager.playPCMAudio` si aspetta (lo suona alla frequenza della
        // sessione del telefono, 48 kHz sull'altoparlante dell'iPhone).
        var campioni = [Float32](repeating: 0, count: 48000)
        for i in campioni.indices { campioni[i] = 0.3 * sin(2 * .pi * 440 * Float32(i) / 48000) }
        let audio = campioni.withUnsafeBufferPointer { Data(buffer: $0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try s.send(audio, toPeers: [p], with: .reliable)
                try s.send(Data("HEARTBEAT".utf8), toPeers: [p], with: .reliable)
                self.log("mandati \(audio.count) byte di audio: il telefono deve suonare un La per un secondo")
            } catch {
                self.log("ERRORE invio audio: \(error)")
            }
        }
    }

    func session(_ s: MCSession, didReceive d: Data, fromPeer p: MCPeerID) {
        if String(data: d, encoding: .utf8) == "HEARTBEAT" {
            log("HEARTBEAT da \(p.displayName)")
        } else {
            log("ricevuti \(d.count) byte di audio da \(p.displayName)")
        }
    }

    func session(_ s: MCSession, didReceive st: InputStream, withName n: String, fromPeer p: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer p: MCPeerID, with pr: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer p: MCPeerID, at u: URL?, withError e: Error?) {}
}

let prova = Prova()
prova.parti()
RunLoop.main.run(until: Date().addingTimeInterval(durata))
print("\ntrovati: \(prova.trovati.count), collegato: \(prova.collegato ? "si'" : "no")")
exit(prova.collegato ? 0 : 1)
