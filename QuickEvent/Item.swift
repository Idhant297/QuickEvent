//
//  Item.swift
//  QuickEvent
//
//  Created by Idhant Gulati on 3/22/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var text: String?
    var id: UUID
    
    init(timestamp: Date, text: String? = nil) {
        self.timestamp = timestamp
        self.text = text
        self.id = UUID()
    }
}
