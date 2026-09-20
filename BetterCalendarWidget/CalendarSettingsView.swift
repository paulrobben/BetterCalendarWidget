//
//  CalendarSettingsView.swift
//  BetterCalendarWidget
//

import SwiftUI

/// Lets the person choose which calendars the month view shows. The choice is
/// stored in the App Group, so the widget honours it too.
struct CalendarSettingsView: View {
    let options: [CalendarOption]
    @Binding var hiddenIdentifiers: Set<String>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if options.isEmpty {
                    ContentUnavailableView(
                        "No Calendars",
                        systemImage: "calendar",
                        description: Text("There are no calendars on this device.")
                    )
                } else {
                    calendarList
                }
            }
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var calendarList: some View {
        List {
            ForEach(groupedBySource, id: \.source) { group in
                Section(group.source) {
                    ForEach(group.options) { option in
                        Toggle(isOn: visibility(of: option)) {
                            Label {
                                Text(option.title)
                            } icon: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
            }

            if hiddenIdentifiers.count == options.count {
                Section {
                    Text("Every calendar is hidden, so the month is empty.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var groupedBySource: [(source: String, options: [CalendarOption])] {
        // `options` arrives sorted by source, so grouping keeps that order.
        Dictionary(grouping: options, by: \.sourceTitle)
            .map { (source: $0.key, options: $0.value) }
            .sorted { $0.source.localizedCompare($1.source) == .orderedAscending }
    }

    private func visibility(of option: CalendarOption) -> Binding<Bool> {
        Binding(
            get: { !hiddenIdentifiers.contains(option.id) },
            set: { isVisible in
                if isVisible {
                    hiddenIdentifiers.remove(option.id)
                } else {
                    hiddenIdentifiers.insert(option.id)
                }
            }
        )
    }
}

#Preview {
    @Previewable @State var hidden: Set<String> = ["work"]

    let options = [
        CalendarOption(id: "home", title: "Home", color: .blue, sourceTitle: "iCloud"),
        CalendarOption(id: "work", title: "Work", color: .red, sourceTitle: "iCloud"),
        CalendarOption(id: "holidays", title: "German Holidays", color: .purple, sourceTitle: "Other"),
    ]

    return CalendarSettingsView(options: options, hiddenIdentifiers: $hidden)
}
