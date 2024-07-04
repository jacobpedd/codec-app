//
//  ClipListView.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/3/24.
//

import SwiftUI

struct ClipListView: View {
    var clip: Clip
    @EnvironmentObject var feedModel: FeedModel
    @State private var isMenuOpen: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ZStack {
                    if let image = feedModel.clipArtworks[clip.id] {
                        Image(uiImage: image.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(10)
                            .overlay(isPlayingClip ?
                                     Color.black.opacity(0.6).cornerRadius(10) : nil
                            )
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 60, height: 60)
                            .cornerRadius(10)
                    }

                    if isPlayingClip {
                        if feedModel.isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        } else {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        }
                    }
                }

                VStack(alignment: .leading) {
                    Text(clip.name)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(clip.createdAt.customFormatted()) • \(formatTimeStatus())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
                
                if (!isPlayingClip) {
                    Menu {
                        Button(role: .destructive, action: { onDelete() }) {
                            Label("Remove", systemImage: "trash")
                        }
                        Button(action: { feedModel.playNext(at: clip.id) }) {
                            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                        }
                        Button(action: { feedModel.playLast(at: clip.id) }) {
                            Label("Play Last", systemImage: "text.line.last.and.arrowtriangle.forward")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                            .padding()
                    }
                    .onTapGesture {
                        isMenuOpen.toggle()
                    }
                }
            }
        }
        .padding(.horizontal)
        .onTapGesture {
            onPlay()
        }
    }
    
    private var isPlayingClip: Bool {
        if let playingClip = feedModel.nowPlaying {
            return clip.id == playingClip.id
        }
        return false
    }

    private func onPlay() {
        if isPlayingClip {
            feedModel.playPause()
        } else {
            feedModel.playClip(at: clip.id)

            if !feedModel.isPlaying {
                feedModel.playPause()
            }
        }
    }

    private func onDelete() {
        feedModel.deleteClip(id: clip.id)
    }
    
    private func formatTimeStatus() -> String {
        let duration = Double(clip.endTime - clip.startTime) / 1000.0
//        if let currentTime = clip.currentTime, currentTime < duration {
//            let timeRemaining = clip.duration - currentTime
//            let minutesRemaining = Int(timeRemaining / 60)
//
//            if minutesRemaining > 0 {
//                let minLabel = minutesRemaining == 1 ? "min" : "mins"
//                return "\(minutesRemaining) \(minLabel) left"
//            } else {
//                return "Less than a minute left"
//            }
//        } else {
            // If currentTime is not set or duration is complete
            let totalDurationMinutes = Int(duration / 60)
            let minLabel = totalDurationMinutes == 1 ? "min" : "mins"
            return "\(totalDurationMinutes) \(minLabel)"
//        }
    }

}

