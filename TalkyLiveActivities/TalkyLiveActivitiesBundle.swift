//
//  TalkyLiveActivitiesBundle.swift
//  TalkyLiveActivities
//
//  Widget extension entry point: the radio and walkie Live Activities, and the
//  live radio widgets (channel, propagation, lock screen).
//

import WidgetKit
import SwiftUI

@main
struct TalkyLiveActivitiesBundle: WidgetBundle {
    // Deployment target del widget è iOS 16.2 (vedi Info.plist), quindi il
    // `#available` precedente era ridondante e — con WidgetBundleBuilder — poteva
    // produrre un body vuoto in caso di build con SDK più vecchi. I due Widget
    // sono già gated con @available a livello di struct.
    var body: some Widget {
        RadioActivityWidget()
        WalkieActivityWidget()
        // I widget della radio vera (cartella TalkyWidgets) vogliono iOS 17:
        // configurazione con AppIntent e containerBackground.
        if #available(iOS 17.0, *) {
            ChannelWidget()
            PropagationWidget()
            SunWidget()
            BandLockWidget()
        }
        if #available(iOS 18.0, *) {
            ListenCBControl()
        }
    }
}
