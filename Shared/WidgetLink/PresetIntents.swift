//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - PresetIntents.swift
//  Talky
//
//  I tasti dei widget radio. Le dichiarazioni stanno qui, compilate nell'app
//  e nelle estensioni, perche' il sistema li riconosce per nome; `perform()`
//  invece e' diverso per ogni target. Essendo AudioPlaybackIntent, il sistema
//  li esegue nel processo dell'app, anche lanciandola in background: e' li'
//  che c'e' il lettore, l'estensione non puo' suonare niente.
//  Implementazioni: WalkieTalkie/Radio/PresetIntents+App.swift (iPhone),
//  macTalky/Core/PresetIntents+App.swift (Mac), TalkyWidgets/PresetIntents+Widget.swift.

import AppIntents

/// Suona una stazione delle preferite, o l'ultima ascoltata.
@available(iOS 17.0, macOS 14.0, *)
struct PlayPresetIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "w_intent_play"
    static let isDiscoverable = false

    @Parameter(title: "w_intent_station")
    var stationID: Int

    init() {}

    init(stationID: Int) {
        self.stationID = stationID
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct StopRadioIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "w_intent_stop"
    static let isDiscoverable = false

    init() {}
}

/// Il controllo "La mia radio preferita": quale sia lo decide l'app, che
/// conosce preferite e ascolti anche quando i widget non li vedono.
@available(iOS 17.0, macOS 14.0, *)
struct PlayFavoriteRadioIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "w_fav_control_name"
    static let isDiscoverable = false

    /// Senza Talky Pro l'app deve venire avanti per mostrare la paywall;
    /// con Pro resta in background e suona.
    @available(iOS 26.0, macOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    init() {}
}
