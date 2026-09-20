//
//  CalendarEventStore.swift
//  BetterCalendarWidget
//

import EventKit
import SwiftUI
import WidgetKit

/// The level of access the app has to the person's calendar data.
enum CalendarAccess: Equatable {
    /// Access hasn't been determined yet, or the request is still in flight.
    case pending
    case granted
    case denied
}

/// Reads events from the person's calendars and groups them by day for the
/// month overview.
@Observable
final class CalendarEventStore {
    private let store = EKEventStore()

    let calendar: Calendar

    private(set) var access: CalendarAccess = .pending

    /// Events overlapping the loaded range, keyed by the first moment of each
    /// day they touch. Multi-day events appear under every day they cover.
    private(set) var eventsByDay: [Date: [DayEvent]] = [:]

    /// The range currently loaded, so store changes can be re-fetched.
    private var loadedRange: Range<Date>?

    private let visibility = CalendarVisibility()

    /// Calendars the person has switched off in settings. Writing this
    /// persists to the App Group, refetches, and refreshes the widget.
    var hiddenCalendarIdentifiers: Set<String> {
        didSet {
            guard hiddenCalendarIdentifiers != oldValue else { return }
            visibility.hiddenIdentifiers = hiddenCalendarIdentifiers
            WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
            if let loadedRange {
                loadEvents(in: loadedRange)
            }
        }
    }

    static let widgetKind = "MonthWidget"

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.hiddenCalendarIdentifiers = visibility.hiddenIdentifiers
    }

    /// Asks for full access, which EventKit requires in order to read events.
    func requestAccess() async {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            access = .granted
        case .notDetermined:
            do {
                access = try await store.requestFullAccessToEvents() ? .granted : .denied
            } catch {
                access = .denied
            }
        default:
            access = .denied
        }
    }

    /// Reads the current authorisation without prompting, for callers that
    /// can't show a permission dialog — the widget extension in particular.
    func refreshAccessStatus() {
        access = EKEventStore.authorizationStatus(for: .event) == .fullAccess ? .granted : .denied
    }

    /// Fetches every event overlapping `range` from the visible calendars and
    /// regroups it by day.
    func loadEvents(in range: Range<Date>) {
        guard access == .granted, !range.isEmpty else { return }
        loadedRange = range

        // An empty `calendars:` array isn't the same as nil — nil would search
        // every calendar, which is the opposite of what the person asked for.
        let visible = visibleCalendars
        guard !visible.isEmpty else {
            eventsByDay = [:]
            return
        }

        let predicate = store.predicateForEvents(
            withStart: range.lowerBound,
            end: range.upperBound,
            calendars: visible
        )
        eventsByDay = groupByDay(store.events(matching: predicate), in: range)
    }

    private var visibleCalendars: [EKCalendar] {
        store.calendars(for: .event).filter {
            !hiddenCalendarIdentifiers.contains($0.calendarIdentifier)
        }
    }

    /// Every event calendar, as plain values for the settings list.
    func calendarOptions() -> [CalendarOption] {
        store.calendars(for: .event)
            .map(CalendarOption.init)
            .sorted {
                if $0.sourceTitle != $1.sourceTitle {
                    return $0.sourceTitle.localizedCompare($1.sourceTitle) == .orderedAscending
                }
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
    }

    /// The events on a given day, sorted with all-day events first.
    func events(on day: Date) -> [DayEvent] {
        eventsByDay[calendar.startOfDay(for: day)] ?? []
    }

    /// Reloads whenever the Calendar database changes underneath us — for
    /// example when the person edits an event in Apple's Calendar app.
    func observeStoreChanges() async {
        let changes = NotificationCenter.default
            .notifications(named: .EKEventStoreChanged)
            .map { $0.name }

        for await _ in changes {
            // The widget can't observe the event store while it isn't running,
            // so the app nudges it whenever the calendar database changes.
            WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)

            guard let loadedRange else { continue }
            loadEvents(in: loadedRange)
        }
    }

    private func groupByDay(_ events: [EKEvent], in range: Range<Date>) -> [Date: [DayEvent]] {
        var grouped: [Date: [DayEvent]] = [:]

        for event in events {
            guard let start = event.startDate, let end = event.endDate else { continue }
            // Resolve to values now, while the store backing these objects is
            // still alive — see DayEvent.
            let resolved = DayEvent(event)
            var day = calendar.startOfDay(for: max(start, range.lowerBound))

            // Add the event to every day it covers. An event ending exactly at
            // midnight belongs to the day before, so compare against `end`
            // strictly and special-case events with no duration.
            while day < range.upperBound, day < end || calendar.isDate(day, inSameDayAs: start) {
                grouped[day, default: []].append(resolved)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        return grouped.mapValues { $0.sorted(by: DayEvent.isOrderedBefore) }
    }
}
