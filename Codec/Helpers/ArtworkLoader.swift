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

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadFeedArtwork(for feed: Feed, completion: @escaping (Artwork?) -> Void) {
        guard let feedURL = URL(string: feed.url) else {
            print("Invalid feed URL")
            completion(nil)
            return
        }
        
        let task = session.dataTask(with: feedURL) { data, response, error in
            if let error = error {
                print("Error fetching RSS feed: \(error.localizedDescription)")
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
                    completion(image.map { Artwork(image: $0) })
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
