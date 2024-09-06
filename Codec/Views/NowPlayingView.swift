//
//  NowPlayingView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/7/24.
//

import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var playerVM: PlayerViewModel
    @EnvironmentObject private var artworkVM: ArtworkViewModel
    
    @State private var isPlayerShowing: Bool = false
    @State private var artwork: Artwork?
    
    var body: some View {
        VStack {
            if let clip = playerVM.nowPlaying {
                HStack {
                    ArtworkView(feed: clip.feedItem.feed)
                        .frame(width: 40, height: 40)
                        .cornerRadius(5)
                    Text(clip.name)
                        .font(.footnote)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        playerVM.playPause()
                    }) {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.primary)
                    }
                    Button(action: {
                        playerVM.next()
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
    }
    .previewWithEnvironment()
}
