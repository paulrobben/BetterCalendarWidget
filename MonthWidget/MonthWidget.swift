//
//  MonthWidget.swift
//  MonthWidget
//
//  Created by Paul on 20.09.26.
//

import SwiftUI
import WidgetKit

struct MonthEntry: TimelineEntry {
    let date: Date
    let month: CalendarMonth
    let eventsByDay: [Date: [DayEvent]]
    /// False when the containing app hasn't been granted calendar access yet.
    let hasAccess: Bool
}

struct Provider: TimelineProvider {
    // WidgetKit calls these from a nonisolated context, while the calendar
    // types the app shares are MainActor-isolated, so each one hops.
    nonisolated func placeholder(in context: Context) -> MonthEntry {
        MainActor.assumeIsolated {
            MonthEntry(
                date: .now,
                month: CalendarMonth(containing: .now),
                eventsByDay: [:],
                hasAccess: true
            )
        }
    }

    nonisolated func getSnapshot(in context: Context, completion: @escaping (MonthEntry) -> Void) {
        Task { @MainActor in
            completion(currentEntry())
        }
    }

    nonisolated func getTimeline(in context: Context, completion: @escaping (Timeline<MonthEntry>) -> Void) {
        Task { @MainActor in
            // The grid highlights today, so it only needs rebuilding at
            // midnight. Calendar edits are picked up by the reload the
            // containing app requests when the event store changes.
            let entry = currentEntry()
            let midnight = Calendar.current.nextDate(
                after: .now,
                matching: DateComponents(hour: 0, minute: 0),
                matchingPolicy: .nextTime
            )
            let next = midnight ?? Date.now.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func currentEntry() -> MonthEntry {
        let store = CalendarEventStore()
        let month = CalendarMonth(containing: .now, calendar: store.calendar)

        // A widget can't prompt, so it only reads when the app already has access.
        store.refreshAccessStatus()
        guard store.access == .granted else {
            return MonthEntry(date: .now, month: month, eventsByDay: [:], hasAccess: false)
        }

        store.loadEvents(in: month.gridRange)
        return MonthEntry(date: .now, month: month, eventsByDay: store.eventsByDay, hasAccess: true)
    }
}

struct MonthWidgetEntryView: View {
    var entry: MonthEntry

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(entry.month.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            WeekdayHeaderView(symbols: entry.month.weekdaySymbols)

            if entry.hasAccess {
                // A GeometryReader in a stack takes the space the fixed-size
                // siblings leave, which is exactly the height to divide by.
                GeometryReader { proxy in
                    MonthGridView(
                        month: entry.month,
                        eventsByDay: entry.eventsByDay,
                        selectedDay: .constant(entry.month.calendar.startOfDay(for: entry.date)),
                        onMonthChange: { _ in },
                        rowHeight: proxy.size.height / CGFloat(entry.month.weekCount)
                    )
                }
            } else {
                Spacer()
                Text("Open BetterCalendarWidget to allow calendar access.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
    }
}

struct MonthWidget: Widget {
    let kind: String = "MonthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MonthWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Month")
        .description("An overview of the current month with your events.")
        .supportedFamilies([.systemLarge])
    }
}

/// Made-up events for the preview. `DayEvent` is a plain value, so this needs
/// no event store — which the extension process can't create one of anyway.
@MainActor
private func previewEvents() -> [Date: [DayEvent]] {
    let month = CalendarMonth(containing: .now)
    let palette: [(Color, Color)] = [
        (Color(red: 0.00, green: 0.48, blue: 1.00), .white),
        (Color(red: 1.00, green: 0.23, blue: 0.19), .white),
        (Color(red: 1.00, green: 0.80, blue: 0.00), .black),
    ]
    let titles = ["Standup", "Design review", "Dentist"]
    let counts = [3: 4, 4: 1, 9: 2, 15: 1, 16: 3, 22: 1, 23: 2, 24: 1]

    var result: [Date: [DayEvent]] = [:]
    for day in month.days where month.contains(day) {
        let dayOfMonth = month.calendar.component(.day, from: day)
        guard let count = counts[dayOfMonth] else { continue }
        result[day] = (0..<count).map { index in
            let (color, titleColor) = palette[index % palette.count]
            return DayEvent(
                id: "\(dayOfMonth)-\(index)",
                title: titles[index % titles.count],
                start: day,
                end: day,
                color: color,
                titleColor: titleColor
            )
        }
    }
    return result
}

#Preview("Granted", as: .systemLarge) {
    MonthWidget()
} timeline: {
    MonthEntry(
        date: .now,
        month: CalendarMonth(containing: .now),
        eventsByDay: previewEvents(),
        hasAccess: true
    )
}

#Preview("No access", as: .systemLarge) {
    MonthWidget()
} timeline: {
    MonthEntry(
        date: .now,
        month: CalendarMonth(containing: .now),
        eventsByDay: [:],
        hasAccess: false
    )
}
