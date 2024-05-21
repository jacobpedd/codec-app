//
//  AudioPlayerManager.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/21/24.
//

import AVFoundation
import MediaPlayer

protocol MediaPlayerDelegate: AnyObject {
    func nextTrack() -> URL?
    func previousTrack() -> URL?
}

class MediaPlayerManager {
    weak var delegate: MediaPlayerDelegate?
    static let shared = MediaPlayerManager()

    var audioPlayer: AVPlayer?
    var currentPlayerItem: AVPlayerItem?
    
    init() {
        setupControlCenterControls()
        configureAudioSession()
    }

    private func setupControlCenterControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.pause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.nextTrack()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            self?.previousTrack()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seekToTime(seconds: event.positionTime)
            return .success
        }
    }

    func play() {
        audioPlayer?.play()
        updateNowPlayingInfo()
    }

    func pause() {
        audioPlayer?.pause()
        updateNowPlayingInfo()
    }

    func nextTrack() {
        guard let nextUrl = delegate?.nextTrack() else { return }
        let nextItem = AVPlayerItem(url: nextUrl)
        audioPlayer?.replaceCurrentItem(with: nextItem)
        
        play()
    }

    func previousTrack() {
        // Logic to switch to the previous track
    }

    func seekToTime(seconds: Double) {
        let seekTime = CMTime(seconds: seconds, preferredTimescale: 1)
        audioPlayer?.seek(to: seekTime)
    }

    private func updateNowPlayingInfo() {
//        var nowPlayingInfo = [String: Any]()
//        // Set up metadata here, such as track title and artist
//        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            print("Failed to set audio session category.")
        }
    }
}
