//
//  NowPlayingView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/7/24.
//

import SwiftUI


struct NowPlayingView: View {
    @State private var isPlayerShowing: Bool = false
    @EnvironmentObject private var feedModel: FeedModel
    
    var image: Artwork? {
        if let topic = feedModel.nowPlaying {
            return feedModel.topicArtworks[topic.id]
        }
        return nil
    }
    
    var body: some View {
        VStack {
            if let topic = feedModel.nowPlaying {
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
                        feedModel.playPause()
                    }) {
                        Image(systemName: feedModel.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.black)
                    }
                    Button(action: {
                        feedModel.next()
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
                .onChange(of: topic.audio) {
                    // TODO: I think the loading should happen in model?
                    feedModel.loadAudio(audioKey: topic.audio)
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
                    // TODO: I think the loading should happen in model?
                    feedModel.loadAudio(audioKey: topic.audio)
                }
            }
        }
    }
}

#Preview {
    return VStack {
        Spacer()
        NowPlayingView()
            .environmentObject(FeedModel())
    }
}
