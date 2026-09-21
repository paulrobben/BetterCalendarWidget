//
//  ContentView.swift
//  BetterCalendarWidget
//
//  Created by Paul on 20.09.26.
//

import EventKit
import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL

    @State private var eventStore = CalendarEventStore()
    @State private var month = CalendarMonth(containing: .now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var isShowingSettings = false
    @State private var detailedEvent: DetailedEvent?
    @State private var draftEvent: DraftEvent?

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

                    ToolbarItem(placement: .topBarLeading) {
                        Button("Settings", systemImage: "gearshape") {
                            isShowingSettings = true
                        }
                        .disabled(eventStore.access != .granted)
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    CalendarSettingsView(
                        options: eventStore.calendarOptions(),
                        writableOptions: eventStore.writableCalendarOptions(),
                        hiddenIdentifiers: $eventStore.hiddenCalendarIdentifiers,
                        newEventCalendarIdentifier: $eventStore.newEventCalendarIdentifier
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
                .padding(.top, 12)

            dayActions
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()

            DayEventsView(
                day: selectedDay,
                events: eventStore.events(on: selectedDay),
                onSelect: showDetail
            )
        }
        .sheet(item: $detailedEvent) { detailed in
            EventDetailView(event: detailed.event) { detailedEvent = nil }
        }
        .sheet(item: $draftEvent) { draft in
            EventEditorView(event: draft.event, store: eventStore.writingStore) {
                draftEvent = nil
            }
        }
    }

    /// What can be done with the selected day: add an event to it, or hand the
    /// day over to Apple's Calendar.
    private var dayActions: some View {
        HStack(spacing: 12) {
            addEventButton
            openCalendarButton
        }
        .controlSize(.large)
    }

    private var addEventButton: some View {
        Button {
            addEvent()
        } label: {
            Label("Add Event", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    /// Hands the selected day to Apple's Calendar. Icon only: adding an event
    /// is the more likely thing to want, so it takes the width.
    private var openCalendarButton: some View {
        Button("Open in Calendar", systemImage: "calendar") {
            openSystemCalendar()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
    }

    /// Opens EventKit's editor on a new event, at the selected day and the
    /// current time. Nothing is written unless the person taps Add.
    private func addEvent() {
        guard let event = eventStore.draftEvent(on: selectedDay) else { return }
        draftEvent = DraftEvent(event: event)
    }

    /// Shows EventKit's detail for a tapped event. Silently does nothing if the
    /// event has been deleted since the day list was drawn.
    private func showDetail(_ dayEvent: DayEvent) {
        guard let event = eventStore.ekEvent(for: dayEvent) else { return }
        detailedEvent = DetailedEvent(id: dayEvent.id, event: event)
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

    /// Opens Apple's Calendar on the selected day. `calshow:` takes the day to
    /// show as whole seconds since the reference date; without one it opens
    /// wherever the person last left it.
    private func openSystemCalendar() {
        let seconds = Int(selectedDay.timeIntervalSinceReferenceDate)
        guard let url = URL(string: "calshow:\(seconds)") else { return }
        openURL(url)
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

/// The event whose detail is showing. `EKEvent` is a reference type with no
/// identity `sheet(item:)` can use, so the `DayEvent` it came from lends its
/// own — unique per occurrence.
private struct DetailedEvent: Identifiable {
    let id: String
    let event: EKEvent
}

/// The unsaved event the editor is filling in. A fresh id each time, so
/// reopening the editor presents a new draft rather than reusing the last.
private struct DraftEvent: Identifiable {
    let id = UUID()
    let event: EKEvent
}

#Preview {
    ContentView()
}
