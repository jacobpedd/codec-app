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
    func bufferingStateChanged(_ isBuffering: Bool)
}

class AudioManager: NSObject {
    weak var delegate: AudioManagerDelegate?
    var audioPlayer: AVPlayer?
    var playerItem: AVPlayerItem?
    var timeObserverToken: Any?
    
    private var cachedPlayers: [String: AVPlayer] = [:]
    private var cacheOrder: [String] = []
    private let maxCachedPlayers = 5
    
    override init() {
        super.init()
        setupControlCenterControls()
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            print("AudioManager: Error configuring session: \(error)")
        }
    }

    func loadAudio(audioKey: String) {
        print("AudioManager: Starting to load audio: \(audioKey)")
        cleanUp()
        
        if let cachedPlayer = cachedPlayers[audioKey] {
            audioPlayer = cachedPlayer
            playerItem = cachedPlayer.currentItem
            updateCacheOrder(audioKey)
        } else {
            guard let encodedAudioKey = audioKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://bucket.trycodec.com/\(encodedAudioKey)") else {
                print("AudioManager: Error: Invalid URL for audio key: \(audioKey)")
                return
            }
            let asset = AVAsset(url: url)
            playerItem = AVPlayerItem(asset: asset)
            audioPlayer = AVPlayer(playerItem: playerItem)
            
            print("AudioManager: Caching new player for key: \(audioKey)")
            cachePlayer(audioKey: audioKey, player: audioPlayer!)
        }
        
        guard let playerItem = playerItem else { return }
        
        setupObservers(for: playerItem)
        
        audioPlayer?.replaceCurrentItem(with: playerItem)
        
        setupProgressListener()
        loadDuration()
    }

    private func setupObservers(for playerItem: AVPlayerItem) {
        playerItem.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        let session = AVAudioSession.sharedInstance()
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: session)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let playerItem = object as? AVPlayerItem else { return }
        
        switch keyPath {
        case "playbackBufferEmpty":
            print("AudioManager: Playback buffer is empty")
            delegate?.bufferingStateChanged(true)
        case "playbackLikelyToKeepUp":
            print("AudioManager: Playback is likely to keep up")
            delegate?.bufferingStateChanged(false)
        case "playbackBufferFull":
            print("AudioManager: Playback buffer is full")
            delegate?.bufferingStateChanged(false)
        default:
            break
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
                    await MainActor.run {
                        self.delegate?.durationLoaded(seconds)
                    }
                }
            } catch {
                print("AudioManager: Error loading duration: \(error)")
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
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [unowned self] event in
            guard let delegate = self.delegate else { return .commandFailed }
            if !delegate.isPlaying {
                delegate.playPause()
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.addTarget { [unowned self] event in
            guard let delegate = self.delegate else { return .commandFailed }
            if delegate.isPlaying {
                delegate.playPause()
                return .success
            }
            return .commandFailed
        }

        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            guard let delegate = self.delegate else { return .commandFailed }
            delegate.next()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            guard let delegate = self.delegate else { return .commandFailed }
            delegate.previous()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            guard let delegate = self.delegate else { return .commandFailed }
            delegate.seekToTime(seconds: event.positionTime)
            return .success
        }
    }

    @objc private func playerItemDidReachEnd() {
        audioPlayer?.seek(to: .zero)
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
            if delegate.isPlaying {
                delegate.playPause()
            }
        } else if type == .ended {
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
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
        if let playerItem = playerItem {
            playerItem.removeObserver(self, forKeyPath: "status")
            playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            playerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            playerItem.removeObserver(self, forKeyPath: "playbackBufferFull")
        }
        NotificationCenter.default.removeObserver(self)
    }

    deinit {
        cleanUp()
    }
}
