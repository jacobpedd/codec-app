//
//  FeedModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/20/24.
//

import SwiftUI
import AVFoundation
import MediaPlayer

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
            // Only reload topic if it's now
            // Sometimes things get moved but it doesn't really change
            if nowPlaying?.id != feed[nowPlayingIndex].id {
                nowPlaying = feed[nowPlayingIndex]
                self.loadAudio(audioKey: feed[nowPlayingIndex].audio)
                self.feedService.postView(uuid: feed[nowPlayingIndex].uuid, duration: 0.0)
            }
        }
    }
    @Published private(set) var topicArtworks = [Int: Artwork]() {
        didSet {
            updateNowPlayingInfo()
        }
    }
    
    // Audio player state
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentTime: TimeInterval = 0.0 {
        didSet {
            // Keep feed updated
            nowPlaying?.currentTime = Int(currentTime)
            
            // Sync with control center
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        }
    }
    @Published private(set) var duration: TimeInterval = 0.0 {
        didSet {
            // Sync with control center
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = duration
        }
    }
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
    
    var nowPlaying: Topic?
    
    var upNext: [Topic] {
        if feed.count > 0 {
            return Array(feed[(nowPlayingIndex + 1)...])
        } else {
           return []
        }
    }
    
    private let feedService = FeedService()
    
    func load() async {
        setupPlayBack()
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
        guard let topicIndex = feed.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // If the topic is already next, no need to move it
        if topicIndex == nowPlayingIndex + 1 {
            return
        }
        
        // Remove the topic from its current position
        let topic = feed.remove(at: topicIndex)

        // Adjust the nowPlayingIndex if necessary
        if topicIndex < nowPlayingIndex {
            nowPlayingIndex -= 1
        }

        
        // Insert the topic right after the nowPlayingIndex
        let newIndex = min(nowPlayingIndex + 1, feed.count)
        feed.insert(topic, at: newIndex)
    }
    
    func playLast(at id: Int) {
        guard let topicIndex = feed.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // Remove the topic from its current position
        let topic = feed.remove(at: topicIndex)
        
        // Adjust the nowPlayingIndex if necessary
        if topicIndex < nowPlayingIndex {
            nowPlayingIndex -= 1
        }
        
        // Append the topic to the end of the feed
        feed.append(topic)
    }
    
    func deleteTopic(id: Int) {
        if let topicIndex = feed.firstIndex(where: { $0.id == id }) {
            feedService.postView(uuid: feed[topicIndex].uuid, duration: -1.0)
            feed.remove(at: topicIndex)

            // Adjust the nowPlayingIndex if necessary
            if nowPlayingIndex >= topicIndex {
                nowPlayingIndex -= 1
            }

            // Ensure nowPlayingIndex is within the valid range
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
            updateNowPlayingInfo()
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
            self.feedService.postView(uuid: self.nowPlaying!.uuid, duration: self.duration)
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
    private func setupPlayBack() {
        configureAudioSession()
        setupControlCenterControls()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Configure the app for playback of long-form TTS.
            try session.setCategory(.playback)
            try session.setActive(true)
            
            // Add interruption observer
            NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: session)
            
            // Add route change observer (e.g., headphones plugged/unplugged)
            NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: session)
        } catch let error as NSError {
            print("Setting category to AVAudioSessionCategoryPlayback failed: \(error)")
        }
    }
    
    private func setupControlCenterControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()

        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            print("Play command - is playing: \(self.isPlaying)")
            if !self.isPlaying {
                self.playPause()
                return .success
            }
            return .commandFailed
        }

        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            print("Pause command - is playing: \(self.isPlaying)")
            if self.isPlaying {
                self.playPause()
                return .success
            }
            return .commandFailed
        }

        // Add handler for Next Command
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            print("Next command")
            self.next()
            return .success
        }

        // Add handler for Previous Command
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            print("Previous command")
            self.previous()
            return .success
        }

        // Add handler for Seek Command
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            print("Seek command - position: \(event.positionTime)")
            self.seekToTime(seconds: event.positionTime)
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
                
        if let nowPlaying = nowPlaying {
            nowPlayingInfo[MPMediaItemPropertyTitle] = nowPlaying.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = "Codec"
            
            if let artwork = topicArtworks[nowPlaying.id]?.image {
                let artwork = MPMediaItemArtwork(boundsSize: artwork.size) { size in
                    return artwork
                }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .began {
            // Interruption began, pause playback
            if isPlaying {
                playPause()
            }
        } else if type == .ended {
            // Interruption ended, resume playback if needed
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Resume playback if appropriate
                if !isPlaying {
                    playPause()
                }
            }
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
            case .oldDeviceUnavailable:
                // Headphones unplugged, pause playback
                if isPlaying {
                    playPause()
                }
            default: break
        }
    }
}

extension FeedModel {
    private func updateView() {
        if let playingTopicUuid = nowPlaying?.uuid {
            if playingTopicUuid != lastViewItemUuid {
                // Topic change, should update
                lastViewItemUuid = playingTopicUuid
                lastViewCurrentTime = currentTime
                feedService.postView(uuid: playingTopicUuid, duration: currentTime)
            } else {
                // Same topic, update if time chaged
                let timeDiff = abs(currentTime - lastViewCurrentTime)
                if timeDiff > 3 {
                    // Time changed, should update
                    lastViewCurrentTime = currentTime
                    feedService.postView(uuid: playingTopicUuid, duration: currentTime)
                }
            }
        }
    }
    
    // TODO: Make this private and call when upnext gets small
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
