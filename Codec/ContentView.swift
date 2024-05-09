//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI
import BigUIPaging


struct ContentView: View {
    @EnvironmentObject private var userModel: UserModel
    @State private var currentPageIndex: Int = 0

    var body: some View {
        VStack {
            if (!userModel.feed.isEmpty) {
                PageView(selection: $currentPageIndex) {
                    ForEach(0..<userModel.feed.count, id: \.self) { index in
                        TopicView(index: index)
                    }
                }
                .pageViewStyle(.cardDeck)
                .pageViewCardCornerRadius(15)
                
                PageIndicator(selection: $currentPageIndex, total: userModel.feed.count) { (index, _) in
                    if index == userModel.playingIndex {
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
        .onChange(of: userModel.playingIndex) {
            currentPageIndex = userModel.playingIndex
        }
        .task {
            await userModel.loadFeed()
        }
    }
}

#Preview {
    return ContentView()
        .environmentObject(AudioPlayerModel())
        .environmentObject(UserModel())
}
