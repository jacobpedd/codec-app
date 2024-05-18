//
//  TopicViewList.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/17/24.
//

import Foundation
import SwiftUI

struct TopicListView: View {
    var index: Int
    @EnvironmentObject var userModel: UserModel
    @EnvironmentObject var playerModel: AudioPlayerModel
    @State private var isMenuOpen: Bool = false

    var body: some View {
        ZStack {
            if index < userModel.feed.count {
                VStack(spacing: 0) {
                    HStack {
                        ZStack {
                            if let image = userModel.topicArtworks[userModel.feed[index].id] {
                                Image(uiImage: image.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(10)
                                    .overlay(
                                        userModel.playingIndex == index ?
                                        Color.black.opacity(0.6).cornerRadius(10) : nil
                                    )
                            } else {
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(10)
                            }

                            if userModel.playingIndex == index {
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
                            Text(userModel.feed[index].title)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(userModel.feed[index].createdAt.customFormatted())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Menu {
                            Button(role: .destructive, action: { onDelete(index: index) }) {
                                Label("Remove", systemImage: "trash")
                            }
                            Button(action: { userModel.moveTopicToFront(at: index) }) {
                                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            }
                            Button(action: { userModel.moveTopicToBack(at: index) }) {
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

                    if index != userModel.feed.count - 1 {
                        HStack {
                            Rectangle()
                                .frame(width: 60, height: 0)
                            VStack {
                                Divider()
                            }
                        }
                        .frame(height: 20)
                    } else {
                        Rectangle()
                            .fill(.white)
                            .frame(height: 40)
                    }
                }
                .padding(.horizontal)
                .onTapGesture {
                    onPlay(index: index)
                }

                if isMenuOpen {
                    Color.black.opacity(0.001)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            isMenuOpen = false
                        }
                }
            }
        }
    }

    private func onPlay(index: Int) {
        if userModel.playingIndex != index {
            userModel.playingIndex = index

            if !playerModel.isPlaying {
                playerModel.playPause()
            }
        } else {
            playerModel.playPause()
        }
    }

    private func onDelete(index: Int) {
        userModel.deleteTopic(at: index)
    }
}
