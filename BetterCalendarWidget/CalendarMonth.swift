//
//  CalendarMonth.swift
//  BetterCalendarWidget
//

import Foundation

/// A single month, and the navigation around it. The layout itself lives in
/// `CalendarGrid`, which the grid view draws.
struct CalendarMonth: Hashable {
    /// The first moment of the first day of the month.
    let start: Date
    let calendar: Calendar

    init(containing date: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        let components = calendar.dateComponents([.year, .month], from: date)
        self.start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    /// The weeks to draw for this month.
    var grid: CalendarGrid {
        .month(containing: start, calendar: calendar)
    }

    var title: String {
        start.formatted(.dateTime.month(.wide).year())
    }

    /// Whether `date` falls within this month.
    func contains(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: start, toGranularity: .month)
    }

    /// The month `months` away from this one, keeping the same calendar.
    func advanced(by months: Int) -> CalendarMonth {
        let shifted = calendar.date(byAdding: .month, value: months, to: start) ?? start
        return CalendarMonth(containing: shifted, calendar: calendar)
    }

    /// The day to select when moving to this month: today if it falls here,
    /// otherwise the first of the month.
    var preferredSelection: Date {
        contains(.now) ? calendar.startOfDay(for: .now) : start
    }
}
