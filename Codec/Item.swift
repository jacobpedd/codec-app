//
//  Item.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
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
