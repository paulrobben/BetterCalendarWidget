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
struct CalendarGridView: View {
    let grid: CalendarGrid
    let eventsByDay: [Date: [DayEvent]]
    @Binding var selectedDay: Date

    /// Called when the person swipes horizontally, or taps a dimmed day from
    /// an adjacent period. A grid that dims nothing — four weeks, say — only
    /// ever calls this from a swipe, so widgets leave it at its default.
    var onPeriodChange: (Int) -> Void = { _ in }

    /// The height of every row. Days cap their bars to fit it, so the grid is
    /// always exactly `weekCount * rowHeight` tall.
    let rowHeight: CGFloat

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(grid.days, id: \.self) { day in
                DayCell(
                    day: day,
                    calendar: grid.calendar,
                    isDimmed: grid.isDimmed(day),
                    isSelected: grid.calendar.isDate(day, inSameDayAs: selectedDay),
                    events: eventsByDay[day] ?? [],
                    rowHeight: rowHeight
                )
                .contentShape(.rect)
                .onTapGesture { select(day) }
            }
        }
        .gesture(periodSwipe)
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

/// One day in the grid: its number, then as many titled event bars as the row
/// height allows. Anything that doesn't fit collapses into a `+n` marker, so a
/// busy day can't stretch the row.
private struct DayCell: View {
    let day: Date
    let calendar: Calendar
    /// True for a day the grid shows only as padding, such as a neighbouring
    /// month's days filling out a month's first and last rows.
    let isDimmed: Bool
    let isSelected: Bool
    let events: [DayEvent]

    /// The height the row gives this cell, which decides how many bars fit.
    let rowHeight: CGFloat

    @ScaledMetric(relativeTo: .caption2) private var barHeight: CGFloat = 13
    @ScaledMetric(relativeTo: .caption) private var numberDiameter: CGFloat = 22

    private static let barSpacing: CGFloat = 1.5
    private static let contentSpacing: CGFloat = 2
    private static let verticalPadding: CGFloat = 2

    private var isToday: Bool { calendar.isDateInToday(day) }

    var body: some View {
        VStack(spacing: Self.contentSpacing) {
            dayNumber
            eventBars
        }
        .opacity(isDimmed ? 0.4 : 1)
        .padding(.horizontal, 1.5)
        .padding(.vertical, Self.verticalPadding)
        // maxHeight fills the row, which LazyVGrid sizes to its tallest day.
        // Without it the grid centres shorter cells and the day numbers in a
        // row no longer line up.
        .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// How many bars fit once the day number has taken its share of the row.
    private var barCapacity: Int {
        let reserved = numberDiameter + Self.contentSpacing + Self.verticalPadding * 2
        let available = rowHeight - reserved
        guard available > 0 else { return 0 }
        return Int(available / (barHeight + Self.barSpacing))
    }

    private var hiddenCount: Int {
        max(events.count - barCapacity, 0)
    }

    /// The day number, with the overflow count beside it. The marker sits here
    /// rather than in a bar slot because a 4x4 widget often has room for only
    /// one bar — spending that slot on a "+n" would drop every title.
    ///
    /// The two share a row instead of the marker overlaying the cell's trailing
    /// edge: a cell is only a little wider than the selection circle, so an
    /// overlaid marker collided with the circle on a busy today — and worse at
    /// the larger Dynamic Type sizes, where the circle scales up.
    private var dayNumber: some View {
        HStack(spacing: 1) {
            Text(day.formatted(.dateTime.day()))
                .font(.caption)
                .fontWeight(isToday ? .semibold : .regular)
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .frame(width: numberDiameter, height: numberDiameter)
                .background(selectionCircle)
                // Centres the number in whatever the marker leaves, so a day
                // without one keeps it centred in the cell.
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

    /// One bar per event, filled with its calendar's colour. Cells are narrow,
    /// so titles truncate — the day detail below the grid shows them in full.
    private var eventBars: some View {
        VStack(spacing: Self.barSpacing) {
            ForEach(events.prefix(barCapacity)) { event in
                Text(event.title)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(event.titleColor)
                    .padding(.horizontal, 3)
                    .frame(maxWidth: .infinity, minHeight: barHeight, alignment: .leading)
                    .background(event.color, in: .rect(cornerRadius: 3))
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

    private var accessibilityLabel: String {
        let date = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        guard !events.isEmpty else { return date }
        let titles = events.map(\.title)
        return "\(date), \(titles.formatted(.list(type: .and)))"
    }
}

/// Renders a grid against made-up events, so the layout can be checked without
/// depending on whatever is in the real calendar database.
private struct CalendarGridPreview: View {
    let grid: CalendarGrid

    /// How many events to put on each day, keyed by the day's position in the
    /// grid — which, unlike a day number, doesn't repeat across a span that
    /// straddles two months.
    let eventCounts: [Int: Int]

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
        eventCounts: [6: 1, 14: 2, 22: 1]
    )
    .frame(height: previewGridHeight)
}

#Preview("Busy month") {
    CalendarGridPreview(
        grid: .month(containing: .now),
        eventCounts: [4: 1, 5: 6, 6: 2, 11: 3, 12: 1, 18: 4, 19: 2, 25: 5, 26: 1, 27: 2]
    )
    .frame(height: previewGridHeight)
}

#Preview("Four weeks") {
    CalendarGridPreview(
        grid: .weeks(4, containing: .now),
        eventCounts: [1: 2, 2: 1, 8: 4, 9: 1, 15: 2, 16: 3, 22: 1, 25: 2]
    )
    .frame(height: previewGridHeight)
}
