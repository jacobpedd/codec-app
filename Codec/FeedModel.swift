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

    // MARK: - Published properties
    @Published var token: String? {
        didSet { updateFeedService() }
    }
    @Published var username: String?
    @Published private(set) var feed = [Clip]()
    @Published var interestedTopics: [Topic] = []
    @Published var followedFeeds: [UserFeedFollow] = []
    @Published var nowPlayingIndex: Int = 0 {
            didSet {
                updateNowPlaying(to: nowPlayingIndex)
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
    var history: [Clip] { Array(feed[..<nowPlayingIndex]) }
    var upNext: [Clip] { Array(feed[(nowPlayingIndex + 1)...]) }

    // MARK: - Initialization
    init() {
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
        
        let (history, queue) = await (historyTask, queueTask)
        
        let historyClips = history.map { $0.clip }
        print("Loaded \((historyClips + queue).count) clip")
        
        DispatchQueue.main.async {
            self.feed = historyClips + queue
            self.nowPlayingIndex = max(0, history.count - 1)
            let uniqueFeeds = Set(self.feed.map { $0.feedItem.feed })
            self.loadArtworkForFeeds(Array(uniqueFeeds))
            self.loadArtworkForFeeds(self.followedFeeds.map { $0.feed })
        }
    }

    func loadProfileData() async {
        guard let feedService = feedService else { return }
        async let topicsTask = feedService.loadTopics()
        async let followedShowsTask = feedService.loadFollowedShows()
        
        let (topics, followedShows) = await (topicsTask, followedShowsTask)
        print("Loaded profile with \(topics.count) topics and \(followedShows.count) followed shows")
        
        DispatchQueue.main.async {
            self.interestedTopics = topics
            self.followedFeeds = followedShows
            self.loadArtworkForFeeds(self.followedFeeds.map { $0.feed })
        }
    }

    func logout() {
        audioManager.pause()
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "playbackSpeed")
        token = nil
        username = nil
        nowPlayingIndex = 0
        feed.removeAll()
        nowPlaying = nil
        feedArtworks.removeAll()
        currentTime = 0.0
        duration = 0.0
        playbackSpeed = 1.0
        feedService = nil
    }

    func playPause() {
        if isPlaying {
            audioManager.pause()
            viewTracker.stopTracking()
        } else {
            audioManager.play()
            viewTracker.startTracking(clip: nowPlaying,
                                      currentTimePublisher: $currentTime,
                                      durationPublisher: $duration)
        }
        isPlaying.toggle()
    }

    private func updateNowPlaying(to index: Int) {
        guard index >= 0 && index < feed.count else { return }
        
        if (feed.count - index < 5) {
            Task {
                await loadMoreClips()
            }
        }
        
        viewTracker.stopTracking()
        
        if nowPlaying?.id != feed[index].id {
            nowPlaying = feed[index]
            audioManager.loadAudio(audioKey: feed[index].audioBucketKey)
        }
        
        if isPlaying {
            viewTracker.startTracking(clip: nowPlaying,
                                      currentTimePublisher: $currentTime,
                                      durationPublisher: $duration)
            audioManager.play()
        }
    }

    // Add this new method to set nowPlayingIndex safely
    func setNowPlayingIndex(_ index: Int) {
        guard index >= 0 && index < feed.count else { return }
        nowPlayingIndex = index
    }

    // Update these methods to use setNowPlayingIndex
    func next() {
        setNowPlayingIndex(min(feed.count - 1, nowPlayingIndex + 1))
    }

    func previous() {
        setNowPlayingIndex(max(0, nowPlayingIndex - 1))
    }

    // Update this method to use setNowPlayingIndex
    func deleteClip(id: Int) {
        if let clipIndex = feed.firstIndex(where: { $0.id == id }) {
            viewTracker.stopTracking()
            Task {
                await feedService?.updateView(clipId: id, duration: 0)
            }
            feed.remove(at: clipIndex)
            
            if nowPlayingIndex >= clipIndex {
                setNowPlayingIndex(max(0, nowPlayingIndex - 1))
            }
        }
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
            feedService = nil
            return
        }
        UserDefaults.standard.set(token, forKey: "token")
        feedService = FeedService(token: token)
        viewTracker.setFeedService(feedService)
    }

    private func initializePlaybackSpeed() {
        if playbackSpeed == 0 {
            playbackSpeed = 1.0
        }
    }

    private func setupNowPlayingInfo() {
        NowPlayingHelper.setArtist("Codec")
    }
}

// MARK: - AudioManagerDelegate
extension FeedModel: AudioManagerDelegate {
    func playbackDidEnd() {
        Task {
            guard let clipId = nowPlaying?.id else { return }
            await feedService?.updateView(clipId: clipId, duration: 100)
        }
        if isPlaying {
            playPause()
            next()
            playPause()
        } else {
            next()
        }
    }
    
    func currentTimeUpdated(_ currentTime: TimeInterval) {
        self.currentTime = currentTime
    }
    
    func durationLoaded(_ duration: TimeInterval) {
        self.duration = duration
    }
}

// MARK: - Feed Management
extension FeedModel {
    func playNext(at id: Int) {
        guard let clipIndex = feed.firstIndex(where: { $0.id == id }) else { return }
        if clipIndex == nowPlayingIndex + 1 { return }
        let clip = feed.remove(at: clipIndex)
        if clipIndex < nowPlayingIndex { nowPlayingIndex -= 1 }
        let newIndex = min(nowPlayingIndex + 1, feed.count)
        feed.insert(clip, at: newIndex)
    }
    
    func playLast(at id: Int) {
        guard let clipIndex = feed.firstIndex(where: { $0.id == id }) else { return }
        let clip = feed.remove(at: clipIndex)
        if clipIndex < nowPlayingIndex { nowPlayingIndex -= 1 }
        feed.append(clip)
    }
}

// MARK: - Topic Management
extension FeedModel {
    func setInterested(for topicId: Int, isInterested: Bool) async {
        if let index = interestedTopics.firstIndex(where: { $0.id == topicId }) {
            interestedTopics[index].isInterested = isInterested
            await feedService?.setTopicInterest(topicId: topicId, isInterested: isInterested)
        }
    }
    
    func addNewTopic(text: String, isInterested: Bool) async {
        let newTopic = Topic(id: UUID().hashValue, text: text, isInterested: isInterested)
        interestedTopics.append(newTopic)
        let success = await feedService?.addTopic(text: text, isInterested: isInterested) ?? false
        if !success {
            interestedTopics.removeAll { $0.id == newTopic.id }
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
