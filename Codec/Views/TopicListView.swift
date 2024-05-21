//
//  TopicViewList.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/17/24.
//

import SwiftUI

struct TopicListView: View {
    var topic: Topic
    @EnvironmentObject var feedModel: FeedModel
    @State private var isMenuOpen: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ZStack {
                    if let image = feedModel.topicArtworks[topic.id] {
                        Image(uiImage: image.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(10)
                            .overlay(isPlayingTopic ?
                                     Color.black.opacity(0.6).cornerRadius(10) : nil
                            )
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 60, height: 60)
                            .cornerRadius(10)
                    }

                    if isPlayingTopic {
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
                    Text(topic.title)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(topic.createdAt.customFormatted()) • \(formatTimeStatus())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
                
                if (!isPlayingTopic) {
                    Menu {
                        Button(role: .destructive, action: { onDelete() }) {
                            Label("Remove", systemImage: "trash")
                        }
                        Button(action: { feedModel.playNext(at: topic.id) }) {
                            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                        }
                        Button(action: { feedModel.playLast(at: topic.id) }) {
                            Label("Play Last", systemImage: "text.line.last.and.arrowtriangle.forward")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.black)
                            .padding()
                    }
                    .onTapGesture {
                        isMenuOpen.toggle()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var isPlayingTopic: Bool {
        if let playingTopic = feedModel.nowPlaying {
            return topic.id == playingTopic.id
        }
        return false
    }

//    private func onPlay() {
//        if isPlayingTopic {
//            feedModel.playPause()
//        } else {
//            feedModel.playTopic(at: topic.id)
//
//            if !feedModel.isPlaying {
//                feedModel.playPause()
//            }
//        }
//    }

    private func onDelete() {
        feedModel.deleteTopic(id: topic.id)
    }
    
    private func formatTimeStatus() -> String {
        if let currentTime = topic.currentTime, currentTime < topic.duration {
            let timeRemaining = topic.duration - currentTime
            let minutesRemaining = Int(timeRemaining / 60)

            if minutesRemaining > 0 {
                let minLabel = minutesRemaining == 1 ? "min" : "mins"
                return "\(minutesRemaining) \(minLabel) left"
            } else {
                return "Less than a minute left"
            }
        } else {
            // If currentTime is not set or duration is complete
            let totalDurationMinutes = Int(topic.duration / 60)
            let minLabel = totalDurationMinutes == 1 ? "min" : "mins"
            return "\(totalDurationMinutes) \(minLabel)"
        }
    }

}
