//
//  MonthWidgetBundle.swift
//  MonthWidget
//
//  Created by Paul on 20.09.26.
//

import WidgetKit
import SwiftUI

@main
struct MonthWidgetBundle: WidgetBundle {
    // Listed longest span first, which is also least detail first.
    var body: some Widget {
        MonthWidget()
        FourWeeksWidget()
        ThreeWeeksWidget()
        TwoWeeksWidget()
        OneWeekWidget()
    }
}
