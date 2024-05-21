//
//  FeedModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/20/24.
//

import SwiftUI
import AVFoundation

class FeedModel: ObservableObject {
    // Managing audio libraries
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    
    // View tracking
    private var lastViewItemUuid: String?
    private var lastViewCurrentTime: Double = 0
    
    // Feed
    @Published private var feed = [Topic]()
    @Published private var nowPlayingIndex: Int = 0 {
        didSet {
            // Load new audio file on change
            self.loadAudio(audioKey: feed[nowPlayingIndex].audio)
            self.feedService.postView(uuid: feed[nowPlayingIndex].uuid, duration: 0.0)
        }
    }
    @Published private(set) var topicArtworks = [Int: Artwork]()
    
    // Audio player state
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentTime: TimeInterval = 0.0 {
        didSet {
            nowPlaying?.currentTime = Int(currentTime)
        }
    }
    @Published private(set) var duration: TimeInterval = 0.0
    @Published var playbackSpeed: Double = 1.0 {
        didSet {
            audioPlayer?.rate = isPlaying ? Float(playbackSpeed) : 0.0
        }
    }
    
    // Feed vars the views will use
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
            feedService.postView(uuid: feed[topicIndex].uuid, duration: -1.0)
            feed.remove(at: topicIndex)
            if nowPlayingIndex > topicIndex {
                nowPlayingIndex -= 1
            }
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
    private func loadAudio(audioKey: String) {
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
        
        // Remove any old end of play observers
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)

        // Load new audio from bucket
        if let audioURL = URL(string: "https://bucket.wirehead.tech/\(audioKey)") {
            let asset = AVAsset(url: audioURL)
            playerItem = AVPlayerItem(asset: asset)
            
            if (audioPlayer != nil) {
                audioPlayer?.replaceCurrentItem(with: playerItem)
            } else {
                audioPlayer = AVPlayer(playerItem: playerItem)
            }
            
            // Add completion observer
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerItemDidReachEnd(notification:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
            
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
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.feedService.postView(uuid: self.nowPlaying!.uuid, duration: duration)
            self.next()
        }
    }

    private func loadDuration() {
        Task {
            if let duration = try? await playerItem?.asset.load(.duration) {
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
            self.updateView()
        }
    }
}

extension FeedModel {
    private func updateView() {
        if let playingTopicUuid = nowPlaying?.uuid {
            if playingTopicUuid != lastViewItemUuid {
                // Topic change, should update
//                print("\(nowPlaying?.title ?? ""): \(currentTime)")
                lastViewItemUuid = playingTopicUuid
                lastViewCurrentTime = currentTime
                feedService.postView(uuid: playingTopicUuid, duration: currentTime)
            } else {
                // Same topic, update if time chaged
                let timeDiff = abs(currentTime - lastViewCurrentTime)
                if timeDiff > 3 {
                    // Time changed, should update
//                    print("\(nowPlaying?.title ?? ""): \(currentTime)")
                    lastViewCurrentTime = currentTime
                    feedService.postView(uuid: playingTopicUuid, duration: currentTime)
                }
            }
        }
    }
    
    func loadMoreTopics() async {
        let newTopics = await feedService.loadQueue()
        // Remove duplicates by checking for unique topic IDs
        // NOTE: Shouldn't have duplicates, but just in case
        let existingTopicIds = Set(feed.map { $0.id })
        let filteredNewTopics = newTopics.filter { !existingTopicIds.contains($0.id) }
        // Append the filtered new topics to the feed
        feed.append(contentsOf: filteredNewTopics)
        filteredNewTopics.forEach(loadImageForTopic)
    }
}
