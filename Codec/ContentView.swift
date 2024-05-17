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
                ZStack() {
                    VStack {
                        List(0..<userModel.feed.count, id: \.self) { index in
                            TopicListView(index: index)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                            
                                
                        }
                        .listStyle(PlainListStyle())
                        Rectangle()
                            .fill(.white)
                            .frame(height: 40)
                            .background(.white)
                    }
                    
                    
                    VStack {
                        Spacer()
                        NowPlayingView()
                    }
                }
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
