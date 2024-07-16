//
//  ArtworkCache.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/16/24.
//

/**
 ArtworkCache

 This class provides a caching mechanism for artwork images in the Codec app.

 Key features:
 - Stores artwork images in the app's Caches directory
 - Caches up to 100 most recently used artwork images
 - Provides methods to save, retrieve, and manage cached images
 - Automatically cleans up older cache entries when the limit is exceeded

 Usage:
 - Use `cacheArtwork(_:for:)` to save an artwork image
 - Use `getCachedArtwork(for:)` to retrieve a cached artwork image
 - The cache is automatically managed, removing older entries when needed

 Note: The cached data may be deleted by the system if storage space is needed,
 so the app should be prepared to re-download artworks if they're not found in the cache.
 */

import Foundation
import UIKit

class ArtworkCache {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize = 100
    
    init() {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("ArtworkCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func cacheArtwork(_ artwork: UIImage, for feedId: Int) {
        let fileURL = cacheDirectory.appendingPathComponent("\(feedId).png")
        try? artwork.pngData()?.write(to: fileURL)
        
        cleanupCacheIfNeeded()
    }
    
    func getCachedArtwork(for feedId: Int) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent("\(feedId).png")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    private func cleanupCacheIfNeeded() {
        let cachedFiles = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
        guard let files = cachedFiles, files.count > maxCacheSize else { return }
        
        let sortedFiles = files.sorted { (file1, file2) -> Bool in
            let date1 = try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return date1! < date2!
        }
        
        for file in sortedFiles.prefix(files.count - maxCacheSize) {
            try? fileManager.removeItem(at: file)
        }
    }
}
