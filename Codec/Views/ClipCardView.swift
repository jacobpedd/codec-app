//
//  ClipCardView.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/10/24.
//

import SwiftUI

struct ClipCardView: View {
    @EnvironmentObject private var feedModel: FeedModel
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
                    VStack {
                        Spacer()
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
                            Spacer()
                        }
                        .padding()
                        .background(.thinMaterial)
                        }
                    .opacity(labelOpacity)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ProgressView()
            }
        }
        .frame(width: cardSize, height: cardSize)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .animation(.easeInOut(duration: 0.3), value: index == feedModel.nowPlayingIndex)
    }
}

