//
//  WidgetMetrics.swift
//  BetterCalendarWidget
//

import CoreGraphics

/// Home Screen widget dimensions, used to show the month at the size it will
/// occupy as a widget.
///
/// WidgetKit tells a real widget its own size, so these values are only for
/// the in-app preview. Apple's guidance is that widget sizes vary by device —
/// this is the `systemLarge` size on a 393pt-wide iPhone, which is close
/// enough to convey the real thing on any modern phone.
enum WidgetMetrics {
    /// A 4x4 (`systemLarge`) widget.
    static let systemLarge = CGSize(width: 338, height: 354)

    /// The Home Screen's corner radius for a widget of this size.
    static let cornerRadius: CGFloat = 22
}
