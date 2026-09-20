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
