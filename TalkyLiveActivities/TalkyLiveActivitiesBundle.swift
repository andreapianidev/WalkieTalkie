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
    var body: some Widget {
        if #available(iOS 16.2, *) {
            RadioActivityWidget()
            WalkieActivityWidget()
        }
    }
}
