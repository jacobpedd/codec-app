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
    private let debug: Bool
    
    init(token: String, debug: Bool = false) {
        self.token = token
        self.debug = debug
    }
    
    func loadQueue(excludeClipIds: [Int]? = nil) async -> [Clip] {
        // Base URL
        var urlString = "\(baseURL)/queue/"
        
        // Check if excludeClipIds exists and is not empty
        if let ids = excludeClipIds, !ids.isEmpty {
            // Join the ids into a comma-separated string
            let idsString = ids.map { String($0) }.joined(separator: ",")
            // Append the query parameter to the URL
            urlString += "?exclude_clip_ids=\(idsString)"
        }
        
        // Call the loadGeneric function with the constructed URL
        let queue = await loadGeneric(from: urlString, type: Clip.self)
        return queue
    }
    
    func loadHistory() async -> [UserClipView] {
        let history = await loadGeneric(from: "\(baseURL)/history/", type: UserClipView.self)
        return history.reversed()
    }
    
    func loadFollowedShows() async -> [UserFeedFollow] {
        let follows = await loadGeneric(from: "\(baseURL)/following/", type: UserFeedFollow.self)
        return follows
    }
    
    private func loadGeneric<T: Codable>(from urlString: String, type: T.Type) async -> [T] {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
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
                let decodedResponse = try decoder.decode(PaginatedResponse<T>.self, from: data)
                return decodedResponse.results
            } catch {
                print("Failed to decode PaginatedResponse<\(T.self)>: \(error)")
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
    
    func updateView(clipId: Int, duration: Int) async -> Bool {
        if debug {
            print("Viewed \(clipId): \(duration)%")
            return true
        }
        guard let url = URL(string: "\(baseURL)/view/") else {
            print("Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "clip": clipId,
            "duration": duration
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("Successfully updated view progress for clip \(clipId): \(duration)%")
                return true
            } else {
                print("Failed to update view progress for clip \(clipId): \(response)")
                return false
            }
        } catch {
            print("Error updating view progress for clip \(clipId): \(error)")
            return false
        }
    }
    
    func searchShows(query: String) async -> [Feed] {
        guard let url = URL(string: "\(baseURL)/feed/?search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            print("Invalid URL")
            return []
        }
        
        print("Searching with url \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
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
            
            let searchResults = try decoder.decode(PaginatedResponse<Feed>.self, from: data)
            return searchResults.results
        } catch {
            print("Error searching shows: \(error)")
            return []
        }
    }
    
    func followShow(feedId: Int) async -> Bool {
        guard let url = URL(string: "\(baseURL)/following/") else {
            print("Invalid URL")
            return false
        }
        print("Follow show: \(feedId)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["feed_id": feedId, "is_interested": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            print(response)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                return true
            } else {
                return false
            }
        } catch {
            print("Error following show: \(error)")
            return false
        }
    }
    
    func unfollowShow(followId: Int) async -> Bool {
        guard let url = URL(string: "\(baseURL)/following/\(followId)/") else {
            print("Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
                print("Successfully unfollowed show")
                return true
            } else {
                print("Failed to unfollow show: \(response)")
                return false
            }
        } catch {
            print("Error unfollowing show: \(error)")
            return false
        }
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
