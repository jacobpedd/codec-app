//
//  ClipCardView.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/10/24.
//

import SwiftUI

struct ClipCardView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @Binding var isPlayerShowing: Bool
    @State private var dragOffset: CGFloat = 0.0
    let index: Int
    let cardSize: CGFloat
    let labelOpacity: CGFloat
    
    var clip: Clip {
        return feedModel.feed[index]
    }
    
    var artwork: Artwork? {
        return feedModel.feedArtworks[clip.feedItem.feed.id]
    }
    
    var body: some View {
        VStack {
            if let image = artwork?.image {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                    VStack(spacing: 0) {
                        Spacer()
                        progressBar
                        label
                            .padding()
                            .background(.thinMaterial)
                            .shadow(color: .gray, radius: 10)
                        }
                    .opacity(labelOpacity)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    ProgressView()
                }
            }
        }
        .frame(width: cardSize, height: cardSize)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .animation(.easeInOut(duration: 0.3), value: index == feedModel.nowPlayingIndex)
        .onTapGesture {
            handleTap()
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(.thinMaterial)
                        .brightness(0.5)
                        .frame(width: geometry.size.width * feedModel.progress, height: 5)
                        .shadow(color: .black, radius: 10)
                }
                
                Rectangle()
                    .fill(.thinMaterial)
                    .brightness(0.8)
                    .frame(width: 5, height: 12)
                    .shadow(color: .black, radius: 10)
                Spacer()
            }
            
        }
        .frame(width: cardSize, height: 12)
    }
    
    private var label: some View {
        HStack {
            VStack (alignment: .leading) {
                Text(clip.name)
                    .foregroundColor(.primary)
                    .fontWeight(.bold)
                    .lineLimit(2)
                Text(clip.feedItem.feed.name)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .shadow(color: .clear, radius: 0)
            Spacer()
        }
    }
    
    private func handleTap() {
        if index == feedModel.nowPlayingIndex {
            isPlayerShowing = true
        } else if index == feedModel.nowPlayingIndex! - 1 {
            feedModel.previous()
        } else if index == feedModel.nowPlayingIndex! + 1 {
            feedModel.next()
        }
    }
}

