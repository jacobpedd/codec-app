//
//  FeedService.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/20/24.
//

import Foundation

class FeedService {
    var token: String
    private let baseURL = "https://codec.fly.dev"
    
    init(token: String) {
        self.token = token
    }
    
    func loadQueue() async -> [Clip] {
        let queue = await load(from: "\(baseURL)/feed/")
        print("Loaded \(queue.count) items from queue")
        return queue
    }

    func loadHistory() async -> [Clip] {
        let history = await load(from: "\(baseURL)/history/")
        print("Loaded \(history.count) items from history")
        return history
    }

    private func load(from urlString: String) async -> [Clip] {
        print("Loading \(urlString)...")
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            print("Received data from \(urlString)")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatters: [(any DateFormatterProtocol)] = [
                    ISO8601DateFormatter(),
                    DateFormatter.yyyyMMddTHHmmssSSSSSSZ,
                    DateFormatter.yyyyMMddTHHmmssZ
                ]
                
                for formatter in formatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
            }
            
            do {
                print("Attempting to decode PaginatedResponse<Clip>")
                let decodedResponse = try decoder.decode(PaginatedResponse<Clip>.self, from: data)
                print("Successfully decoded PaginatedResponse")
                print("Number of results: \(decodedResponse.results.count)")
                
                if let firstClip = decodedResponse.results.first {
                    print("First clip: \(firstClip)")
                }
                
                print("Loaded and decoded \(urlString)")
                return decodedResponse.results
            } catch {
                print("Failed to decode PaginatedResponse<Clip>: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    case .valueNotFound(let value, let context):
                        print("Value '\(value)' not found:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    case .dataCorrupted(let context):
                        print("Data corrupted:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                return []
            }
        } catch {
            print("Network error: \(error)")
            return []
        }
    }
    
    func postView(clipId: Int, duration: Double) async -> Bool {
        guard let url = URL(string: "\(baseURL)/view/") else {
            print("Invalid URL")
            return false
        }
        return true
    }
}

struct PaginatedResponse<T: Codable>: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [T]
}

protocol DateFormatterProtocol {
    func date(from string: String) -> Date?
}

extension ISO8601DateFormatter: DateFormatterProtocol {}
extension DateFormatter: DateFormatterProtocol {}

extension DateFormatter {
    static let yyyyMMddTHHmmssSSSSSSZ: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static let yyyyMMddTHHmmssZ: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
