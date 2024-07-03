//
//  FeedModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/20/24.
//

import SwiftUI
import AVFoundation
import MediaPlayer

class FeedModel: ObservableObject, AudioManagerDelegate {
    // Properties
    private let audioManager = AudioManager()
    private var lastViewItemUuid: String?
    private var lastViewCurrentTime: Double = 0
    private var feedService: FeedService?
    
    // Auth token for backend requests
    @Published var token: String? = UserDefaults.standard.string(forKey: "token") {
        didSet {
            guard let token else {
                // Remove token if it's being set to nil
                UserDefaults.standard.removeObject(forKey: "token")
                feedService = nil
                return
            }
            
            UserDefaults.standard.set(token, forKey: "token")
            feedService = FeedService(token: token)
        }
    }
    @Published var username: String? = UserDefaults.standard.string(forKey: "username") {
        didSet {
            guard let token else {
                UserDefaults.standard.removeObject(forKey: "username")
                return
            }
            UserDefaults.standard.set(token, forKey: "username")
        }
    }
    
    // Feed
    @Published private var feed = [Clip]()
    @Published private var nowPlayingIndex: Int = 0 {
        didSet {
            // Only reload Clip if it's now
            // Sometimes things get moved but it doesn't really change
            if nowPlaying?.id != feed[nowPlayingIndex].id {
                nowPlaying = feed[nowPlayingIndex]
                audioManager.loadAudio(audioKey: feed[nowPlayingIndex].audioBucketKey)
                
                guard let feedService else { return }
//                feedService.postView(clipId: feed[nowPlayingIndex].id, duration: 0.0)
            }
        }
    }
//    @Published private(set) var ClipArtworks = [Int: Artwork]() {
//        didSet {
//            guard let ClipId = nowPlaying?.id else { return }
//            guard let artwork = ClipArtworks[ClipId]?.image else { return }
//            NowPlayingHelper.setArtwork(artwork)
//        }
//    }
    
    // Audio player state
    @Published private(set) var isPlaying = false
    
    @Published private(set) var currentTime: TimeInterval = 0.0 {
        didSet {
            // Keep feed updated
//            nowPlaying?.currentTime = Int(currentTime)
            
            // Sync with control center
            NowPlayingHelper.setCurrentTime(currentTime)
        }
    }
    
    @Published private(set) var duration: Double = 0.0 {
        didSet {
            // Sync with control center
            NowPlayingHelper.setDuration(duration)
        }
    }
    
    @Published var playbackSpeed: Double = UserDefaults.standard.double(forKey: "playbackSpeed") {
        didSet {
            UserDefaults.standard.set(playbackSpeed, forKey: "playbackSpeed")
            audioManager.setRate(rate: isPlaying ? playbackSpeed : 0.0)
        }
    }
    
    // Feed vars the views will use
    var history: [Clip] {
        if feed.count > 0 {
            return Array(feed[..<nowPlayingIndex])
        } else {
            return []
        }
    }
    
    var nowPlaying: Clip? {
        didSet {
            // Sync with control center
            guard let Clip = nowPlaying else { return }
            NowPlayingHelper.setTitle(Clip.name)
//            guard let artwork = ClipArtworks[Clip.id]?.image else { return }
//            NowPlayingHelper.setArtwork(artwork)
            
        }
    }
    
    var progress: Double {
        currentTime / duration
    }
    
    var upNext: [Clip] {
        if feed.count > 0 {
            return Array(feed[(nowPlayingIndex + 1)...])
        } else {
           return []
        }
    }
    
    init() {
        audioManager.delegate = self
        setupNowPlayingInfo()
        if playbackSpeed == 0 { // UserDefaults returns 0 if the key does not exist
            playbackSpeed = 1.0 // Default playback speed
        }
        
        
        guard let token else { return }
        feedService = FeedService(token: token)
    }
        
    
    func load() async {
        guard let feedService else { return }
        
        let (history, queue) = await (feedService.loadHistory(), feedService.loadQueue())
        print("Loaded \((history + queue).count) total")
        DispatchQueue.main.async {
            self.feed = history + queue
            self.nowPlayingIndex = max(0, history.count - 1)
            self.feed.forEach(self.loadImageForClip)
        }
    }
    
    func logout() {
        // Stop any playing audio
        audioManager.pause()

        // Reset user-related data
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "playbackSpeed")
        token = ""

        // Clear the feed
        nowPlayingIndex = 0
        feed.removeAll()
        nowPlaying = nil

        // Clear cached artworks
//        ClipArtworks.removeAll()

        // Reset playback state
        currentTime = 0.0
        duration = 0.0
        playbackSpeed = 1.0  // Reset to default playback speed

        // Reset FeedService
        feedService = nil
    }
    
    func playPause() {
        if isPlaying {
            audioManager.pause()
        } else {
            audioManager.play()
            audioManager.setRate(rate: playbackSpeed)
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
        audioManager.seekTo(seconds: seconds)
        
        currentTime = seconds
    }

    func seekToProgress(percentage: Double) {
        let seekTime = duration * percentage
        audioManager.seekTo(seconds: seekTime)
        
        currentTime = seekTime
    }
    
    func playNext(at id: Int) {
        guard let ClipIndex = feed.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // If the Clip is already next, no need to move it
        if ClipIndex == nowPlayingIndex + 1 {
            return
        }
        
        // Remove the Clip from its current position
        let Clip = feed.remove(at: ClipIndex)

        // Adjust the nowPlayingIndex if necessary
        if ClipIndex < nowPlayingIndex {
            nowPlayingIndex -= 1
        }

        
        // Insert the Clip right after the nowPlayingIndex
        let newIndex = min(nowPlayingIndex + 1, feed.count)
        feed.insert(Clip, at: newIndex)
    }
    
    func playLast(at id: Int) {
        guard let ClipIndex = feed.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // Remove the Clip from its current position
        let Clip = feed.remove(at: ClipIndex)
        
        // Adjust the nowPlayingIndex if necessary
        if ClipIndex < nowPlayingIndex {
            nowPlayingIndex -= 1
        }
        
        // Append the Clip to the end of the feed
        feed.append(Clip)
    }
    
    func playClip(at id: Int) {
        guard let ClipIndex = feed.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // Remove the Clip from its current position
        let Clip = feed.remove(at: ClipIndex)

        // Adjust the nowPlayingIndex if necessary
        if ClipIndex < nowPlayingIndex {
            nowPlayingIndex -= 1
        }
        
        // Insert the Clip right after the nowPlayingIndex
        let newIndex = min(nowPlayingIndex + 1, feed.count)
        feed.insert(Clip, at: newIndex)
        
        // Set the Clip as playing
        nowPlayingIndex = newIndex
    }
    
    func deleteClip(id: Int) {
        if let ClipIndex = feed.firstIndex(where: { $0.id == id }) {
            guard let feedService else { return }
//            feedService.postView(uuid: feed[ClipIndex].uuid, duration: -1.0)
//            feed.remove(at: ClipIndex)
//
//            // Adjust the nowPlayingIndex if necessary
//            if nowPlayingIndex >= ClipIndex {
//                nowPlayingIndex -= 1
//            }
//
//            // Ensure nowPlayingIndex is within the valid range
//            nowPlayingIndex = max(0, min(nowPlayingIndex, feed.count - 1))
        }
    }
}

extension FeedModel {
    func playbackDidEnd() {
        if isPlaying {
            playPause()
            next()
            playPause()
        } else {
            // Probably not possible
            next()
        }
    }
    
    func currentTimeUpdated(_ currentTime: TimeInterval) {
        self.currentTime = currentTime
    }
    
    func durationLoaded(_ duration: TimeInterval) {
        self.duration = duration
    }
    
    private func setupNowPlayingInfo() {
        NowPlayingHelper.setArtist("Codec")
    }
}

extension FeedModel {
    private func loadImageForClip(_ clip: Clip) {
        print("TODO: Get url")
//        print(clip.feedItem.feed.url)
//        guard let image = Clip.image, let url = URL(string: "https://bucket.wirehead.tech/\(image)") else { return }
//        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
//            guard let data = data, error == nil else { return }
//            DispatchQueue.main.async {
//                if let image = UIImage(data: data) {
//                    self?.ClipArtworks[Clip.id] = Artwork(image: image)
//                }
//            }
//        }.resume()
    }
}

extension FeedModel {
    private func updateView() {
        guard let feedService else { return }
//        if let playingClipUuid = nowPlaying?.uuid {
//            if playingClipUuid != lastViewItemUuid {
//                // Clip change, should update
//                lastViewItemUuid = playingClipUuid
//                lastViewCurrentTime = currentTime
//                feedService.postView(uuid: playingClipUuid, duration: currentTime)
//            } else {
//                // Same Clip, update if time chaged
//                let timeDiff = abs(currentTime - lastViewCurrentTime)
//                if timeDiff > 3 {
//                    // Time changed, should update
//                    lastViewCurrentTime = currentTime
//                    feedService.postView(uuid: playingClipUuid, duration: currentTime)
//                }
//            }
//        }
    }
    
    func loadMoreClips() async {
        guard let feedService else { return }
        let newClips = await feedService.loadQueue()
        // Remove duplicates by checking for unique Clip IDs
        // NOTE: Shouldn't have duplicates, but just in case
        let existingClipIds = Set(feed.map { $0.id })
        let filteredNewClips = newClips.filter { !existingClipIds.contains($0.id) }
        // Append the filtered new Clips to the feed
        feed.append(contentsOf: filteredNewClips)
        filteredNewClips.forEach(loadImageForClip)
    }
}
