//
//  CalendarGrid.swift
//  BetterCalendarWidget
//

import Foundation

/// A block of whole weeks to lay out as a seven-column grid.
///
/// This is what the grid view draws, so the same view renders a month, four
/// weeks, or any other run of weeks. `CalendarMonth` stays separate because
/// month navigation — stepping, "does this month contain today" — only makes
/// sense for months.
struct CalendarGrid: Hashable {
    let calendar: Calendar

    /// What to call this span, or nil for one with no name of its own — a run
    /// of weeks usually straddles two months.
    let title: String?

    /// Row-major, and always a whole number of weeks.
    let days: [Date]

    /// Days drawn at reduced prominence: in a month grid, the adjacent-month
    /// days padding the first and last rows. Empty when every day belongs.
    let dimmedDays: Set<Date>

    var weekCount: Int { max(days.count / 7, 1) }

    /// The span the grid covers, from its first day up to (but not including)
    /// the day after its last.
    var gridRange: Range<Date> {
        guard let first = days.first,
              let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last)
        else {
            let now = Date.now
            return now..<now
        }
        return first..<end
    }

    /// The first day that isn't padding, used to work out which way a tap on a
    /// dimmed day should move.
    var firstProminentDay: Date {
        days.first { !dimmedDays.contains($0) } ?? days.first ?? .now
    }

    func isDimmed(_ day: Date) -> Bool {
        dimmedDays.contains(day)
    }

    /// Short weekday labels ordered to match the grid columns.
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = min(max(calendar.firstWeekday - 1, 0), symbols.count - 1)
        return Array(symbols[offset...] + symbols[..<offset])
    }
}

extension CalendarGrid {
    /// The weeks covering one month, padded into the adjacent months so every
    /// row starts on the calendar's first weekday.
    static func month(containing date: Date, calendar: Calendar = .current) -> CalendarGrid {
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30

        // How many days of the previous month are needed to fill the first row.
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let weekCount = Int((Double(leading + dayCount) / 7).rounded(.up))

        let gridStart = calendar.date(byAdding: .day, value: -leading, to: start) ?? start
        let days = (0..<(weekCount * 7)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
        let dimmed = days.filter { !calendar.isDate($0, equalTo: start, toGranularity: .month) }

        return CalendarGrid(
            calendar: calendar,
            title: Self.monthTitle(for: start),
            days: days,
            dimmedDays: Set(dimmed)
        )
    }

    /// How a month is named wherever it's shown — the widget's heading and the
    /// app's navigation title alike.
    static func monthTitle(for start: Date) -> String {
        start.formatted(.dateTime.month(.wide).year())
    }

    /// `count` whole weeks, beginning with the week that contains `date`.
    /// Every day belongs, so nothing is dimmed.
    static func weeks(_ count: Int, containing date: Date, calendar: Calendar = .current) -> CalendarGrid {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
        let days = (0..<(max(count, 1) * 7)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }

        return CalendarGrid(
            calendar: calendar,
            title: nil,
            days: days,
            dimmedDays: []
        )
    }
}
