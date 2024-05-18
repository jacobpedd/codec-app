//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI


struct ContentView: View {
    @EnvironmentObject private var userModel: UserModel

    var body: some View {
        VStack {
            if (!userModel.feed.isEmpty) {
                ZStack() {
                    VStack {
                        List {
                            ForEach(userModel.feed) { topic in
                                TopicListView(topic: topic)
                                    .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
                            }
                            .onDelete(perform: delete)
                            Rectangle()
                                .fill(.blue)
                                .frame(height: 0)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(PlainListStyle())
                        
                        Rectangle()
                            .fill(.white)
                            .frame(height: 40)
                    }
                    .padding(.trailing)
                    
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
        .task {
            await userModel.loadFeed()
        }
    }
    
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            userModel.deleteTopicIndex(at: index)
        }
    }
}

#Preview {
    return ContentView()
        .environmentObject(AudioPlayerModel())
        .environmentObject(UserModel())
}
