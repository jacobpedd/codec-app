//
//  AudioPlayerModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/9/24.
//

import AVFoundation

class AudioPlayerModel: ObservableObject {
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?

    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0

    func setupPlayer(audioKey: String) {
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
    }

    func loadAudio(audioKey: String, shouldPlay: Bool = false) {
        // Pause existing content if playing
        if (isPlaying) {
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
        
        if (shouldPlay) {
            playPause()
            isPlaying = true
        }
    }

    deinit {
        if let token = timeObserverToken {
            audioPlayer?.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
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

    func playPause() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        isPlaying.toggle()
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

    func seekToTime(seconds: Double) {
        let seekTime = CMTime(seconds: seconds, preferredTimescale: 1)
        audioPlayer?.seek(to: seekTime)
    }

    func seekToProgress(percentage: Double) {
        guard let duration = playerItem?.duration else { return }
        let totalSeconds = CMTimeGetSeconds(duration)
        let seekTimeSeconds = totalSeconds * percentage
        let seekTime = CMTime(seconds: seekTimeSeconds, preferredTimescale: 1)
        audioPlayer?.seek(to: seekTime)
    }
}

