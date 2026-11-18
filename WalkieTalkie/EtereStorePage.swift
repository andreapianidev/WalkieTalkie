//creato da Andrea Piani - 18/11/26 - https://www.andreapiani.com - EtereStorePage.swift
//  Talky
//
//  La scheda di Etere.AI aperta dentro Talky. Con il link all'App Store chi
//  tocca esce dall'app, e per tornare deve ricordarsene: qui scarica e resta.

import StoreKit
import UIKit

@MainActor
final class EtereStorePage: NSObject, SKStoreProductViewControllerDelegate {
    static let shared = EtereStorePage()

    /// Forma senza paese e senza slug: porta alla scheda nello Store di chi tocca.
    static let url = URL(string: "https://apps.apple.com/app/id6829725463")!
    private static let appleID = 6829725463

    func open() {
        guard let presenter = AdRootViewController.current() else {
            UIApplication.shared.open(Self.url)
            return
        }
        // L'app-open al rientro finirebbe sopra la scheda appena chiusa.
        AdManager.shared.appOpen.suppressNextResume = true
        let page = SKStoreProductViewController()
        page.delegate = self
        page.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: Self.appleID]) { loaded, _ in
            // Senza rete la scheda resta bianca: meglio lo Store, che sa dirlo.
            guard !loaded else { return }
            Task { @MainActor in
                page.dismiss(animated: true)
                UIApplication.shared.open(Self.url)
            }
        }
        presenter.present(page, animated: true)
    }

    nonisolated func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        Task { @MainActor in viewController.dismiss(animated: true) }
    }
}
