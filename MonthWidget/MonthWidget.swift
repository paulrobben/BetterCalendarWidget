//
//  MonthWidget.swift
//  MonthWidget
//
//  Created by Paul on 20.09.26.
//

import SwiftUI
import WidgetKit

struct MonthWidget: Widget {
    let kind: String = "MonthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarGridProvider<MonthGridKind>()) { entry in
            CalendarGridWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Month")
        .description("An overview of the current month with your events.")
        .supportedFamilies([.systemLarge])
    }
}

#Preview("Granted", as: .systemLarge) {
    MonthWidget()
} timeline: {
    let grid = CalendarGrid.month(containing: .now)
    CalendarGridEntry(
        date: .now,
        grid: grid,
        eventsByDay: previewEvents(for: grid),
        hasAccess: true
    )
}

#Preview("No access", as: .systemLarge) {
    MonthWidget()
} timeline: {
    CalendarGridEntry(
        date: .now,
        grid: .month(containing: .now),
        eventsByDay: [:],
        hasAccess: false
    )
}
