//
//  AudioManager.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/21/24.
//

import Foundation
import AVFoundation
import MediaPlayer

protocol AudioManagerDelegate: AnyObject {
    var isPlaying: Bool { get }
    func playPause()
    func next()
    func previous()
    func seekToTime(seconds: Double)
    func playbackDidEnd()
    func currentTimeUpdated(_ currentTime: TimeInterval)
    func durationLoaded(_ duration: TimeInterval)
}

class AudioManager {
    weak var delegate: AudioManagerDelegate?
    var audioPlayer: AVPlayer?
    var playerItem: AVPlayerItem?
    var timeObserverToken: Any?
    
    private var cachedPlayers: [String: AVPlayer] = [:]
    private var cacheOrder: [String] = []
    private let maxCachedPlayers = 5
    
    init() {
        setupControlCenterControls()
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            print("Error configuring session: \(error)")
        }
    }

    func loadAudio(audioKey: String) {
        cleanUp()
        
        if let cachedPlayer = cachedPlayers[audioKey] {
            audioPlayer = cachedPlayer
            playerItem = cachedPlayer.currentItem
            updateCacheOrder(audioKey)
        } else {
            guard let encodedAudioKey = audioKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://bucket.trycodec.com/\(encodedAudioKey)") else {
                print("Error: Invalid URL")
                return
            }
            let asset = AVAsset(url: url)
            playerItem = AVPlayerItem(asset: asset)
            audioPlayer = AVPlayer(playerItem: playerItem)
            
            // Cache the new player
            cachePlayer(audioKey: audioKey, player: audioPlayer!)
        }
        
        guard let playerItem = playerItem else { return }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Add observers for the audio session
        let session = AVAudioSession.sharedInstance()
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: session)

        audioPlayer = audioPlayer ?? AVPlayer(playerItem: playerItem)
        audioPlayer?.replaceCurrentItem(with: playerItem)
        
        setupProgressListener()
        loadDuration()
    }

    func preloadAudio(audioKeys: [String]) {
        for audioKey in audioKeys {
            if cachedPlayers[audioKey] == nil {
                guard let encodedAudioKey = audioKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                      let url = URL(string: "https://bucket.trycodec.com/\(encodedAudioKey)") else {
                    print("Error: Invalid URL for key: \(audioKey)")
                    continue
                }
                let asset = AVAsset(url: url)
                let playerItem = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: playerItem)
                
                cachePlayer(audioKey: audioKey, player: player)
            } else {
                updateCacheOrder(audioKey)
            }
        }
    }

    private func cachePlayer(audioKey: String, player: AVPlayer) {
        cachedPlayers[audioKey] = player
        cacheOrder.append(audioKey)
        
        if cachedPlayers.count > maxCachedPlayers {
            let oldestKey = cacheOrder.removeFirst()
            cachedPlayers.removeValue(forKey: oldestKey)
        }
    }

    private func updateCacheOrder(_ audioKey: String) {
        if let index = cacheOrder.firstIndex(of: audioKey) {
            cacheOrder.remove(at: index)
        }
        cacheOrder.append(audioKey)
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
                print("Error loading duration: \(error)")
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
    
    private func setupControlCenterControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()

        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            guard let delegate = self.delegate else { return .commandFailed }
            print("Play command - is playing: \(delegate.isPlaying)")
            if !delegate.isPlaying {
                delegate.playPause()
                return .success
            }
            return .commandFailed
        }

        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            guard let delegate = self.delegate else { return .commandFailed }
            print("Pause command - is playing: \(delegate.isPlaying)")
            if delegate.isPlaying {
                delegate.playPause()
                return .success
            }
            return .commandFailed
        }

        // Add handler for Next Command
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            guard let delegate = self.delegate else { return .commandFailed }
            print("Next command")
            delegate.next()
            return .success
        }

        // Add handler for Previous Command
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            guard let delegate = self.delegate else { return .commandFailed }
            print("Previous command")
            delegate.previous()
            return .success
        }

        // Add handler for Seek Command
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            guard let delegate = self.delegate else { return .commandFailed }
            print("Seek command - position: \(event.positionTime)")
            delegate.seekToTime(seconds: event.positionTime)
            return .success
        }
    }

    @objc private func playerItemDidReachEnd() {
        delegate?.playbackDidEnd()
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        guard let delegate = self.delegate else { return }

        if type == .began {
            // Interruption began, pause playback
            if delegate.isPlaying {
                delegate.playPause()
            }
        } else if type == .ended {
            // Interruption ended, resume playback if needed
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Resume playback if appropriate
                if !delegate.isPlaying {
                    delegate.playPause()
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
        guard let delegate = self.delegate else { return }

        switch reason {
            case .oldDeviceUnavailable:
                // Headphones unplugged, pause playback
                if delegate.isPlaying {
                    delegate.playPause()
                }
            default: break
        }
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
