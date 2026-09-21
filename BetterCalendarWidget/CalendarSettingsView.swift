//
//  CalendarSettingsView.swift
//  BetterCalendarWidget
//

import SwiftUI
import UIKit

/// Lets the person choose which calendars the month view shows. The choice is
/// stored in the App Group, so the widget honours it too.
struct CalendarSettingsView: View {
    let options: [CalendarOption]

    /// The calendars a new event can go in, which is a subset of `options`.
    let writableOptions: [CalendarOption]

    @Binding var hiddenIdentifiers: Set<String>
    @Binding var newEventCalendarIdentifier: String?

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
            newEventSection

            calendarsSection

            aboutSection
        }
    }

    /// Every calendar in one section, ordered by the account it comes from so
    /// calendars from the same account stay together.
    private var calendarsSection: some View {
        Section {
            ForEach(options) { option in
                Toggle(isOn: visibility(of: option)) {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.title)

                            // The account, now that there are no longer a
                            // section per account to say which is which.
                            Text(option.sourceTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        } header: {
            Text("Calendars")
        } footer: {
            if hiddenIdentifiers.count == options.count {
                Text("Every calendar is hidden, so the month is empty.")
            }
        }
    }

    private var newEventSection: some View {
        Section {
            Picker("Default Calendar", selection: $newEventCalendarIdentifier) {
                Text("System Default").tag(String?.none)

                ForEach(writableOptions) { option in
                    Label {
                        Text(option.title)
                    } icon: {
                        Self.colourDot(option.color)
                    }
                    .tag(Optional(option.id))
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("New Events")
        } footer: {
            Text("Where the Add Event button puts an event. Read-only calendars, such as subscribed holidays, aren't listed.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            if let repository = Self.repository {
                Link(destination: repository) {
                    HStack {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private static let repository = URL(string: "https://github.com/paulrobben/BetterCalendarWidget")

    /// A dot in a calendar's own colour, for the picker menu.
    ///
    /// Drawn to a bitmap rather than tinting `circle.fill`: the menu is a UIKit
    /// menu, which renders a symbol in the label colour whatever the view asks
    /// for, so a tinted symbol came out black.
    ///
    /// The gap to the title is drawn into the image too. A `Label` gives no say
    /// over the space between its icon and text, and the row showing the
    /// current choice had the two almost touching.
    private static func colourDot(_ colour: Color) -> Image {
        let dot = Circle()
            .fill(colour)
            .frame(width: 10, height: 10)
            .padding(.trailing, 5)

        let renderer = ImageRenderer(content: dot)
        renderer.scale = 3

        guard let dot = renderer.uiImage?.withRenderingMode(.alwaysOriginal) else {
            return Image(systemName: "circle.fill")
        }
        return Image(uiImage: dot)
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
    @Previewable @State var newEventCalendar: String? = "home"

    let options = [
        CalendarOption(id: "home", title: "Home", color: .blue, sourceTitle: "iCloud"),
        CalendarOption(id: "work", title: "Work", color: .red, sourceTitle: "iCloud"),
        CalendarOption(id: "holidays", title: "German Holidays", color: .purple, sourceTitle: "Other"),
    ]

    return CalendarSettingsView(
        options: options,
        // A subscribed holiday calendar can't take new events.
        writableOptions: Array(options.prefix(2)),
        hiddenIdentifiers: $hidden,
        newEventCalendarIdentifier: $newEventCalendar
    )
}
