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
    var audio: String // id of the audio file
    var createdAt: Date
    
    init(id: Int, title: String, audio: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.audio = audio
    }
}
