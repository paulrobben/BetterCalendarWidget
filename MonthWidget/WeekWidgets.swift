//
//  WeekWidgets.swift
//  MonthWidget
//

import SwiftUI
import WidgetKit

// The same grid as the Month widget, showing the current week and a varying
// number of the weeks after it. None of them names its span the way the Month
// widget does: a run of weeks often straddles two months, and the row is
// better spent on the grid. Fewer weeks means taller rows, so each widget down
// this list shows more of a busy day's events before collapsing the rest into
// a "+n".

struct FourWeeksWidget: Widget {
    let kind: String = "FourWeeksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarGridProvider<FourWeeksGridKind>()) { entry in
            CalendarGridWidgetView(entry: entry, showsTitle: false)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("4 Weeks")
        .description("This week and the next three, with your events.")
        .supportedFamilies([.systemLarge])
    }
}

struct ThreeWeeksWidget: Widget {
    let kind: String = "ThreeWeeksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarGridProvider<ThreeWeeksGridKind>()) { entry in
            CalendarGridWidgetView(entry: entry, showsTitle: false)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("3 Weeks")
        .description("This week and the next two, with more of each day's events.")
        .supportedFamilies([.systemLarge])
    }
}

struct TwoWeeksWidget: Widget {
    let kind: String = "TwoWeeksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarGridProvider<TwoWeeksGridKind>()) { entry in
            CalendarGridWidgetView(entry: entry, showsTitle: false)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("2 Weeks")
        .description("This week and the next, with more of each day's events.")
        // Two rows suit a 4x2 as well as a 4x4: the grid divides whatever
        // height WidgetKit gives it, and a day just fits fewer bars.
        .supportedFamilies([.systemLarge, .systemMedium])
    }
}

struct OneWeekWidget: Widget {
    let kind: String = "OneWeekWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarGridProvider<OneWeekGridKind>()) { entry in
            CalendarGridWidgetView(entry: entry, showsTitle: false)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("1 Week")
        .description("This week only, with every event a day can fit.")
        .supportedFamilies([.systemLarge, .systemMedium])
    }
}

#Preview("4 Weeks", as: .systemLarge) {
    FourWeeksWidget()
} timeline: {
    let grid = CalendarGrid.weeks(4, containing: .now)
    CalendarGridEntry(date: .now, grid: grid, eventsByDay: previewEvents(for: grid), hasAccess: true)
}

#Preview("3 Weeks", as: .systemLarge) {
    ThreeWeeksWidget()
} timeline: {
    let grid = CalendarGrid.weeks(3, containing: .now)
    CalendarGridEntry(date: .now, grid: grid, eventsByDay: previewEvents(for: grid), hasAccess: true)
}

#Preview("2 Weeks", as: .systemLarge) {
    TwoWeeksWidget()
} timeline: {
    let grid = CalendarGrid.weeks(2, containing: .now)
    CalendarGridEntry(date: .now, grid: grid, eventsByDay: previewEvents(for: grid), hasAccess: true)
}

#Preview("1 Week", as: .systemLarge) {
    OneWeekWidget()
} timeline: {
    let grid = CalendarGrid.weeks(1, containing: .now)
    CalendarGridEntry(date: .now, grid: grid, eventsByDay: previewEvents(for: grid), hasAccess: true)
}

#Preview("2 Weeks, medium", as: .systemMedium) {
    TwoWeeksWidget()
} timeline: {
    let grid = CalendarGrid.weeks(2, containing: .now)
    CalendarGridEntry(date: .now, grid: grid, eventsByDay: previewEvents(for: grid), hasAccess: true)
}

#Preview("1 Week, medium", as: .systemMedium) {
    OneWeekWidget()
} timeline: {
    let grid = CalendarGrid.weeks(1, containing: .now)
    CalendarGridEntry(date: .now, grid: grid, eventsByDay: previewEvents(for: grid), hasAccess: true)
}

#Preview("No access", as: .systemLarge) {
    OneWeekWidget()
} timeline: {
    CalendarGridEntry(
        date: .now,
        grid: .weeks(1, containing: .now),
        eventsByDay: [:],
        hasAccess: false
    )
}
