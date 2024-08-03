import SwiftUI
import AVFoundation
import MediaPlayer

@MainActor
class FeedModel: ObservableObject {
    // MARK: - Properties
    private let audioManager = AudioManager()
    private(set) var feedService: FeedService?
    private let session: URLSession
    private let viewTracker: ViewTracker
    private let artworkLoader: ArtworkLoader
    private let debug: Bool

    // MARK: - Published properties
    @Published var token: String? {
        didSet { updateFeedService() }
    }
    @Published var username: String?
    @Published private(set) var feed = [Clip]()
    @Published var followedFeeds: [UserFeedFollow] = []
    @Published var nowPlayingIndex: Int? {
        didSet {
            if let index = nowPlayingIndex {
                updateNowPlaying(to: index)
            } else {
                nowPlaying = nil
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
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0.0 {
        didSet { NowPlayingHelper.setCurrentTime(currentTime) }
    }
    @Published private(set) var duration: Double = 0.0 {
        didSet { NowPlayingHelper.setDuration(duration) }
    }
    @Published var playbackSpeed: Double {
        didSet {
            UserDefaults.standard.set(playbackSpeed, forKey: "playbackSpeed")
            audioManager.setRate(rate: isPlaying ? playbackSpeed : 0.0)
        }
    }
    @Published var searchResults: [Feed] = []
    @Published var isSearching = false
    @Published private(set) var isLoading = false
    @Published var needsOnboarding = false

    // MARK: - Computed properties
    var nowPlaying: Clip? {
        didSet {
            guard let clip = nowPlaying else { return }
            NowPlayingHelper.setTitle(clip.name)
            guard let artwork = feedArtworks[clip.feedItem.feed.id]?.image else { return }
            NowPlayingHelper.setArtwork(artwork)
        }
    }
    var progress: Double { currentTime / duration }
    var history: [Clip] {
        guard let index = nowPlayingIndex else { return [] }
        return Array(feed[..<index])
    }
    var upNext: [Clip] {
        guard let index = nowPlayingIndex else { return feed }
        return index + 1 < feed.count ? Array(feed[(index + 1)...]) : []
    }

    // MARK: - Initialization
    init(debug: Bool = false) {
        let cache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: "imageCache")
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
        
        self.viewTracker = ViewTracker()
        self.artworkLoader = ArtworkLoader(session: session)
        self.token = UserDefaults.standard.string(forKey: "token")
        self.username = UserDefaults.standard.string(forKey: "username")
        self.playbackSpeed = UserDefaults.standard.double(forKey: "playbackSpeed")
        self.debug = debug
        
        setupAudioManager()
        setupNowPlayingInfo()
        initializePlaybackSpeed()
        updateFeedService()
    }

    // MARK: - Public methods
    func load() async {
        guard let feedService = feedService else { return }
        
        async let historyTask = feedService.loadHistory()
        async let queueTask = feedService.loadQueue()
        async let followedTask = feedService.loadFollowedShows()
        
        let (history, queue, followedFeeds) = await (historyTask, queueTask, followedTask)
        
        let historyClips = history.map { $0.clip }
        print("Loaded \((historyClips + queue).count) clip")
        
        DispatchQueue.main.async {
            self.needsOnboarding = queue.isEmpty
            self.feed = historyClips + queue
            self.followedFeeds = followedFeeds
            self.nowPlayingIndex = max(0, history.count - 1)
            let uniqueFeeds = Set(self.feed.map { $0.feedItem.feed })
            self.loadArtworkForFeeds(Array(uniqueFeeds))
            self.loadArtworkForFeeds(self.followedFeeds.map { $0.feed })
        }
    }

    func logout() {
        // Stop any ongoing audio playback
        audioManager.pause()
        viewTracker.stopTracking()
        
        // Clear user defaults
        UserDefaults.standard.removeObject(forKey: "token")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "playbackSpeed")
        
        // Reset all properties on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("Self is nil in async block")
                return
            }
            
            self.token = nil
            self.username = nil
            self.feedArtworks.removeAll()
            self.nowPlaying = nil
            self.currentTime = 0.0
            self.duration = 0.0
            self.playbackSpeed = 1.0
            self.isPlaying = false
            self.isSearching = false
            self.isLoading = false
            
            self.followedFeeds.removeAll()
            self.searchResults.removeAll()
            self.feedService = nil
            
            // UI crashes if these aren't delayed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.nowPlayingIndex = nil
                self.feed.removeAll()
            }
        }
    }

    func playPause() {
        if isPlaying {
            audioManager.pause()
            viewTracker.stopTracking()
        } else {
            audioManager.play()
            audioManager.setRate(rate: playbackSpeed)
            viewTracker.startTracking()
        }
        isPlaying.toggle()
    }

    private func updateNowPlaying(to index: Int) {
        guard index >= 0 && index < feed.count else {
            nowPlaying = nil
            return
        }
        
        // Check if we need to load more clips into the queue
        if (feed.count - index < 5) {
            Task {
                await loadMoreClips()
            }
        }
        
        var wasPlaying = false
        if isPlaying {
            wasPlaying = true
            playPause()
        }
        
        if nowPlaying?.id != feed[index].id {
            nowPlaying = feed[index]
            currentTime = 0.0
            audioManager.loadAudio(audioKey: feed[index].audioBucketKey)
            viewTracker.setCurrentClip(feed[index], currentTimePublisher: $currentTime, durationPublisher: $duration)

            
            // Pre-load next 3 clips and previous 1 clip
            let preloadRange = max(0, index - 1)...min(feed.count - 1, index + 3)
            let preloadKeys = preloadRange.map { feed[$0].audioBucketKey }
            audioManager.preloadAudio(audioKeys: preloadKeys)
        }
        
        if wasPlaying {
            // Resume play because we paused it above
            playPause()
        }
    }

    func setNowPlayingIndex(_ index: Int?) {
        nowPlayingIndex = index
    }

    func next() {
        guard let nowPlayingIndex, !feed.isEmpty else { return }
        setNowPlayingIndex(min(feed.count - 1, nowPlayingIndex + 1))
    }

    func previous() {
        guard let nowPlayingIndex, !feed.isEmpty else { return }
        setNowPlayingIndex(max(0, nowPlayingIndex - 1))
    }

    func seekToTime(seconds: Double) {
        audioManager.seekTo(seconds: seconds)
        currentTime = seconds
    }

    func seekToProgress(percentage: Double) {
        let seekTime = duration * percentage
        seekToTime(seconds: seekTime)
    }

    // MARK: - Private methods
    private func setupAudioManager() {
        audioManager.delegate = self
    }

    private func updateFeedService() {
        guard let token = token else {
            UserDefaults.standard.removeObject(forKey: "token")
            UserDefaults.standard.removeObject(forKey: "username")
            feedService = nil
            return
        }
        UserDefaults.standard.set(token, forKey: "token")
        UserDefaults.standard.set(username, forKey: "username")
        feedService = FeedService(token: token, debug: self.debug)
        viewTracker.setFeedService(feedService)
    }

    private func initializePlaybackSpeed() {
        self.playbackSpeed = UserDefaults.standard.double(forKey: "playbackSpeed")
        if self.playbackSpeed == 0 {
           self.playbackSpeed = 1.0 // Default to 1.0 if not set
        }
    }

    private func setupNowPlayingInfo() {
        NowPlayingHelper.setArtist("Codec")
    }
}

// MARK: - AudioManagerDelegate
extension FeedModel: AudioManagerDelegate {
    func playbackDidEnd() {
        guard let clipId = nowPlaying?.id else { return }
        Task {
            await feedService?.updateView(clipId: clipId, duration: 100)
        }
        next()
    }
    
    func currentTimeUpdated(_ currentTime: TimeInterval) {
        self.currentTime = currentTime
    }
    
    func durationLoaded(_ duration: TimeInterval) {
        self.duration = duration
    }
}

// MARK: - Show Management
extension FeedModel {
    func searchShows(query: String) async {
        isSearching = true
        defer { isSearching = false }

        guard let feedService = feedService else { return }
        let allResults = await feedService.searchShows(query: query)
        let followedFeedIds = Set(followedFeeds.map { $0.feed.id })
        searchResults = allResults.filter { !followedFeedIds.contains($0.id) }
    }

    func followShow(feed: Feed, isInterested: Bool = true) async -> Bool {
        guard let feedService = feedService else { return false }
        let success = await feedService.followShow(feedId: feed.id, isInterested: isInterested)
        print("Success following show \(success)")
        if success {
            let followedFeeds = await feedService.loadFollowedShows()
            DispatchQueue.main.async {
                self.followedFeeds = followedFeeds
                self.loadArtworkForFeeds(self.followedFeeds.map { $0.feed })
            }
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
        guard let feedService = feedService, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        // Collect all clip IDs in history, now playing, and up next
        let historyClipIds = history.map { $0.id }
        let nowPlayingClipId = nowPlaying?.id ?? nil
        let upNextClipIds = upNext.map { $0.id }
        var excludeClipIds = historyClipIds + upNextClipIds
        if let clipId = nowPlayingClipId {
            excludeClipIds += [clipId]
        }
        
        let newClips = await feedService.loadQueue(excludeClipIds: excludeClipIds)
        let existingClipIds = Set(feed.map { $0.id })
        let filteredNewClips = newClips.filter { !existingClipIds.contains($0.id) }
        
        DispatchQueue.main.async {
            self.feed.append(contentsOf: filteredNewClips)
            let uniqueFeeds = Set(filteredNewClips.map { $0.feedItem.feed })
            self.loadArtworkForFeeds(Array(uniqueFeeds))
        }
    }
}

// MARK: - Artwork Loading
extension FeedModel {
    func loadArtworkForFeed(_ feed: Feed) {
        artworkLoader.loadFeedArtwork(for: feed) { [weak self] artwork in
            DispatchQueue.main.async {
                if let artwork = artwork {
                    self?.feedArtworks[feed.id] = artwork
                }
            }
        }
    }

    func loadArtworkForFeeds(_ feeds: [Feed]) {
        for feed in feeds {
            loadArtworkForFeed(feed)
        }
    }
}
