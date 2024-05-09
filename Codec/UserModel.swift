//
//  UserModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/9/24.
//

import Foundation
import UIKit

class UserModel: ObservableObject {
    @Published private(set) var feed = [Topic]()
    @Published private(set) var images = [Int: UIImage]()
    @Published var playingIndex: Int = 0

    var currentTopic: Topic {
        return feed[playingIndex]
    }
    
    func next() {
        if (playingIndex < feed.count - 1) {
            playingIndex += 1
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
            
            let decodedResponse = try! decoder.decode([Topic].self, from: data)
            feed = decodedResponse
            
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
                    self?.images[topic.id] = image
                }
            }
        }.resume()
    }
}

