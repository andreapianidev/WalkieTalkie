//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - PresetIntents+Widget.swift
//  TalkyWidgets
//
//  Il lato estensione dei tasti radio (Shared/WidgetLink/PresetIntents.swift).
//  L'estensione li deve conoscere per metterli nei bottoni, ma non li esegue:
//  da AudioPlaybackIntent il sistema li passa all'app. Qui non c'e' un lettore
//  a cui chiedere di suonare, quindi non si fa niente.

import AppIntents

@available(iOS 17.0, macOS 14.0, *)
extension PlayPresetIntent {
    func perform() async throws -> some IntentResult { .result() }
}

@available(iOS 17.0, macOS 14.0, *)
extension StopRadioIntent {
    func perform() async throws -> some IntentResult { .result() }
}

@available(iOS 17.0, macOS 14.0, *)
extension PlayFavoriteRadioIntent {
    func perform() async throws -> some IntentResult { .result() }
}
