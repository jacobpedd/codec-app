//
//  FeedService.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/20/24.
//

import Foundation

class FeedService {
    func loadQueue() async -> [Topic] {
        await load(from: "https://api.wirehead.tech/queue?email=jacob.peddicord@hey.com")
    }

    func loadHistory() async -> [Topic] {
        await load(from: "https://api.wirehead.tech/history?email=jacob.peddicord@hey.com").reversed()
    }

    private func load(from urlString: String) async -> [Topic] {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            let decodedResponse = try decoder.decode([Topic].self, from: data)
            return decodedResponse
        } catch {
            print("Network error: \(error)")
            return []
        }
    }
}
