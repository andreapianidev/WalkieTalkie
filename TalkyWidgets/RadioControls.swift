//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - RadioControls.swift
//  TalkyWidgets
//
//  I controlli di Talky: Centro di Controllo e tasto Azione su iPhone,
//  Centro di Controllo e barra dei menu sul Mac (macOS 26).
//  CB 19 e walkie gratis, la radio preferita con Talky Pro.

import AppIntents
import SwiftUI
import WidgetKit

/// Apre Talky gia' sul canale 19 della CB (come il controllo "Accendi" di Etere).
@available(iOS 18.0, macOS 26.0, *)
struct ListenCBControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.Andrea-Piani.WalkieTalkie.cb19") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "talky://live/cb?hz=27185000")!)) {
                Label("CB 19", systemImage: "antenna.radiowaves.left.and.right")
            }
        }
        .displayName("w_control_name")
        .description("w_control_about")
    }
}

/// Apre il walkie fra telefoni sul canale in uso, pubblico o privato, e ne
/// mostra il nome: e' il canale su cui si verra' sentiti.
@available(iOS 18.0, macOS 26.0, *)
struct WalkieChannelControl: ControlWidget {
    struct Channel: ControlValueProvider {
        var previewValue: String? { nil }

        func currentValue() async throws -> String? { RadioShelf.walkieChannel }
    }

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: RadioShelf.walkieControlKind, provider: Channel()) { channel in
            ControlWidgetButton(action: OpenURLIntent(URL(string: "talky://walkie/channel")!)) {
                Label(channel ?? String(localized: "w_walkie_public"), systemImage: "dot.radiowaves.left.and.right")
            }
        }
        .displayName("w_walkie_control_name")
        .description("w_walkie_control_about")
    }
}

/// Talky Pro: fa partire la preferita ascoltata per ultima senza aprire l'app.
/// Senza Pro mostra il lucchetto, e il tocco porta alla paywall.
@available(iOS 18.0, macOS 26.0, *)
struct FavoriteRadioControl: ControlWidget {
    struct Favorite: ControlValueProvider {
        struct Value {
            let name: String?
            let hasPro: Bool
        }

        var previewValue: Value { Value(name: nil, hasPro: true) }

        func currentValue() async throws -> Value {
            // Il nome e' quello che l'app suonera': la prima preferita, o
            // l'ultima stazione ascoltata se di preferite non ce ne sono.
            Value(name: RadioShelf.presets.first?.name ?? RadioShelf.onAir?.station.name,
                  hasPro: await TalkyPro.isActive())
        }
    }

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: RadioShelf.favoriteControlKind, provider: Favorite()) { value in
            // Un bottone solo: ControlWidgetTemplateBuilder non ammette if, quindi
            // l'azione non puo' cambiare col Pro. Cambia l'etichetta, e senza Pro
            // l'intent porta avanti l'app sulla paywall (PresetIntents+App).
            ControlWidgetButton(action: PlayFavoriteRadioIntent()) {
                if value.hasPro {
                    Label(value.name ?? String(localized: "w_fav_control_name"), systemImage: "radio")
                } else {
                    Label("Talky Pro", systemImage: "lock.fill")
                }
            }
        }
        .displayName("w_fav_control_name")
        .description("w_fav_control_about")
    }
}
