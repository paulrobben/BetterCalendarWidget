//
//  MonthGridView.swift
//  BetterCalendarWidget
//

import SwiftUI

/// The column headings above the month grid.
struct WeekdayHeaderView: View {
    let symbols: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(symbols, id: \.self) { symbol in
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

/// A month laid out as rows of seven days, with a titled bar for each event.
struct MonthGridView: View {
    let month: CalendarMonth
    let eventsByDay: [Date: [DayEvent]]
    @Binding var selectedDay: Date

    /// Called when the person swipes horizontally, or taps a day belonging to
    /// an adjacent month.
    let onMonthChange: (Int) -> Void

    /// The height of every row. Days cap their bars to fit it, so the grid is
    /// always exactly `weekCount * rowHeight` tall.
    let rowHeight: CGFloat

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(month.days, id: \.self) { day in
                DayCell(
                    day: day,
                    calendar: month.calendar,
                    isInMonth: month.contains(day),
                    isSelected: month.calendar.isDate(day, inSameDayAs: selectedDay),
                    events: eventsByDay[day] ?? [],
                    rowHeight: rowHeight
                )
                .contentShape(.rect)
                .onTapGesture { select(day) }
            }
        }
        .gesture(monthSwipe)
    }

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let width = value.translation.width
                guard abs(width) > abs(value.translation.height) else { return }
                onMonthChange(width < 0 ? 1 : -1)
            }
    }

    private func select(_ day: Date) {
        selectedDay = day
        // Tapping a greyed-out day from a neighbouring month follows it there.
        guard !month.contains(day) else { return }
        onMonthChange(day < month.start ? -1 : 1)
    }
}

/// One day in the month grid: its number, then as many titled event bars as
/// the row height allows. Anything that doesn't fit collapses into a `+n`
/// marker, so a busy day can't stretch the row.
private struct DayCell: View {
    let day: Date
    let calendar: Calendar
    let isInMonth: Bool
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
        .opacity(isInMonth ? 1 : 0.4)
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
    private var dayNumber: some View {
        Text(day.formatted(.dateTime.day()))
            .font(.caption)
            .fontWeight(isToday ? .semibold : .regular)
            .monospacedDigit()
            .foregroundStyle(numberColor)
            .frame(width: numberDiameter, height: numberDiameter)
            .background(selectionCircle)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if hiddenCount > 0 {
                    Text("+\(hiddenCount)")
                        .font(.system(size: 8, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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

/// Renders the grid against made-up events, so the layout can be checked
/// without depending on whatever is in the real calendar database.
private struct MonthGridPreview: View {
    /// How many events to put on each day, keyed by day of the month.
    let eventCounts: [Int: Int]

    private let month = CalendarMonth(containing: .now)

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
            MonthGridView(
                month: month,
                eventsByDay: eventsByDay,
                selectedDay: .constant(month.preferredSelection),
                onMonthChange: { _ in },
                rowHeight: proxy.size.height / CGFloat(month.weekCount)
            )
        }
    }

    private var eventsByDay: [Date: [DayEvent]] {
        let titles = ["Standup", "Design review", "Lunch with Sam", "1:1", "Dentist", "Retro"]
        var result: [Date: [DayEvent]] = [:]

        for day in month.days {
            let dayOfMonth = month.calendar.component(.day, from: day)
            guard month.contains(day), let count = eventCounts[dayOfMonth] else { continue }

            result[day] = (0..<count).map { index in
                DayEvent(
                    id: "\(dayOfMonth)-\(index)",
                    title: titles[index % titles.count],
                    start: day,
                    end: day,
                    color: Self.palette[index % Self.palette.count],
                    titleColor: Self.textColors[index % Self.textColors.count]
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
    MonthGridPreview(eventCounts: [4: 1, 12: 2, 20: 1])
        .frame(height: previewGridHeight)
}

#Preview("Busy month") {
    MonthGridPreview(eventCounts: [2: 1, 3: 6, 4: 2, 9: 3, 10: 1, 16: 4, 17: 2, 23: 5, 24: 1, 25: 2])
        .frame(height: previewGridHeight)
}
