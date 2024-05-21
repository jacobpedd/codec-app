//
//  AudioManager.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/21/24.
//

import Foundation
import AVFoundation

protocol AudioManagerDelegate: AnyObject {
    func playbackDidEnd()
    func currentTimeUpdated(_ timeElapsed: TimeInterval)
    func durationLoaded(_ duration: TimeInterval)
}

class AudioManager {
    weak var delegate: AudioManagerDelegate?
    var audioPlayer: AVPlayer?
    var playerItem: AVPlayerItem?
    var timeObserverToken: Any?

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            print("Error configuring session")
        }
    }

    func loadAudio(audioKey: String) {
        cleanUp()
        
        guard let url = URL(string: "https://bucket.wirehead.tech/\(audioKey)") else { return }
        let asset = AVAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)
        guard let playerItem = playerItem else { return }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        audioPlayer = audioPlayer ?? AVPlayer(playerItem: playerItem)
        audioPlayer?.replaceCurrentItem(with: playerItem)

        setupProgressListener()
        loadDuration()
    }

    func play() {
        audioPlayer?.play()
    }

    func pause() {
        audioPlayer?.pause()
    }
    
    func setRate(rate: Double) {
        audioPlayer?.rate = Float(rate)
    }

    func seekTo(seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        audioPlayer?.seek(to: time)
    }

    private func loadDuration() {
        guard let playerItem = playerItem else { return }
        Task {
            do {
                let duration = try await playerItem.asset.load(.duration)
                if !duration.isIndefinite {
                    let seconds = CMTimeGetSeconds(duration)
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.durationLoaded(seconds)
                    }
                }
            } catch {
                print("Error loading duration")
            }
        }
    }

    private func setupProgressListener() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let timeElapsed = CMTimeGetSeconds(time)
            self?.delegate?.currentTimeUpdated(timeElapsed)
        }
    }

    @objc private func playerItemDidReachEnd() {
        delegate?.playbackDidEnd()
    }

    private func cleanUp() {
        if let token = timeObserverToken {
            audioPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self)
    }

    deinit {
        cleanUp()
    }
}
