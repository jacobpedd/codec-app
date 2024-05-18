//
//  Topic.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import Foundation

class Topic: Codable, Identifiable, CustomStringConvertible {
    var id: Int
    var title: String
    var script: String
    var audio: String // bucket key of the audio file
    var image: String // bucket key of the image file
    var createdAt: Date
    
    init(id: Int, title: String, script: String, audio: String, image: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.script = script
        self.audio = audio
        self.image = image
        self.createdAt = createdAt
    }
    
    var description: String {
        let string = String(title)
        return string
    }
}
