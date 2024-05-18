//
//  NowPlayingView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/7/24.
//

import SwiftUI


struct NowPlayingView: View {
    @State private var isPlayerShowing: Bool = false
    @EnvironmentObject private var playerModel: AudioPlayerModel
    @EnvironmentObject private var userModel: UserModel
    
    var topic: Topic? {
        userModel.playingTopic
    }
    
    var image: Artwork? {
        if let topic {
            return userModel.topicArtworks[topic.id]
        }
        return nil
    }
    
    var body: some View {
        VStack {
            if let topic {
                HStack {
                    if let image = image {
                        Image(uiImage: image.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .cornerRadius(10)
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 30, height: 30)
                            .cornerRadius(10)
                    }
                    Text(topic.title)
                        .font(.footnote)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        playerModel.playPause()
                    }) {
                        Image(systemName: playerModel.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.black)
                    }
                    Button(action: {
                        userModel.next()
                    }) {
                        Image(systemName: "forward.fill")
                            .foregroundColor(.black)
                    }
                    
                }
                .padding(10)
                .background()
                .cornerRadius(10)
                .frame(maxWidth: .infinity)
                .shadow(color: Color.gray.opacity(0.3), radius: 10)
                .padding(.horizontal)
                .padding(.bottom)
                .onChange(of: topic.audio) { audio in
                    playerModel.loadAudio(audioKey: audio)
                }
                .onTapGesture {
                    isPlayerShowing = true
                }
                .sheet(isPresented: $isPlayerShowing, onDismiss: {
                    isPlayerShowing = false
                }) {
                    NowPlayingSheet()
                }
                .onAppear() {
                    playerModel.loadAudio(audioKey: topic.audio)
                }
            }
        }
    }
}

#Preview {
    return VStack {
        Spacer()
        NowPlayingView()
            .environmentObject(AudioPlayerModel())
            .environmentObject(UserModel())
    }
}
