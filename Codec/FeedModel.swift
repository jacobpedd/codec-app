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
    private let feedService = FeedService()
    
    // Feed
    @Published private var feed = [Topic]()
    @Published private var nowPlayingIndex: Int = 0 {
        didSet {
            // Only reload topic if it's now
            // Sometimes things get moved but it doesn't really change
            if nowPlaying?.id != feed[nowPlayingIndex].id {
                nowPlaying = feed[nowPlayingIndex]
                audioManager.loadAudio(audioKey: feed[nowPlayingIndex].audio)
                feedService.postView(uuid: feed[nowPlayingIndex].uuid, duration: 0.0)
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
    @Published private(set) var currentTime: TimeInterval = 0.0 {
        didSet {
            // Keep feed updated
            nowPlaying?.currentTime = Int(currentTime)
            
            // Sync with control center
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        }
    }
    @Published private(set) var duration: Double = 0.0 {
        didSet {
            // Sync with control center
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = duration
        }
    }
    @Published var playbackSpeed: Double = 1.0 {
        didSet {
            audioManager.setRate(rate: isPlaying ? playbackSpeed : 0.0)
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
    
    var progress: Double {
        currentTime / duration
    }
    
    var upNext: [Topic] {
        if feed.count > 0 {
            return Array(feed[(nowPlayingIndex + 1)...])
        } else {
           return []
        }
    }
    
    init() {
        audioManager.delegate = self
    }
        
    
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
}

extension FeedModel {
    func playbackDidEnd() {
        next()
    }
    
    func currentTimeUpdated(_ timeElapsed: TimeInterval) {
        currentTime = timeElapsed
    }
    
    func durationLoaded(_ duration: TimeInterval) {
        self.duration = duration
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
