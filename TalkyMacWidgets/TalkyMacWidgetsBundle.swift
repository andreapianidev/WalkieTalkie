//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - TalkyMacWidgetsBundle.swift
//  TalkyMacWidgets
//
//  I widget di Talky sulla scrivania del Mac: gli stessi di iOS (cartella
//  TalkyWidgets), senza quelli della schermata di blocco che il Mac non ha.

import SwiftUI
import WidgetKit

@main
struct TalkyMacWidgets: WidgetBundle {
    var body: some Widget {
        ChannelWidget()
        PropagationWidget()
        SunWidget()
    }
}
