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
        if let clip = feedModel.nowPlaying {
            return feedModel.feedArtworks[clip.feedItem.feed.id]
        }
        return nil
    }
    
    var body: some View {
        VStack {
            if let clip = feedModel.nowPlaying {
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
                    Text(clip.name)
                        .font(.footnote)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        feedModel.playPause()
                    }) {
                        Image(systemName: feedModel.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.primary)
                    }
                    Button(action: {
                        feedModel.next()
                    }) {
                        Image(systemName: "forward.fill")
                            .foregroundColor(.primary)
                    }
                    
                }
                .padding(10)
                .background(.thinMaterial)
                .cornerRadius(10)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom)
                .onTapGesture {
                    isPlayerShowing = true
                }
                .sheet(isPresented: $isPlayerShowing, onDismiss: {
                    isPlayerShowing = false
                }) {
                    NowPlayingSheet()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(25)
                        .presentationBackground(.clear)
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
