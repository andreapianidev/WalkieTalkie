//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - LocalNetworkGuard.swift
//  WalkieTalkie

import Foundation
import Combine
import Network
import UIKit

/// Dice se il permesso Rete locale e' stato negato.
///
/// iOS non ha una funzione per chiederlo. Lo si capisce da un browser Bonjour:
/// con il permesso spento resta in `.waiting` con l'errore DNS PolicyDenied.
/// Senza quel permesso Multipeer non trova nessuno e chi usa l'app vede solo
/// "nessun dispositivo", che e' la recensione da una stella piu' frequente.
final class LocalNetworkGuard: ObservableObject {
    static let shared = LocalNetworkGuard()

    @Published private(set) var isDenied = false

    /// `kDNSServiceErr_PolicyDenied` di dns_sd.h.
    private static let policyDenied: DNSServiceErrorType = -65570
    private var browser: NWBrowser?
    private var foregroundObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    private init() {
        // Chi va in Impostazioni ad accendere il permesso torna all'app: la
        // scheda rossa deve sparire da sola, senza chiedergli di riavviare.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard self?.browser != nil else { return }
            self?.recheck()
        }
    }

    func check() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: "_walkie-talkie._tcp", domain: nil), using: .tcp)
        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .waiting(let error), .failed(let error):
                guard case .dns(let code) = error, code == Self.policyDenied else { return }
                self?.isDenied = true
                self?.noteDenied()
            case .ready:
                self?.isDenied = false
            default:
                break
            }
        }
        // `.ready` arriva anche prima che l'utente risponda al prompt, quindi
        // non dimostra niente. Un risultato si': Talky pubblica lo stesso
        // servizio (TalkyCrossPlatformManager), e senza permesso non vedrebbe
        // nemmeno se stessa.
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard !results.isEmpty else { return }
            self?.isDenied = false
            Funnel.once(Funnel.localNetworkGranted)
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    /// Il diniego va a Firebase solo a app attiva: mentre il prompt Rete
    /// locale e' a schermo l'app e' inattiva, e su alcune versioni di iOS il
    /// browser segnala PolicyDenied anche li', prima di qualunque risposta.
    /// In quel caso si aspetta il rientro e si guarda se e' ancora negato.
    private func noteDenied() {
        guard UIApplication.shared.applicationState == .active else {
            guard activeObserver == nil else { return }
            activeObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if let observer = self.activeObserver { NotificationCenter.default.removeObserver(observer) }
                self.activeObserver = nil
                // Il browser passa a pronto qualche istante dopo il "Consenti".
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    if self?.isDenied == true { Funnel.once(Funnel.localNetworkDenied) }
                }
            }
            return
        }
        Funnel.once(Funnel.localNetworkDenied)
    }

    func recheck() {
        browser?.cancel()
        browser = nil
        check()
    }

    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
