//
//  UserModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/9/24.
//

import Foundation
import UIKit
import SwiftUI

class UserModel: ObservableObject {
    @Published private(set) var feed = [Topic]()
    @Published private(set) var topicArtworks = [Int: Artwork]()
    @Published var playingTopicId: Int? = nil

    var playingTopic: Topic? {
        if let playingTopicId = playingTopicId {
            return feed.first { $0.id == playingTopicId }
        }
        return nil
    }
    
    var playingTopicIndex: Int? {
        if let playingTopicId = playingTopicId {
            return feed.firstIndex { $0.id == playingTopicId }
        }
        return nil
    }
    
    func previous() {
        if let playingTopicIndex {
            if (playingTopicIndex > 0) {
                playingTopicId = feed[playingTopicIndex - 1].id
            }
        }
    }
    
    func next() {
        if let playingTopicIndex {
            if (playingTopicIndex < feed.count - 1) {
                playingTopicId = feed[playingTopicIndex + 1].id
            }
        }
    }
    
    func deleteTopicIndex(at index: Int) {
        guard index >= 0 && index < feed.count else { return }
        if let playingTopicIndex {
            if  playingTopicIndex >= index {
                playingTopicId = feed[max(0, playingTopicIndex - 1)].id
            }
        }
        feed.remove(at: index)
    }
    
    func deleteTopicId(at id: Int) {
        if let topicIndex = feed.firstIndex(where: { $0.id == id }) {
            if let playingTopicIndex {
                if  playingTopicIndex >= topicIndex {
                    playingTopicId = feed[max(0, playingTopicIndex - 1)].id
                }
            }
            
            feed.remove(at: topicIndex)
        }
    }
    
    func moveTopicToFront(at id: Int) {
        if let topicIndex = feed.firstIndex(where: { $0.id == id }) {
            guard topicIndex >= 0 && topicIndex < feed.count else { return }
            let topic = feed.remove(at: topicIndex)
            feed.insert(topic, at: 0)
        }
    }
    
    func moveTopicToBack(at id: Int) {
        if let topicIndex = feed.firstIndex(where: { $0.id == id }) {
            guard topicIndex >= 0 && topicIndex < feed.count else { return }
            let topic = feed.remove(at: topicIndex)
            feed.append(topic)
        }
    }
    
    func loadFeed() async {
        guard let url = URL(string: "https://api.wirehead.tech/queue?email=jacob.peddicord@hey.com") else {
            print("Invalid URL")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            let decodedResponse = try decoder.decode([Topic].self, from: data)
            feed = decodedResponse
            playingTopicId = feed[0].id
            for topic in feed {
                loadImageForTopic(topic)
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    private func loadImageForTopic(_ topic: Topic) {
        let urlString = "https://bucket.wirehead.tech/\(topic.image)"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                if let image = UIImage(data: data) {
                    self?.topicArtworks[topic.id] = Artwork(image: image)
                }
            }
        }.resume()
    }
}
