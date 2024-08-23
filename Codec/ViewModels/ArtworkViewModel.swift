//
//  ArtworkViewModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/20/24.
//

import SwiftUI

class ArtworkViewModel: ObservableObject {
    private var feedArtworks = [Int: Artwork]()
    private let artworkLoader: ArtworkLoader
    
    init(session: URLSession) {
        self.artworkLoader = ArtworkLoader(session: session)
    }
    
    func loadArtwork(for feed: Feed, completion: @escaping (Artwork?) -> Void) {
        if let cachedArtwork = feedArtworks[feed.id] {
            completion(cachedArtwork)
            return
        }
        
        artworkLoader.loadFeedArtwork(for: feed) { [weak self] artwork in
            DispatchQueue.main.async {
                if let artwork = artwork {
                    self?.feedArtworks[feed.id] = artwork
                }
                completion(artwork)
            }
        }
    }
}
