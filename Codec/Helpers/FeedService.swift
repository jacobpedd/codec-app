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
    private var loadedClipIds: Set<Int> = [] // Store clip IDs in memory and never load them twice
    
    init(token: String, debug: Bool = false) {
        self.token = token
        self.debug = debug
    }
    
    func loadQueue(category: Category? = nil) async -> [Clip] {
        // Base URL
        var urlString = "\(baseURL)/queue/"
        
        var queryItems = [String]()
        
        // Always exclude already loaded clips
        if !loadedClipIds.isEmpty {
            let idsString = loadedClipIds.map { String($0) }.joined(separator: ",")
            queryItems.append("exclude_clip_ids=\(idsString)")
        }
        
        // Check if category exists
        if let category {
            queryItems.append("topic_ids=\(category.id)")
        }
        
        // If there are any query items, join them with "&" and append to the urlString
        if !queryItems.isEmpty {
            urlString += "?" + queryItems.joined(separator: "&")
        }
        
        // Call the loadGeneric function with the constructed URL
        let newClips = await loadGeneric(from: urlString, type: Clip.self)
        
        // Add new clip IDs to the loaded set
        loadedClipIds.formUnion(newClips.map { $0.id })
        return newClips
    }
    
    func loadHistory() async -> [UserClipView] {
        let history = await loadGeneric(from: "\(baseURL)/history/", type: UserClipView.self)
        return history.reversed()
    }
    
    func loadFollowedShows() async -> [UserFeedFollow] {
        let follows = await loadGeneric(from: "\(baseURL)/following/", type: UserFeedFollow.self)
        return follows
    }
    
    func loadCategories() async -> [Category] {
        let urlString = "\(baseURL)/categories/?should_display=true"
        let categories = await loadGeneric(from: urlString, type: Category.self)
        return categories
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
    
    func followShow(feedId: Int, isInterested: Bool = true) async -> Bool {
        guard let url = URL(string: "\(baseURL)/following/") else {
            print("Invalid URL")
            return false
        }
        print("Follow show: \(feedId)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["feed_id": feedId, "is_interested": isInterested]
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
    
    func getUserCategoryScores() async -> [UserCategoryScore] {
        let scores = await loadGeneric(from: "\(baseURL)/user_category_scores/", type: UserCategoryScore.self)
        return scores.sorted { $0.createdAt < $1.createdAt }
    }
    
    func updateUserCategoryScore(categoryId: Int, score: Float) async -> Bool {
        guard let url = URL(string: "\(baseURL)/user_category_scores/") else {
            print("Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "category": categoryId,
            "score": score
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("Successfully updated category score for category \(categoryId): \(score)")
                return true
            } else {
                print("Failed to update category score for category \(categoryId): \(response)")
                return false
            }
        } catch {
            print("Error updating category score for category \(categoryId): \(error)")
            return false
        }
    }
    
    func deleteUserCategoryScore(categoryScoreId: Int) async -> Bool {
        guard let url = URL(string: "\(baseURL)/user_category_scores/\(categoryScoreId)/") else {
            print("Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("Successfully deleted category score \(categoryScoreId)")
                return true
            } else {
                print("Failed to delete category score \(categoryScoreId): \(response)")
                return false
            }
        } catch {
            print("Error deleting category score \(categoryScoreId): \(error)")
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
