//
//  CalendarGridWidget.swift
//  MonthWidget
//

import SwiftUI
import WidgetKit

struct CalendarGridEntry: TimelineEntry {
    let date: Date
    let grid: CalendarGrid
    let eventsByDay: [Date: [DayEvent]]
    /// False when the containing app hasn't been granted calendar access yet.
    let hasAccess: Bool
}

/// The span of days a widget draws. It's the only thing that differs between
/// the widgets, so everything else below is shared.
protocol CalendarGridKind {
    static func grid(containing date: Date, calendar: Calendar) -> CalendarGrid
}

enum MonthGridKind: CalendarGridKind {
    static func grid(containing date: Date, calendar: Calendar) -> CalendarGrid {
        .month(containing: date, calendar: calendar)
    }
}

/// A run of whole weeks starting with the one containing today. The widget is
/// the same height whichever span it shows, so the fewer weeks it covers the
/// taller its rows are — and the more events a day fits before the `+n`.
protocol WeekSpanGridKind: CalendarGridKind {
    static var weekCount: Int { get }
}

extension WeekSpanGridKind {
    static func grid(containing date: Date, calendar: Calendar) -> CalendarGrid {
        .weeks(weekCount, containing: date, calendar: calendar)
    }
}

enum OneWeekGridKind: WeekSpanGridKind {
    static let weekCount = 1
}

enum TwoWeeksGridKind: WeekSpanGridKind {
    static let weekCount = 2
}

enum ThreeWeeksGridKind: WeekSpanGridKind {
    static let weekCount = 3
}

enum FourWeeksGridKind: WeekSpanGridKind {
    static let weekCount = 4
}

struct CalendarGridProvider<Kind: CalendarGridKind>: TimelineProvider {
    // WidgetKit calls these from a nonisolated context, while the calendar
    // types the app shares are MainActor-isolated, so each one hops.
    nonisolated func placeholder(in context: Context) -> CalendarGridEntry {
        MainActor.assumeIsolated {
            CalendarGridEntry(
                date: .now,
                grid: Kind.grid(containing: .now, calendar: .current),
                eventsByDay: [:],
                hasAccess: true
            )
        }
    }

    nonisolated func getSnapshot(in context: Context, completion: @escaping (CalendarGridEntry) -> Void) {
        Task { @MainActor in
            completion(currentEntry())
        }
    }

    nonisolated func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarGridEntry>) -> Void) {
        Task { @MainActor in
            // The grid highlights today, and a four-week span starts from the
            // week today falls in, so both only need rebuilding at midnight.
            // Calendar edits are picked up by the reload the containing app
            // requests when the event store changes.
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

    private func currentEntry() -> CalendarGridEntry {
        let store = CalendarEventStore()
        let grid = Kind.grid(containing: .now, calendar: store.calendar)

        // A widget can't prompt, so it only reads when the app already has access.
        store.refreshAccessStatus()
        guard store.access == .granted else {
            return CalendarGridEntry(date: .now, grid: grid, eventsByDay: [:], hasAccess: false)
        }

        store.loadEvents(in: grid.gridRange)
        return CalendarGridEntry(date: .now, grid: grid, eventsByDay: store.eventsByDay, hasAccess: true)
    }
}

struct CalendarGridWidgetView: View {
    var entry: CalendarGridEntry

    /// Whether to name the span above the grid. The Month widget does; the
    /// 4 Weeks widget gives the row to the grid instead.
    var showsTitle: Bool = true

    var body: some View {
        VStack(spacing: 2) {
            if showsTitle {
                HStack {
                    Text(entry.grid.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                }
            }

            WeekdayHeaderView(symbols: entry.grid.weekdaySymbols)

            if entry.hasAccess {
                // A GeometryReader in a stack takes the space the fixed-size
                // siblings leave, which is exactly the height to divide by.
                GeometryReader { proxy in
                    CalendarGridView(
                        grid: entry.grid,
                        eventsByDay: entry.eventsByDay,
                        selectedDay: .constant(entry.grid.calendar.startOfDay(for: entry.date)),
                        rowHeight: proxy.size.height / CGFloat(entry.grid.weekCount)
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

/// Made-up events for the previews. `DayEvent` is a plain value, so this needs
/// no event store — which the extension process can't create one of anyway.
/// Days are picked by position in the grid, since a four-week span can cover
/// the same day number twice.
@MainActor
func previewEvents(for grid: CalendarGrid) -> [Date: [DayEvent]] {
    let palette: [(Color, Color)] = [
        (Color(red: 0.00, green: 0.48, blue: 1.00), .white),
        (Color(red: 1.00, green: 0.23, blue: 0.19), .white),
        (Color(red: 1.00, green: 0.80, blue: 0.00), .black),
    ]
    let titles = ["Standup", "Design review", "Dentist"]
    // A repeating run of per-day counts. Its length is coprime with seven, so
    // no two weeks come out alike however many of them the grid shows.
    let counts = [0, 2, 0, 5, 1, 0, 3, 0, 1, 4, 0]

    var result: [Date: [DayEvent]] = [:]
    for (index, day) in grid.days.enumerated() {
        let count = counts[index % counts.count]
        guard !grid.isDimmed(day), count > 0 else { continue }
        result[day] = (0..<count).map { position in
            let (color, titleColor) = palette[position % palette.count]
            return DayEvent(
                id: "\(index)-\(position)",
                title: titles[position % titles.count],
                start: day,
                end: day,
                color: color,
                titleColor: titleColor
            )
        }
    }
    return result
}
