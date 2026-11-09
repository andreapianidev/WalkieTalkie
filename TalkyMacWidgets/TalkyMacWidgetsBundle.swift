//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - TalkyMacWidgetsBundle.swift
//  TalkyMacWidgets
//
//  I widget di Talky sulla scrivania del Mac: gli stessi di iOS (cartella
//  TalkyWidgets), senza quelli della schermata di blocco che il Mac non ha.
//  I controlli vanno nel Centro di Controllo e nella barra dei menu.

import SwiftUI
import WidgetKit

@main
struct TalkyMacWidgets: WidgetBundle {
    var body: some Widget {
        ChannelWidget()
        PropagationWidget()
        SunWidget()
        PresetsWidget()
        OnAirWidget()
        ListenCBControl()
        WalkieChannelControl()
        FavoriteRadioControl()
    }
}
