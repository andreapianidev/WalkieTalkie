//  AdViewControllerRepresentable.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

import SwiftUI
import UIKit

struct AdViewControllerRepresentable: UIViewControllerRepresentable {
    let viewController = UIViewController()

    func makeUIViewController(context: Context) -> UIViewController {
        viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

enum AdRootViewController {
    static func current() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return nil
        }

        let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene.windows.first?.rootViewController

        var topMost = rootVC
        while let presented = topMost?.presentedViewController {
            topMost = presented
        }
        return topMost
    }
}
