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
    @Published var nowPlayingIndex: Int = 0
    @Published private(set) var topicArtworks = [Int: Artwork]()

    var playingTopic: Topic? {
        if feed.count > 0 {
            return feed[nowPlayingIndex]
        }
        return nil
    }
    
    func previous() {
        if nowPlayingIndex > 0 {
            nowPlayingIndex -= 1
        }
    }
    
    func next() {
        if nowPlayingIndex < feed.count - 1 {
            nowPlayingIndex += 1
        }
    }
    
    func deleteTopicIndex(at index: Int) {
        guard index >= 0 && index < feed.count else { return }
        if nowPlayingIndex >= index {
            nowPlayingIndex = max(0, nowPlayingIndex - 1)
        }
        feed.remove(at: index)
    }
    
    func deleteTopicId(at id: Int) {
        if let topicIndex = feed.firstIndex(where: { $0.id == id }) {
            if  nowPlayingIndex >= topicIndex {
                nowPlayingIndex = max(0, nowPlayingIndex - 1)
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
        let history = await loadHistory()
        let queue = await loadQueue()
        
        feed = history + queue
        nowPlayingIndex = history.count - 1
        
        for topic in feed {
            loadImageForTopic(topic)
        }
    }

    private func loadQueue() async -> [Topic] {
        guard let url = URL(string: "https://api.wirehead.tech/queue?email=jacob.peddicord@hey.com") else {
            print("Invalid URL")
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return decodeData(data: data)
        } catch {
            print("Error: \(error)")
            return []
        }
    }

    private func loadHistory() async -> [Topic]{
        guard let url = URL(string: "https://api.wirehead.tech/history?email=jacob.peddicord@hey.com") else {
            print("Invalid URL")
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return decodeData(data: data)
        } catch {
            print("Error: \(error)")
            return []
        }
    }

    private func decodeData(data: Data) -> [Topic] {
        do {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            let decodedResponse = try decoder.decode([Topic].self, from: data)
            return decodedResponse
        } catch {
            print("Error: \(error)")
            return []
        }
    }
    
    private func loadImageForTopic(_ topic: Topic) {
        if let image = topic.image {
            let urlString = "https://bucket.wirehead.tech/\(image)"
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
}
