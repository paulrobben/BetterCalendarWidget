//
//  ContentView.swift
//  BetterCalendarWidget
//
//  Created by Paul on 20.09.26.
//

import SwiftUI

struct ContentView: View {
    @State private var eventStore = CalendarEventStore()
    @State private var month = CalendarMonth(containing: .now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(month.title)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Previous Month", systemImage: "chevron.left") {
                            changeMonth(by: -1)
                        }
                        Button("Today") {
                            goToToday()
                        }
                        .disabled(month.contains(.now) && isTodaySelected)
                        Button("Next Month", systemImage: "chevron.right") {
                            changeMonth(by: 1)
                        }
                    }

                    ToolbarItem(placement: .bottomBar) {
                        Button("Settings", systemImage: "gearshape") {
                            isShowingSettings = true
                        }
                        .disabled(eventStore.access != .granted)
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    CalendarSettingsView(
                        options: eventStore.calendarOptions(),
                        hiddenIdentifiers: $eventStore.hiddenCalendarIdentifiers
                    )
                }
        }
        .task {
            await eventStore.requestAccess()
        }
        .task {
            await eventStore.observeStoreChanges()
        }
        // Refetch whenever the visible month changes, and once more as soon as
        // access is granted.
        .task(id: LoadKey(monthStart: month.start, access: eventStore.access)) {
            eventStore.loadEvents(in: grid.gridRange)
        }
    }

    /// The weeks the current month is drawn as.
    private var grid: CalendarGrid { month.grid }

    @ViewBuilder
    private var content: some View {
        switch eventStore.access {
        case .pending:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            CalendarAccessDeniedView()
        case .granted:
            monthOverview
        }
    }

    private var monthOverview: some View {
        VStack(spacing: 0) {
            widgetSizedMonth
                .padding(.vertical, 12)

            Divider()

            DayEventsView(day: selectedDay, events: eventStore.events(on: selectedDay))
        }
    }

    /// The month at the size it occupies as a 4x4 widget. Days cap their bars
    /// to the row height, so this never needs to scroll.
    private var widgetSizedMonth: some View {
        VStack(spacing: 2) {
            WeekdayHeaderView(symbols: grid.weekdaySymbols)

            // A GeometryReader in a stack takes the space the fixed-size
            // siblings leave, which is exactly the height to divide by.
            GeometryReader { proxy in
                CalendarGridView(
                    grid: grid,
                    eventsByDay: eventStore.eventsByDay,
                    selectedDay: $selectedDay,
                    onPeriodChange: changeMonth,
                    rowHeight: proxy.size.height / CGFloat(grid.weekCount)
                )
            }
        }
        .padding(8)
        .frame(width: WidgetMetrics.systemLarge.width, height: WidgetMetrics.systemLarge.height)
        .background(.background.secondary, in: .rect(cornerRadius: WidgetMetrics.cornerRadius))
    }

    private var isTodaySelected: Bool {
        eventStore.calendar.isDateInToday(selectedDay)
    }

    // The grid is deliberately not animated: animating it cross-fades each
    // cell's text, so the outgoing and incoming day numbers overlap.
    private func changeMonth(by delta: Int) {
        let next = month.advanced(by: delta)
        month = next
        // Keep the selection visible in the month the person is now looking at.
        if !next.contains(selectedDay) {
            selectedDay = next.preferredSelection
        }
    }

    private func goToToday() {
        month = CalendarMonth(containing: .now, calendar: eventStore.calendar)
        selectedDay = eventStore.calendar.startOfDay(for: .now)
    }
}

/// Identifies a fetch, so the events reload on a month change *and* on the
/// transition from pending to granted access.
private struct LoadKey: Equatable {
    let monthStart: Date
    let access: CalendarAccess
}

#Preview {
    ContentView()
}
