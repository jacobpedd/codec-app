//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI
import BigUIPaging


struct ContentView: View {
    @EnvironmentObject private var userModel: UserDataModel
    @State private var currentPageIndex: Int = 0

    var body: some View {
        VStack {
            if (!userModel.feed.isEmpty) {
                PageView(selection: $currentPageIndex) {
                    ForEach(0..<userModel.feed.count, id: \.self) { index in
                        TopicView(
                            topic: userModel.feed[index],
                            isPlaying: index == userModel.feedIndex,
                            onPlay: {
                                userModel.feedIndex = index
                            }
                        )
                    }
                }
                .pageViewStyle(.cardDeck)
                .pageViewCardCornerRadius(15)
                
                PageIndicator(selection: $currentPageIndex, total: userModel.feed.count) { (index, _) in
                    if index == userModel.feedIndex {
                            Image(systemName: "play.fill")
                        }
                }
                .pageIndicatorColor(.gray)
                .pageIndicatorCurrentColor(.accentColor)
                .pageIndicatorBackgroundStyle(.prominent)
                .allowsContinuousInteraction(false)
                
                NowPlayingView(topic: userModel.currentTopic)
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .onChange(of: userModel.feedIndex) {
            currentPageIndex = userModel.feedIndex
        }
        .task {
            await userModel.loadFeed()
        }
    }
}

#Preview {
    return ContentView()
        .environmentObject(AudioPlayerModel())
        .environmentObject(UserDataModel())
}
