//
//  FeedModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/20/24.
//

import SwiftUI
import AVFoundation
import MediaPlayer

@MainActor
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
            guard let username else {
                UserDefaults.standard.removeObject(forKey: "username")
                return
            }
            UserDefaults.standard.set(username, forKey: "username")
        }
    }
    
    // Feed
    @Published private var feed = [Clip]()
    @Published var interestedTopics: [Topic] = []
    @Published var followedFeeds: [UserFeedFollow] = []
    @Published private var nowPlayingIndex: Int = 0 {
        didSet {
            // Only reload Clip if it's now
            // Sometimes things get moved but it doesn't really change
            if nowPlaying?.id != feed[nowPlayingIndex].id {
                nowPlaying = feed[nowPlayingIndex]
                audioManager.loadAudio(audioKey: feed[nowPlayingIndex].audioBucketKey)
                
//                guard let feedService else { return }
//                feedService.postView(clipId: feed[nowPlayingIndex].id, duration: 0.0)
            }
        }
    }
    @Published private(set) var feedArtworks = [Int: Artwork]() {
        didSet {
            guard let feedId = nowPlaying?.feedItem.feed.id else { return }
            guard let artwork = feedArtworks[feedId]?.image else { return }
            NowPlayingHelper.setArtwork(artwork)
        }
    }
    private let session: URLSession // for caching image requests
    
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
//            guard let artwork = clipArtworks[Clip.id]?.image else { return }
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
    
    // Search related state
    @Published var searchResults: [Feed] = []
    @Published var isSearching = false
    
    init() {
        let cache = URLCache(memoryCapacity: 10 * 1024 * 1024,  // 10 MB memory cache
                             diskCapacity: 100 * 1024 * 1024,   // 100 MB disk cache
                             diskPath: "imageCache")

        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
        
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
        
        async let historyTask = feedService.loadHistory()
        async let queueTask = feedService.loadQueue()
        async let topicsTask = feedService.loadTopics()
        async let followedShowsTask = feedService.loadFollowedShows()
        
        let (history, queue, topics, followedShows) = await (historyTask, queueTask, topicsTask, followedShowsTask)
        
        print("Loaded \((history + queue).count) total clips")
        print("Loaded \(topics.count) topics")
        print("Loaded \(followedShows.count) followed shows")
        
        DispatchQueue.main.async {
            self.feed = history + queue
            self.nowPlayingIndex = max(0, history.count - 1)
            let uniqueFeeds = Set(self.feed.map { $0.feedItem.feed })
            uniqueFeeds.forEach(self.loadFeedArtwork)
            self.interestedTopics = topics
            self.followedFeeds = followedShows
            (self.followedFeeds.map { $0.feed }).forEach(self.loadFeedArtwork)
        }
    }
    
    func loadProfileData() async {
        guard let feedService else { return }
        async let topicsTask = feedService.loadTopics()
        async let followedShowsTask = feedService.loadFollowedShows()
        
        let (topics, followedShows) = await (topicsTask, followedShowsTask)
        print("Loaded \(topics.count) topics")
        print("Loaded \(followedShows.count) followed shows")
        
        DispatchQueue.main.async {
            self.interestedTopics = topics
            self.followedFeeds = followedShows
            (self.followedFeeds.map { $0.feed }).forEach(self.loadFeedArtwork)
        }
    }
    
    func logout() {
        // Stop any playing audio
        audioManager.pause()

        // Reset user-related data
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "playbackSpeed")
        token = nil
        username = nil

        // Clear the feed
        nowPlayingIndex = 0
        feed.removeAll()
        nowPlaying = nil

        // Clear cached artworks
        feedArtworks.removeAll()

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
    private func loadFeedArtwork(_ feed: Feed) {
        // Check if clip is already in the dict
        if (self.feedArtworks.keys.contains(where: { feedId in
            feedId == feed.id
        })) {
            return
        }
        
        guard let feedURL = URL(string: feed.url) else {
            print("Invalid feed URL")
            return
        }
        
        let task = session.dataTask(with: feedURL) { [weak self] data, response, error in
            if let error = error {
                print("Error fetching RSS feed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received from RSS feed")
                return
            }
            
            let parser = XMLParser(data: data)
            let delegate = RSSParserDelegate()
            parser.delegate = delegate
            
            if parser.parse(), let imageURLString = delegate.channelImageURL, let imageURL = URL(string: imageURLString) {
                self?.downloadImage(from: imageURL, for: feed)
            } else {
                print("No image URL found or failed to parse RSS feed for feed \(feed.id)")
            }
        }
        task.resume()
    }
        
    private func downloadImage(from url: URL, for feed: Feed) {
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("Error downloading image for feed \(feed.id): \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.feedArtworks[feed.id] = Artwork(image: image)
                }
            } else {
                print("Failed to create image from data for feed \(feed.id)")
            }
        }
        task.resume()
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
    
    func setInterested(for topicId: Int, isInterested: Bool) async {
        if let index = interestedTopics.firstIndex(where: { $0.id == topicId }) {
            interestedTopics[index].isInterested = isInterested
            // Post the change to the backend if needed
            await feedService?.setTopicInterest(topicId: topicId, isInterested: isInterested)
        }
    }
    
    func addNewTopic(text: String, isInterested: Bool) async {
        let newTopic = Topic(id: UUID().hashValue, text: text, isInterested: isInterested)
        interestedTopics.append(newTopic)
        let success = await feedService?.addTopic(text: text, isInterested: isInterested) ?? false
        if !success {
            // Handle the failure case, e.g., remove the topic from the list or show an error
            if let index = interestedTopics.firstIndex(where: { $0.id == newTopic.id }) {
                interestedTopics.remove(at: index)
            }
        }
    }
    
    func deleteTopic(id: Int) async {
        guard let feedService = feedService else { return }
        
        let success = await feedService.deleteTopic(id: id)
        if success {
            DispatchQueue.main.async {
                self.interestedTopics.removeAll { $0.id == id }
            }
        }
    }
    
    func searchShows(query: String) async {
        isSearching = true
        defer { isSearching = false }

        guard let feedService = feedService else { return }
        let allResults = await feedService.searchShows(query: query)
        let followedFeedIds = Set(followedFeeds.map { $0.feed.id })
        searchResults = allResults.filter { !followedFeedIds.contains($0.id) }
    }

    func followShow(feed: Feed) async -> Bool {
        guard let feedService = feedService else { return false }
        let success = await feedService.followShow(feedId: feed.id)
        if success {
            await loadProfileData()
        }
        return success
    }
    
    func unfollowShow(followId: Int) async {
        guard let feedService = feedService else { return }
        
        let success = await feedService.unfollowShow(followId: followId)
        if success {
            DispatchQueue.main.async {
                self.followedFeeds.removeAll { $0.id == followId }
            }
        }
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
        let uniqueFeeds = Set(filteredNewClips.map { $0.feedItem.feed })
        uniqueFeeds.forEach(self.loadFeedArtwork)
    }
}
