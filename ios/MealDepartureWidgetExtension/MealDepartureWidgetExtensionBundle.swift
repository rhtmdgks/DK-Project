//
//  MealDepartureWidgetExtensionBundle.swift
//  MealDepartureWidgetExtension
//

import WidgetKit
import SwiftUI

@main
struct MealDepartureWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        MealDepartureWidget()
        ClassTimeLeftWidget()
        TodayTimetableWidget()
        MealDepartureCountdownWidget()
    }
}
