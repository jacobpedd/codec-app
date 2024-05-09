//
//  UserDataModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/9/24.
//

import Foundation

class UserDataModel: ObservableObject {
    @Published private(set) var feed = [Topic]()
    @Published var feedIndex: Int = 0
    
    var currentTopic: Topic {
        return feed[feedIndex]
    }
    
    func next() {
        if (feedIndex < feed.count - 1) {
            feedIndex += 1
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
        } catch {
            print("Error: \(error)")
        }
    }
}
