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
    
    func postView(uuid: String, duration: Double, completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "https://api.wirehead.tech/view") else {
            print("Invalid URL")
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = ["itemId": uuid, "duration": duration, "email": "jacob.peddicord@hey.com"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion?(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("Server error")
                completion?(false)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion?(false)
                return
            }
            
//            if let responseString = String(data: data, encoding: .utf8) {
//                print("Response: \(responseString)")
//            }
            
            completion?(true)
        }.resume()
    }
}
