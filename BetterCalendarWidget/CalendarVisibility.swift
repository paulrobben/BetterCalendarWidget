//
//  CalendarVisibility.swift
//  BetterCalendarWidget
//

import Foundation

/// Which calendars the month view shows, shared between the app and the
/// widget through an App Group.
///
/// This records the *hidden* identifiers rather than the visible ones. Storing
/// the visible set would mean a calendar added after the person last opened
/// settings never appears, and would make "nothing stored yet" indistinguishable
/// from "everything hidden".
struct CalendarVisibility {
    static let appGroup = "group.paulrobben.BetterCalendarWidget"

    private static let key = "hiddenCalendarIdentifiers"

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        // Falls back to standard defaults if the App Group is unavailable, in
        // which case the app and widget simply keep separate selections.
        self.defaults = defaults ?? UserDefaults(suiteName: Self.appGroup) ?? .standard
    }

    var hiddenIdentifiers: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.key) ?? []) }
        nonmutating set { defaults.set(newValue.sorted(), forKey: Self.key) }
    }
}

/// The calendar the app adds new events to, or nil to follow the system's own
/// default. Only the app writes events, but this lives in the same App Group
/// defaults so there's one place to look for what the person has chosen.
struct NewEventCalendar {
    private static let key = "newEventCalendarIdentifier"

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: CalendarVisibility.appGroup) ?? .standard
    }

    var identifier: String? {
        get { defaults.string(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
