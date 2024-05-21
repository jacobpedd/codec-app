//
//  FeedModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/20/24.
//

import SwiftUI
import AVFoundation

class FeedModel: ObservableObject {
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    
    @Published private var feed = [Topic]()
    @Published private var nowPlayingIndex: Int = 0
    @Published private(set) var topicArtworks = [Int: Artwork]()
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentTime: TimeInterval = 0.0
    @Published private(set) var duration: TimeInterval = 0.0
    @Published var playbackSpeed: Double = 1.0 {
        didSet {
            audioPlayer?.rate = isPlaying ? Float(playbackSpeed) : 0.0
        }
    }
    
    var history: [Topic] {
        if feed.count > 0 {
            return Array(feed[..<nowPlayingIndex])
        } else {
            return []
        }
    }
    
    var nowPlaying: Topic? {
        guard feed.indices.contains(nowPlayingIndex) else { return nil }
        return feed[nowPlayingIndex]
    }
    
    var upNext: [Topic] {
        if feed.count > 0 {
            return Array(feed[(nowPlayingIndex + 1)...])
        } else {
           return []
        }
    }
    
    private let feedService = FeedService()
    
    func load() async {
        let (history, queue) = await (feedService.loadHistory(), feedService.loadQueue())
        DispatchQueue.main.async {
            self.feed = history + queue
            self.nowPlayingIndex = max(0, history.count - 1)
            self.feed.forEach(self.loadImageForTopic)
        }
        // TODO: Load audio here and internally
    }
    
    func playPause() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
            audioPlayer?.rate = Float(playbackSpeed)
        }
        isPlaying.toggle()
    }
    
    func previous() {
        nowPlayingIndex = max(0, nowPlayingIndex - 1)
    }
    
    func next() {
        nowPlayingIndex = min(feed.count - 1, nowPlayingIndex + 1)
    }
    
    func seekToTime(seconds: Double) {
        let seekTime = CMTime(seconds: seconds, preferredTimescale: 1)
        audioPlayer?.seek(to: seekTime)
        
        currentTime = seconds
        progress = seconds / duration
    }

    func seekToProgress(percentage: Double) {
        guard let duration = playerItem?.duration else { return }
        let totalSeconds = CMTimeGetSeconds(duration)
        let seekTimeSeconds = totalSeconds * percentage
        let seekTime = CMTime(seconds: seekTimeSeconds, preferredTimescale: 1)
        audioPlayer?.seek(to: seekTime)
        
        currentTime = seekTimeSeconds
        progress = percentage
    }
    
    func playNext(at id: Int) {
        if let topicIndex = feed.firstIndex(where: { $0.id == id }) {
            guard topicIndex >= 0 && topicIndex < feed.count else { return }
            let topic = feed.remove(at: topicIndex)
            feed.insert(topic, at: nowPlayingIndex + 1)
        }
    }
    
    func playLast(at id: Int) {
        if let topicIndex = feed.firstIndex(where: { $0.id == id }) {
            guard topicIndex >= 0 && topicIndex < feed.count else { return }
            let topic = feed.remove(at: topicIndex)
            feed.append(topic)
        }
    }
    
    func deleteTopic(id: Int) {
        if let topicIndex = feed.firstIndex(where: {$0.id == id}) {
            feed.remove(at: topicIndex)
            // TODO: Idk if this preserves position when deleting moves around index... test it
            nowPlayingIndex = max(0, min(nowPlayingIndex, feed.count - 1))
        }
    }
    
    deinit {
        if let token = timeObserverToken {
            audioPlayer?.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

extension FeedModel {
    private func loadImageForTopic(_ topic: Topic) {
        guard let image = topic.image, let url = URL(string: "https://bucket.wirehead.tech/\(image)") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                if let image = UIImage(data: data) {
                    self?.topicArtworks[topic.id] = Artwork(image: image)
                }
            }
        }.resume()
    }
}


extension FeedModel {
    // TODO: Make this stuff private so it's internally handled
    func loadAudio(audioKey: String) {
        // Pause existing content if playing
        let originalIsPlaying = isPlaying
        if (originalIsPlaying) {
            playPause()
            isPlaying = false
        }
        
        // Remove old observer if exists
        if let token = timeObserverToken {
            audioPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        // Load new audio from bucket
        if let audioURL = URL(string: "https://bucket.wirehead.tech/\(audioKey)") {
            let asset = AVAsset(url: audioURL)
            playerItem = AVPlayerItem(asset: asset)
            
            if (audioPlayer != nil) {
                audioPlayer?.replaceCurrentItem(with: playerItem)
            } else {
                audioPlayer = AVPlayer(playerItem: playerItem)
            }
            
            loadDuration()
            setupProgressListener()
        }
        
        // Reset progress
        currentTime = 0
        progress = 0
        
        if (originalIsPlaying) {
            playPause()
            isPlaying = true
        }
    }
    
    private func loadDuration() {
        Task {
            if let duration = try? await playerItem?.asset.load(.duration)
            {
                DispatchQueue.main.async { [weak self] in
                    if !duration.isIndefinite {
                        self?.duration = duration.seconds
                    }
                }
            }
        }
    }
    
    private func setupProgressListener() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let durationSeconds = CMTimeGetSeconds(self.playerItem?.duration ?? .zero)
            let currentSeconds = CMTimeGetSeconds(time)
            self.currentTime = currentSeconds
            self.progress = (durationSeconds > 0) ? currentSeconds / durationSeconds : 0
        }
    }
}

