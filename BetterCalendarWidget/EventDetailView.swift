//
//  EventDetailView.swift
//  BetterCalendarWidget
//

import EventKit
import EventKitUI
import SwiftUI

/// EventKit's own event detail, shown when a day's event is tapped.
///
/// `EKEventViewController` is a plain view controller, so it comes wrapped in a
/// navigation controller for the title bar, and Done is added here — it brings
/// no dismiss control of its own.
struct EventDetailView: UIViewControllerRepresentable {
    let event: EKEvent

    /// Called when the person closes the detail, or when EventKit closes it
    /// itself — after the event is deleted from Apple's Calendar, say.
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let detail = EKEventViewController()
        detail.event = event
        // This app only shows events; the Open in Calendar button hands off to
        // Apple's Calendar for anything that changes one.
        detail.allowsEditing = false
        detail.delegate = context.coordinator
        detail.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { _ in context.coordinator.finish() }
        )

        return UINavigationController(rootViewController: detail)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    final class Coordinator: NSObject, EKEventViewDelegate {
        var onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func finish() {
            onFinish()
        }

        // Dismissing is the delegate's job, which here means clearing the
        // state driving the sheet.
        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            onFinish()
        }
    }
}

/// EventKit's own event editor, shown when adding an event.
///
/// Unlike `EKEventViewController` this one is a navigation controller already,
/// and brings its own Cancel and Add buttons. Saving fires an
/// `EKEventStoreChanged` notification, which the app is already listening for,
/// so the grid and the widgets pick the new event up on their own.
struct EventEditorView: UIViewControllerRepresentable {
    /// The event to edit, which must have come from `store`.
    let event: EKEvent
    let store: EKEventStore
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let editor = EKEventEditViewController()
        editor.event = event
        editor.eventStore = store
        editor.editViewDelegate = context.coordinator
        return editor
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        var onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onFinish()
        }
    }
}
