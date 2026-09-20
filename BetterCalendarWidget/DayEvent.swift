//
//  DayEvent.swift
//  BetterCalendarWidget
//

import EventKit
import SwiftUI

/// One occurrence of an event, resolved into plain values.
///
/// The views deliberately don't hold `EKEvent`s. An `EKEvent` faults its
/// relationships — `calendar`, and so the colour — through the `EKEventStore`
/// it came from, and returns nil once that store is deallocated. The widget
/// builds its timeline entry inside one function and renders it later, so
/// anything left unresolved there would silently lose its colour.
struct DayEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    /// The colour of the calendar this event belongs to.
    let color: Color
    /// Black or white, whichever reads better on `color`.
    let titleColor: Color

    init(_ event: EKEvent) {
        // Recurring events share an identifier, so an occurrence is only
        // uniquely identified together with its start date.
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
        let start = event.startDate ?? .distantPast

        self.id = "\(identifier)@\(start.timeIntervalSinceReferenceDate)"
        self.title = event.title ?? String(localized: "Untitled Event")
        self.start = start
        self.end = event.endDate ?? start
        self.isAllDay = event.isAllDay
        self.location = event.location.flatMap { $0.isEmpty ? nil : $0 }

        if let cgColor = event.calendar?.cgColor {
            self.color = Color(cgColor: cgColor)
            self.titleColor = cgColor.readableForeground
        } else {
            self.color = .accentColor
            self.titleColor = .white
        }
    }

    /// For previews and tests, which have no event store to read from.
    init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
         location: String? = nil, color: Color, titleColor: Color) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.color = color
        self.titleColor = titleColor
    }

    /// All-day events first, then by start time, then alphabetically.
    nonisolated static func isOrderedBefore(_ lhs: DayEvent, _ rhs: DayEvent) -> Bool {
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        return lhs.title.localizedCompare(rhs.title) == .orderedAscending
    }
}

/// One selectable calendar, resolved into plain values for the settings list
/// for the same reason as `DayEvent`.
struct CalendarOption: Identifiable, Hashable {
    let id: String
    let title: String
    let color: Color
    /// The account the calendar comes from, used to group the list.
    let sourceTitle: String

    nonisolated init(_ calendar: EKCalendar) {
        self.id = calendar.calendarIdentifier
        self.title = calendar.title
        self.color = calendar.cgColor.map(Color.init(cgColor:)) ?? .accentColor
        self.sourceTitle = calendar.source?.title ?? String(localized: "Other")
    }

    init(id: String, title: String, color: Color, sourceTitle: String) {
        self.id = id
        self.title = title
        self.color = color
        self.sourceTitle = sourceTitle
    }
}

extension CGColor {
    /// Prefers white, which is what calendar apps conventionally put on a
    /// coloured bar, and falls back to black only where white would drop below
    /// a 3:1 contrast ratio — light greens, oranges and yellows.
    ///
    /// Maximising contrast outright would instead put black on saturated reds
    /// and blues, which reads as a rendering bug.
    var readableForeground: Color {
        guard let luminance = relativeLuminance else { return .white }
        // 1.05 / (L + 0.05) >= 3 simplifies to L <= 0.3.
        return luminance <= 0.3 ? .white : .black
    }

    /// WCAG relative luminance, or `nil` if the colour can't be read as sRGB.
    var relativeLuminance: Double? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = converted(to: srgb, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3
        else {
            return nil
        }

        // Luminance needs gamma-decoded channel values.
        let linear = components.prefix(3).map { channel -> Double in
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
