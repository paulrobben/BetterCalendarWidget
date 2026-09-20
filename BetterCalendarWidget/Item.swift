//
//  Item.swift
//  BetterCalendarWidget
//
//  Created by Paul on 20.09.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
