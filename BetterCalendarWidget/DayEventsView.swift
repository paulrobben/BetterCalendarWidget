//
//  DayEventsView.swift
//  BetterCalendarWidget
//

import SwiftUI

/// The events on the day selected in the month grid.
struct DayEventsView: View {
    let day: Date
    let events: [DayEvent]

    var body: some View {
        List {
            Section {
                if events.isEmpty {
                    Text("No Events")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events) { event in
                        EventRow(event: event)
                    }
                }
            } header: {
                Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            }
        }
        .listStyle(.plain)
    }
}

/// A single event: a bar tinted with its calendar's colour, the title, and when
/// it happens.
private struct EventRow: View {
    let event: DayEvent

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(event.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.body)

                Text(timeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let location = event.location {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private var timeDescription: String {
        if event.isAllDay {
            return String(localized: "All day")
        }
        guard event.end > event.start else {
            return event.start.formatted(date: .omitted, time: .shortened)
        }
        return (event.start..<event.end).formatted(.interval.hour().minute())
    }
}

/// Shown when the person has turned down calendar access, since without full
/// access EventKit returns no events at all.
struct CalendarAccessDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("No Calendar Access", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("BetterCalendarWidget needs access to your calendars to show your events.")
        } actions: {
            if let settings = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") {
                    openURL(settings)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
