//
//  CalendarGridView.swift
//  BetterCalendarWidget
//

import SwiftUI

/// The column headings above a calendar grid.
struct WeekdayHeaderView: View {
    let symbols: [String]

    var body: some View {
        HStack(spacing: 0) {
            // Identified by column, not by label: most languages repeat a
            // very short weekday symbol — English has two Ts and two Ss.
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }
}

/// A run of whole weeks laid out as rows of seven days, with a titled bar for
/// each event. A month and a four-week span differ only in the grid handed in.
///
/// Each week is laid out as a whole rather than day by day, so an event
/// covering several days draws as one bar stretched across them.
struct CalendarGridView: View {
    let grid: CalendarGrid
    let eventsByDay: [Date: [DayEvent]]
    @Binding var selectedDay: Date

    /// Called when the person swipes horizontally, or taps a dimmed day from
    /// an adjacent period. A grid that dims nothing — four weeks, say — only
    /// ever calls this from a swipe, so widgets leave it at its default.
    var onPeriodChange: (Int) -> Void = { _ in }

    /// The height of every row. Weeks cap their bars to fit it, so the grid is
    /// always exactly `weekCount * rowHeight` tall.
    let rowHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(weeks) { week in
                WeekRow(
                    days: week.days,
                    grid: grid,
                    eventsByDay: eventsByDay,
                    selectedDay: selectedDay,
                    rowHeight: rowHeight,
                    onSelect: { day in select(day) }
                )
            }
        }
        .gesture(periodSwipe)
    }

    /// The grid's days split into rows of seven.
    private var weeks: [Week] {
        stride(from: 0, to: grid.days.count, by: 7).map { start in
            Week(index: start / 7, days: Array(grid.days[start..<min(start + 7, grid.days.count)]))
        }
    }

    private var periodSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let width = value.translation.width
                guard abs(width) > abs(value.translation.height) else { return }
                onPeriodChange(width < 0 ? 1 : -1)
            }
    }

    private func select(_ day: Date) {
        selectedDay = day
        // Tapping a greyed-out day from a neighbouring month follows it there.
        guard grid.isDimmed(day) else { return }
        onPeriodChange(day < grid.firstProminentDay ? -1 : 1)
    }
}

/// One row of the grid: seven days, and its position down the grid.
private struct Week: Identifiable {
    let index: Int
    let days: [Date]

    var id: Int { index }
}

/// One week: a row of day numbers, and under it the week's events packed into
/// lanes. An event holds the same lane across every day it covers, which is
/// what lets a multi-day bar run straight across the row.
private struct WeekRow: View {
    let days: [Date]
    let grid: CalendarGrid
    let eventsByDay: [Date: [DayEvent]]
    let selectedDay: Date
    let rowHeight: CGFloat
    let onSelect: (Date) -> Void

    @ScaledMetric(relativeTo: .caption2) private var barHeight: CGFloat = 13
    @ScaledMetric(relativeTo: .caption) private var numberDiameter: CGFloat = 22

    private static let barSpacing: CGFloat = 1.5
    private static let contentSpacing: CGFloat = 2
    private static let verticalPadding: CGFloat = 2
    /// Keeps neighbouring bars apart, and a bar off the row's edges.
    private static let barInset: CGFloat = 1.5

    var body: some View {
        // Packed once here: both the numbers, for their overflow counts, and
        // the bars are laid out from the same lanes.
        let segments = WeekEventSegment.pack(days: days, eventsByDay: eventsByDay)

        ZStack(alignment: .top) {
            // Behind the content, so a tap anywhere in a column selects that
            // day — including the empty space a short day leaves.
            dayColumns

            VStack(spacing: Self.contentSpacing) {
                numbers(segments)
                bars(segments)
            }
            .padding(.vertical, Self.verticalPadding)
            // Taps belong to the columns underneath, so a tap on a bar still
            // selects the day it sits on.
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(height: rowHeight)
    }

    private var dayColumns: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { onSelect(day) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: day))
                    .accessibilityAddTraits(isSelected(day) ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func numbers(_ segments: [WeekEventSegment]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { column, day in
                DayNumber(
                    day: day,
                    isToday: grid.calendar.isDateInToday(day),
                    isSelected: isSelected(day),
                    hiddenCount: hiddenCount(inColumn: column, of: segments),
                    diameter: numberDiameter
                )
                .opacity(grid.isDimmed(day) ? 0.4 : 1)
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// The lanes that fit, drawn as bars spanning the columns they cover.
    private func bars(_ segments: [WeekEventSegment]) -> some View {
        GeometryReader { proxy in
            let columnWidth = proxy.size.width / CGFloat(days.count)

            ZStack(alignment: .topLeading) {
                ForEach(segments.filter { $0.lane < barCapacity }) { segment in
                    EventBar(event: segment.event, height: barHeight)
                        .opacity(isDimmed(segment) ? 0.4 : 1)
                        .frame(
                            width: max(columnWidth * CGFloat(segment.columnCount) - Self.barInset * 2, 0),
                            height: barHeight
                        )
                        .offset(
                            x: columnWidth * CGFloat(segment.startColumn) + Self.barInset,
                            y: CGFloat(segment.lane) * (barHeight + Self.barSpacing)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// How many lanes fit once the day numbers have taken their share of the row.
    private var barCapacity: Int {
        let reserved = numberDiameter + Self.contentSpacing + Self.verticalPadding * 2
        let available = rowHeight - reserved
        guard available > 0 else { return 0 }
        return Int(available / (barHeight + Self.barSpacing))
    }

    /// The events touching this column that didn't make it into a lane that fits.
    private func hiddenCount(inColumn column: Int, of segments: [WeekEventSegment]) -> Int {
        segments.count { $0.lane >= barCapacity && $0.covers(column) }
    }

    /// A bar is only greyed out when every day it covers is — one running from
    /// the end of a month into the next belongs to both, so it stays full
    /// strength.
    private func isDimmed(_ segment: WeekEventSegment) -> Bool {
        (segment.startColumn...segment.endColumn).allSatisfy { grid.isDimmed(days[$0]) }
    }

    private func isSelected(_ day: Date) -> Bool {
        grid.calendar.isDate(day, inSameDayAs: selectedDay)
    }

    private func accessibilityLabel(for day: Date) -> String {
        let date = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let events = eventsByDay[day] ?? []
        guard !events.isEmpty else { return date }
        return "\(date), \(events.map(\.title).formatted(.list(type: .and)))"
    }
}

/// One day's number, with the count of its events that didn't fit beside it.
///
/// The overflow marker sits here rather than in a lane because a 4x4 widget
/// often has room for only one bar — spending that lane on a "+n" would drop
/// every title. The two share a row rather than the marker overlaying the
/// column: a column is only a little wider than the selection circle, so an
/// overlaid marker collided with the circle on a busy today.
private struct DayNumber: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let hiddenCount: Int
    let diameter: CGFloat

    var body: some View {
        HStack(spacing: 1) {
            Text(day.formatted(.dateTime.day()))
                .font(.caption)
                .fontWeight(isToday ? .semibold : .regular)
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .frame(width: diameter, height: diameter)
                .background(selectionCircle)
                // Centres the number in whatever the marker leaves, so a day
                // without one keeps it centred in the column.
                .frame(maxWidth: .infinity)

            if hiddenCount > 0 {
                Text("+\(hiddenCount)")
                    .font(.system(size: 8, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var selectionCircle: some View {
        if isSelected {
            Circle().fill(isToday ? Color.accentColor : Color.primary)
        }
    }

    private var numberColor: Color {
        if isSelected {
            return isToday ? .white : Color(.systemBackground)
        }
        return isToday ? .accentColor : .primary
    }
}

/// A single event's bar, filled with its calendar's colour. A bar is as narrow
/// as its column, so titles truncate — the day detail below the grid in the app
/// shows them in full.
///
/// All-day events take the colour solid, events with a time take it washed
/// out, so the two tell apart at a glance without reading anything.
private struct EventBar: View {
    let event: DayEvent
    let height: CGFloat

    /// How much of the calendar's colour a timed event's bar keeps.
    private static let timedOpacity: Double = 0.3

    var body: some View {
        Text(event.title)
            .font(.caption2)
            // Every title reads at one size: a long one truncates rather than
            // shrinking to fit, which had titles across a row at sizes that
            // didn't match.
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(titleColor)
            .padding(.horizontal, 3)
            // A fixed height, not a minimum: the background follows the text,
            // whose line height is a shade over the bar's, so a minimum let
            // bars come out at slightly different heights.
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: 3))
    }

    private var fill: Color {
        event.isAllDay ? event.color : event.color.opacity(Self.timedOpacity)
    }

    /// `DayEvent.titleColor` is chosen to read against the solid colour, which
    /// a washed-out bar no longer is — white on pale yellow is unreadable. A
    /// faint bar takes the foreground colour instead, which suits both a light
    /// and a dark widget.
    private var titleColor: Color {
        event.isAllDay ? event.titleColor : .primary
    }
}

/// One event's run of columns within a week, and the lane it draws in.
struct WeekEventSegment: Identifiable {
    let event: DayEvent
    let startColumn: Int
    let endColumn: Int
    /// The bar's position down the row. Shared by every day of the event, and
    /// never shared with another event on the same day.
    let lane: Int

    /// An event can only appear once per week, so its id settles the segment's.
    var id: String { event.id }

    var columnCount: Int { endColumn - startColumn + 1 }

    func covers(_ column: Int) -> Bool {
        (startColumn...endColumn).contains(column)
    }

    /// Packs a week's events into lanes.
    ///
    /// `eventsByDay` lists a multi-day event under each day it covers, so the
    /// columns it spans are the first and last it appears in — which also
    /// clips it to the week for free. Longest spans are placed first, so the
    /// bars that cross the most days settle at the top of the row.
    static func pack(days: [Date], eventsByDay: [Date: [DayEvent]]) -> [WeekEventSegment] {
        var spans: [(event: DayEvent, first: Int, last: Int)] = []
        var indexByEvent: [String: Int] = [:]

        for (column, day) in days.enumerated() {
            for event in eventsByDay[day] ?? [] {
                if let index = indexByEvent[event.id] {
                    spans[index].last = column
                } else {
                    indexByEvent[event.id] = spans.count
                    spans.append((event, column, column))
                }
            }
        }

        let ordered = spans.sorted { lhs, rhs in
            let lhsLength = lhs.last - lhs.first
            let rhsLength = rhs.last - rhs.first
            if lhsLength != rhsLength { return lhsLength > rhsLength }
            if lhs.first != rhs.first { return lhs.first < rhs.first }
            return DayEvent.isOrderedBefore(lhs.event, rhs.event)
        }

        // Each lane tracks which of the week's columns it has already given
        // away, so an event takes the topmost lane free for its whole span.
        var lanes: [[Bool]] = []
        var segments: [WeekEventSegment] = []

        for span in ordered {
            let columns = span.first...span.last
            var lane = 0
            while true {
                if lane == lanes.count {
                    lanes.append(Array(repeating: false, count: days.count))
                }
                if columns.allSatisfy({ !lanes[lane][$0] }) { break }
                lane += 1
            }

            for column in columns { lanes[lane][column] = true }
            segments.append(
                WeekEventSegment(event: span.event, startColumn: span.first, endColumn: span.last, lane: lane)
            )
        }

        return segments
    }
}

/// Renders a grid against made-up events, so the layout can be checked without
/// depending on whatever is in the real calendar database.
private struct CalendarGridPreview: View {
    let grid: CalendarGrid

    /// How many single-day events to put on each day, keyed by the day's
    /// position in the grid — which, unlike a day number, doesn't repeat
    /// across a span that straddles two months.
    let eventCounts: [Int: Int]

    /// Events covering a run of days, as (first day's position, length).
    var spans: [(start: Int, length: Int)] = []

    /// A spread of colours that straddles the point where the bar text has to
    /// flip from white to black.
    private static let palette: [Color] = [
        Color(red: 0.00, green: 0.48, blue: 1.00),
        Color(red: 1.00, green: 0.23, blue: 0.19),
        Color(red: 1.00, green: 0.80, blue: 0.00),
        Color(red: 0.20, green: 0.78, blue: 0.35),
        Color(red: 0.69, green: 0.32, blue: 0.87),
    ]

    private static let textColors: [Color] = [.white, .white, .black, .black, .white]

    var body: some View {
        GeometryReader { proxy in
            CalendarGridView(
                grid: grid,
                eventsByDay: eventsByDay,
                selectedDay: .constant(grid.calendar.startOfDay(for: .now)),
                rowHeight: proxy.size.height / CGFloat(grid.weekCount)
            )
        }
    }

    private var eventsByDay: [Date: [DayEvent]] {
        let titles = ["Standup", "Design review", "Lunch with Sam", "1:1", "Dentist", "Retro"]
        var result: [Date: [DayEvent]] = [:]

        for (index, day) in grid.days.enumerated() {
            guard !grid.isDimmed(day), let count = eventCounts[index] else { continue }

            result[day] = (0..<count).map { position in
                DayEvent(
                    id: "\(index)-\(position)",
                    title: titles[position % titles.count],
                    start: day,
                    end: day,
                    color: Self.palette[position % Self.palette.count],
                    titleColor: Self.textColors[position % Self.textColors.count]
                )
            }
        }

        // A multi-day event is one value listed under every day it covers,
        // which is how the real event store groups them too.
        let spanTitles = ["Berlin trip", "Conference", "Sam on leave"]
        for (number, span) in spans.enumerated() {
            let days = grid.days[span.start..<min(span.start + span.length, grid.days.count)]
            guard let first = days.first, let last = days.last else { continue }

            let event = DayEvent(
                id: "span-\(number)",
                title: spanTitles[number % spanTitles.count],
                start: first,
                end: last,
                isAllDay: true,
                color: Self.palette[(number + 3) % Self.palette.count],
                titleColor: Self.textColors[(number + 3) % Self.textColors.count]
            )
            for day in days {
                result[day, default: []].append(event)
            }
        }

        return result
    }
}

/// The height the grid gets inside a 4x4 widget, once its weekday header and
/// padding are taken out. The grid reads its own container height, so the
/// preview has to bound it the way the app does — an unbounded canvas would
/// feed an enormous height back into the rows.
private let previewGridHeight = WidgetMetrics.systemLarge.height - 40

#Preview("Quiet month") {
    CalendarGridPreview(
        grid: .month(containing: .now),
        eventCounts: [6: 1, 14: 2, 22: 1],
        spans: [(start: 9, length: 4)]
    )
    .frame(height: previewGridHeight)
}

#Preview("Busy month") {
    CalendarGridPreview(
        grid: .month(containing: .now),
        eventCounts: [4: 1, 5: 6, 6: 2, 11: 3, 12: 1, 18: 4, 19: 2, 25: 5, 26: 1, 27: 2],
        spans: [(start: 3, length: 6), (start: 16, length: 9)]
    )
    .frame(height: previewGridHeight)
}

#Preview("Four weeks") {
    CalendarGridPreview(
        grid: .weeks(4, containing: .now),
        eventCounts: [1: 2, 2: 1, 8: 4, 9: 1, 15: 2, 16: 3, 22: 1, 25: 2],
        spans: [(start: 4, length: 5), (start: 18, length: 3)]
    )
    .frame(height: previewGridHeight)
}
