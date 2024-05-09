//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI
import BigUIPaging


struct ContentView: View {
    @State private var viewModel = ViewModel()
    @State private var currentPageIndex: Int = 0

    var body: some View {
        VStack {
            if (!viewModel.feed.isEmpty) {
                PageView(selection: $currentPageIndex) {
                    ForEach(0..<viewModel.feed.count, id: \.self) { index in
                        TopicView(
                            topic: viewModel.feed[index],
                            isPlaying: index == viewModel.feedIndex,
                            onPlay: {
                                viewModel.feedIndex = index
                            }
                        )
                    }
                }
                .pageViewStyle(.cardDeck)
                .pageViewCardCornerRadius(15)
                
                PageIndicator(selection: $currentPageIndex, total: viewModel.feed.count) { (index, _) in
                    if index == viewModel.feedIndex {
                            Image(systemName: "play.fill")
                        }
                }
                .pageIndicatorColor(.gray)
                .pageIndicatorCurrentColor(.accentColor)
                .pageIndicatorBackgroundStyle(.prominent)
                .allowsContinuousInteraction(false)
                
                NowPlayingView(topic: viewModel.currentTopic)
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .task {
            await viewModel.loadFeed()
        }
    }
}

#Preview {
    return ContentView()
}
