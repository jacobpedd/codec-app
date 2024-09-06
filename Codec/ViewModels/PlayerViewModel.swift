//
//  PlayerViewModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/21/24.
//

import SwiftUI

@MainActor
class PlayerViewModel: ObservableObject {
    private let audioManager: AudioManager
    private let viewTracker: ViewTracker
    var feedVM: FeedViewModel?
    var artworkVM: ArtworkViewModel?
    var feedService: FeedService? {
        didSet {
            viewTracker.setFeedService(feedService)
        }
    }
    
    @Published var nowPlaying: Clip? {
        didSet {
            guard let clip = nowPlaying else { return }
            viewTracker.setCurrentClip(clip, currentTimePublisher: $currentTime, durationPublisher: $duration)
            NowPlayingHelper.setTitle(clip.name)
            artworkVM?.loadArtwork(for: clip.feedItem.feed) { artwork in
                if let image = artwork?.image {
                    NowPlayingHelper.setArtwork(image)
                }
            }
        }
    }
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0.0 {
        didSet { NowPlayingHelper.setCurrentTime(currentTime) }
    }
    @Published var duration: Double = 0.0 {
        didSet { NowPlayingHelper.setDuration(duration) }
    }
    @Published var playbackSpeed: Double {
        didSet {
            UserDefaults.standard.set(playbackSpeed, forKey: "playbackSpeed")
            if isPlaying {
                audioManager.setRate(rate: playbackSpeed)
            }
        }
    }
    var progress: Double {
        duration == 0 ? 1 : currentTime / duration
    }
    
    init() {
        let savedSpeed = UserDefaults.standard.double(forKey: "playbackSpeed")
        self.playbackSpeed = savedSpeed > 0 ? savedSpeed : 1.0
        self.viewTracker = ViewTracker()
        self.audioManager = AudioManager()
        self.audioManager.delegate = self
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
    
    func seekToTime(seconds: Double) {
        audioManager.seekTo(seconds: seconds)
        currentTime = seconds
    }
    
    func seekToProgress(percentage: Double) {
        let seekTime = duration * percentage
        seekToTime(seconds: seekTime)
    }
    
    func next() {
        guard let feedVM else { return }
        feedVM.moveToNextClip()
        updateNowPlaying()
    }
    
    func previous() {
        guard let feedVM else { return }
        feedVM.moveToPreviousClip()
        updateNowPlaying()
    }
    
    func setIndex(index: Int) {
        guard let feedVM else { return }
        guard index < feedVM.currentFeed.count - 1 && index >= 0 else { return }
        feedVM.moveToIndex(index: index)
        updateNowPlaying()
    }
    
    func updateNowPlaying() {
        guard let feedVM, let clip = feedVM.nowPlayingClip else { return }
        print("Now playing: \(clip.name)")
        nowPlaying = clip
        currentTime = 0.0
        
        let wasPlaying = isPlaying
        if wasPlaying {
            playPause()
        }
        audioManager.loadAudio(audioKey: clip.audioBucketKey)
        if wasPlaying {
            playPause()
        }
    }
    
    func clearPlayer() {
        if isPlaying {
            playPause()
        }
        currentTime = 0.0
        duration = 0.0
        viewTracker.stopTracking()
    }
}

extension PlayerViewModel: AudioManagerDelegate {
    func bufferingStateChanged(_ isBuffering: Bool) {
        // TODO: Show buffering state in UI
        return
    }
    
    func playbackDidEnd() {
        next()
    }
    
    func currentTimeUpdated(_ currentTime: TimeInterval) {
        self.currentTime = currentTime
    }
    
    func durationLoaded(_ duration: TimeInterval) {
        self.duration = duration
    }
}
