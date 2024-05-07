//
//  Topic.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import Foundation

class Topic: Codable, Identifiable {
    var id: Int
    var title: String
    var createdAt: Date
    
    init(id: Int, title: String = "", createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
