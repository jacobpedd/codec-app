//
//  TopicViewList.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/17/24.
//

import Foundation
import SwiftUI

struct TopicListView: View {
    var topic: Topic
    @EnvironmentObject var userModel: UserModel
    @EnvironmentObject var playerModel: AudioPlayerModel
    @State private var isMenuOpen: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ZStack {
                    if let image = userModel.topicArtworks[topic.id] {
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
                        if playerModel.isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        } else  {
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

                    Text(topic.createdAt.customFormatted())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    Button(role: .destructive, action: { onDelete(id: topic.id) }) {
                        Label("Remove", systemImage: "trash")
                    }
                    Button(action: { userModel.moveTopicToFront(at: topic.id) }) {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    Button(action: { userModel.moveTopicToBack(at: topic.id) }) {
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
        .padding(.horizontal)
        .onTapGesture {
            onPlay(id: topic.id)
        }

//        if isMenuOpen {
//            Color.black.opacity(0.001)
//                .edgesIgnoringSafeArea(.all)
//                .onTapGesture {
//                    isMenuOpen = false
//                }
//        }
    }
    
    private var isPlayingTopic: Bool {
        if let playingTopicId = userModel.playingTopicId {
            return playingTopicId == topic.id
        }
        return false
    }

    private func onPlay(id: Int) {
        if userModel.playingTopicId != id {
            userModel.playingTopicId = id

            if !playerModel.isPlaying {
                playerModel.playPause()
            }
        } else {
            playerModel.playPause()
        }
    }

    private func onDelete(id: Int) {
        userModel.deleteTopicId(at: id)
    }
}
