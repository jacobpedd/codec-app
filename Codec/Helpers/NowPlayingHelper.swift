//
//  NowPlayingHelper.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/21/24.
//

import Foundation
import MediaPlayer

struct NowPlayingHelper {
    // Private static function to update the now playing information
    private static func updateNowPlayingInfo(_ updates: [String: Any?]) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        updates.forEach { key, value in
            nowPlayingInfo[key] = value
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // Function to update the artwork in the Now Playing Info
    static func setArtwork(_ image: UIImage) {
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
        updateNowPlayingInfo([MPMediaItemPropertyArtwork: artwork])
    }

    // Function to set the title in the Now Playing Info
    static func setTitle(_ title: String) {
        updateNowPlayingInfo([MPMediaItemPropertyTitle: title])
    }
    
    // Function to set the artist in the Now Playing Info
    static func setArtist(_ artist: String) {
        updateNowPlayingInfo([MPMediaItemPropertyTitle: artist])
    }

    // Function to set the duration in the Now Playing Info
    static func setDuration(_ duration: TimeInterval) {
        updateNowPlayingInfo([MPMediaItemPropertyPlaybackDuration: duration])
    }

    // Function to set the current playback time in the Now Playing Info
    static func setCurrentTime(_ currentTime: TimeInterval) {
        updateNowPlayingInfo([MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime])
    }

    // Function to set the playback rate in the Now Playing Info
    static func setPlaybackRate(_ rate: Float) {
        updateNowPlayingInfo([MPNowPlayingInfoPropertyPlaybackRate: rate])
    }
}
