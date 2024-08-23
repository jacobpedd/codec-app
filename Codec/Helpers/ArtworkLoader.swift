import Foundation
import UIKit

class ArtworkLoader {
    private let session: URLSession
    private let cache: ArtworkCache
    private let bucketBaseURL = "https://bucket.trycodec.com/"

    init(session: URLSession = .shared) {
        self.session = session
        self.cache = ArtworkCache()
    }

    func loadFeedArtwork(for feed: Feed, completion: @escaping (Artwork?) -> Void) {
        if let cachedImage = cache.getCachedArtwork(for: feed.id) {
            // No need to resize since the image should already be resized before caching
            DispatchQueue.main.async {
                completion(Artwork(image: cachedImage))
            }
            return
        }

        guard let artworkURL = URL(string: bucketBaseURL + feed.artworkBucketKey) else {
            print("Invalid artwork URL for feed \(feed.id)")
            completion(nil)
            return
        }

        downloadImage(from: artworkURL) { image in
            guard let image = image else {
                print("Failed to download artwork for feed \(feed.id)")
                completion(nil)
                return
            }
            
            let thumbnailSize = CGSize(width: 500, height: 500)
            image.prepareThumbnail(of: thumbnailSize) { thumbnail in
                guard let thumbnail = thumbnail else {
                    print("Failed to create thumbnail for feed \(feed.id)")
                    completion(nil)
                    return
                }
                
                self.cache.cacheArtwork(thumbnail, for: feed.id)
                DispatchQueue.main.async {
                    completion(Artwork(image: thumbnail))
                }
            }
        }
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
