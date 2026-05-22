//
//  TalkyLiveActivitiesBundle.swift
//  TalkyLiveActivities
//
//  Widget extension entry point — bundles the radio and walkie Live Activities.
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
    }
}
