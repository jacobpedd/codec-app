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

    var topic: Topic {
        userModel.feed[index]
    }
    
    var image: Artwork? {
        userModel.topicArtworks[topic.id]
    }
    
    func onPlay() {
        if (userModel.playingIndex != index) {
            // Switch to the current index
            userModel.playingIndex = index
            
            // Play if it wasn't already playing
            if !playerModel.isPlaying {
                playerModel.playPause()
            }
        } else {
            playerModel.playPause()
        }
        
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ZStack {
                    if let image = image {
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
                    Text(topic.title)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(topic.createdAt.customFormatted())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Add spacer if not last
            if (index != userModel.feed.count - 1) {
                HStack() {
                    Rectangle()
                        .frame(width: 60, height: 0)
                    VStack {
                        Divider()
                    }
                    
                }
                .frame(height: 20)
            } else {
                // Annoying spacing for the now playing overlay effect
                Rectangle()
                    .frame(height: 40)
            }
        }
        .padding(.horizontal)
        .onTapGesture {
            onPlay()
        }
    }
}
