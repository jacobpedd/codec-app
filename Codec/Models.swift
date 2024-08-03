//
//  Models.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/3/24.
//

import Foundation

struct Clip: Codable, Identifiable, Hashable {
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: Clip, rhs: Clip) -> Bool {
        return lhs.id == rhs.id
    }
}

struct FeedItem: Codable {
    let id: Int
    let name: String
    let feed: Feed
    let postedAt: Date
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, feed
        case postedAt = "posted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Feed: Codable, Identifiable, Hashable {
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: Feed, rhs: Feed) -> Bool {
        return lhs.id == rhs.id
    }
}

struct UserFeedFollow: Codable, Identifiable, Hashable {
    let id: Int
    let user: Int
    let feed: Feed
    let createdAt: Date
    let isInterested: Bool

    enum CodingKeys: String, CodingKey {
        case id, user, feed
        case createdAt = "created_at"
        case isInterested = "is_interested"
    }
}

struct UserClipView: Codable, Identifiable {
    let id: Int
    let clip: Clip
    let createdAt: Date
    let duration: Int

    enum CodingKeys: String, CodingKey {
        case id, clip, duration
        case createdAt = "created_at"
    }
}

