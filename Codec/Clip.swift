//
//  Clip.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/3/24.
//

import Foundation

struct Clip: Codable, Identifiable {
    let id: Int
    let name: String
    let body: String
    let summary: String
    let startTime: Int
    let endTime: Int
    let audioBucketKey: String
    let feedItem: FeedItem
    let score: Int?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, body, summary
        case startTime = "start_time"
        case endTime = "end_time"
        case audioBucketKey = "audio_bucket_key"
        case feedItem = "feed_item"
        case score
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FeedItem: Codable {
    let id: Int
    let name: String
    let feed: Feed
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, feed
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Feed: Codable {
    let id: Int
    let name: String
    let description: String
    let url: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, url
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
