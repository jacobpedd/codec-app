//
//  ArtworkLoader.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import Foundation
import UIKit

class ArtworkLoader {
    private let session: URLSession
    private let cache: ArtworkCache

    init(session: URLSession = .shared) {
        self.session = session
        self.cache = ArtworkCache()
    }

    func loadFeedArtwork(for feed: Feed, completion: @escaping (Artwork?) -> Void) {
        if let cachedImage = cache.getCachedArtwork(for: feed.id) {
            completion(Artwork(image: cachedImage))
            return
        }

        guard let feedURL = URL(string: feed.url) else {
            print("Invalid feed URL")
            completion(nil)
            return
        }
        
        let task = session.dataTask(with: feedURL) { data, response, error in
            if let error = error {
                print("Error fetching RSS feed \(feedURL): \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received from RSS feed")
                completion(nil)
                return
            }
            
            let parser = XMLParser(data: data)
            let delegate = RSSParserDelegate()
            parser.delegate = delegate
            
            if parser.parse(), let imageURLString = delegate.channelImageURL, let imageURL = URL(string: imageURLString) {
                self.downloadImage(from: imageURL) { image in
                    if let image = image {
                        self.cache.cacheArtwork(image, for: feed.id)
                        completion(Artwork(image: image))
                    } else {
                        completion(nil)
                    }
                }
            } else {
                print("No image URL found or failed to parse RSS feed for feed \(feed.id)")
                completion(nil)
            }
        }
        task.resume()
    }
        
    private func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let task = session.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error downloading image: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            if let image = UIImage(data: data) {
                completion(image)
            } else {
                print("Failed to create image from data")
                completion(nil)
            }
        }
        task.resume()
    }
}
