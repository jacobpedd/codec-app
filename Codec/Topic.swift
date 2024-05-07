//
//  Topic.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import Foundation
import SwiftData

@Model
class Topic {
    var id: String
    var title: String
    var preview: String
    var addedAt: Date
    var viewedAt: Date? = nil
    var dismissedAt: Date? = nil
    
    init(id: String, title: String = "", preview: String = "", addedAt: Date = .now) {
        self.id = id
        self.title = title
        self.preview = preview
        self.addedAt = addedAt
    }
}
