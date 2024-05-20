//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI


struct ContentView: View {
    @EnvironmentObject private var userModel: UserModel
    
    var history: [Topic] {
        if userModel.feed.count > 0 {
            return Array(userModel.feed[..<userModel.nowPlayingIndex])
        } else {
            return []
        }
    }
    
    var nowPlaying: Topic? {
        if userModel.feed.count > 0 {
            return userModel.feed[userModel.nowPlayingIndex]
        } else {
            return nil
        }
    }
    
    var upNext: [Topic] {
        if userModel.feed.count > 0 {
            return Array(userModel.feed[(userModel.nowPlayingIndex + 1)...])
        } else {
           return []
        }
    }

    var body: some View {
        VStack {
            ZStack() {
                VStack {
                    ScrollViewReader { scrollView in
                        List {
                            if history.count > 0 {
                                Section(header: Text("History")) {
                                    ForEach(history) { topic in
                                        TopicListView(topic: topic)
                                            .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
                                            .id(topic.id)
                                    }
                                    .onDelete(perform: deleteFromHistory)
                                }
                            }
                            
                            if nowPlaying != nil {
                                Section(header: Text("Now Playing")) {
                                    TopicListView(topic: nowPlaying!)
                                        .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
                                        .listRowSeparator(.hidden)
                                        .id(nowPlaying!.id)
                                    
                                }
                            }
                            
                            if upNext.count > 0 {
                                Section(header: Text("Up Next")) {
                                    ForEach(upNext) { topic in
                                        TopicListView(topic: topic)
                                            .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
                                            .id(topic.id)
                                    }
                                    .onDelete(perform: deleteFromUpNext)
                                }
                            }
                            Rectangle()
                                .fill(.blue)
                                .frame(height: 0)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(PlainListStyle())
                        .onChange(of: nowPlaying?.id) {
                            if let topicId = nowPlaying?.id {
                                withAnimation {
                                    scrollView.scrollTo(topicId, anchor: .top)
                                }
                            }
                        }
                    }
                    
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
        }
        .task {
            await userModel.loadFeed()
        }
    }
    
    private func deleteFromHistory(at offsets: IndexSet) {
        for index in offsets {
            userModel.deleteTopicIndex(at: index)
        }
    }
    
    private func deleteNowPlaying(at offsets: IndexSet) {
        if nowPlaying != nil {
            userModel.deleteTopicIndex(at: userModel.nowPlayingIndex)
        }
    }
    
    private func deleteFromUpNext(at offsets: IndexSet) {
        for index in offsets {
            userModel.deleteTopicIndex(at: userModel.nowPlayingIndex + 1 + index)
        }
    }
}

#Preview {
    return ContentView()
        .environmentObject(AudioPlayerModel())
        .environmentObject(UserModel())
}
