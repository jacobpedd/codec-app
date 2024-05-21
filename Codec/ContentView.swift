//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI


struct ContentView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var fetchingNewTopics: Bool = false

    var body: some View {
        if let nowPlaying = feedModel.nowPlaying {
            NavigationStack {
                ZStack() {
                    VStack {
                        ScrollViewReader { scrollView in
                            List {
                                if feedModel.history.count > 0 {
                                    Section(header: Text("History")) {
                                        ForEach(feedModel.history) { topic in
                                            TopicListView(topic: topic)
                                                .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
                                                .id(topic.id)
                                        }
                                        .onDelete(perform: deleteFromHistory)
                                    }
                                }
                                
                                Section(header: Text("Now Playing")) {
                                    TopicListView(topic: nowPlaying)
                                        .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
                                        .listRowSeparator(.hidden)
                                        .id(nowPlaying.id)
                                    
                                }
                                .headerProminence(.increased)
                                
                                if feedModel.upNext.count > 0 {
                                    Section(header: Text("Up Next")) {
                                        ForEach(feedModel.upNext) { topic in
                                            TopicListView(topic: topic)
                                                .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
                                                .id(topic.id)
                                        }
                                        .onDelete(perform: deleteFromUpNext)
                                    }

                                }
                                if fetchingNewTopics {
                                    VStack {
                                        ProgressView()
                                        Text("Fetching more topics...")
                                            .foregroundStyle(.gray)
                                            .font(.caption)
                                            .padding(.top, 10)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                                
                                Rectangle()
                                    .fill(.blue)
                                    .frame(height: 0)
                                    .listRowSeparator(.hidden)
                            }
                            .listStyle(PlainListStyle())
                            .onAppear() {
                                if let topicId = feedModel.nowPlaying?.id {
                                    scrollView.scrollTo(topicId, anchor: .top)
                                }
                            }
                            .onChange(of: feedModel.nowPlaying?.id) {
                                if let topicId = feedModel.nowPlaying?.id {
                                    withAnimation {
                                        scrollView.scrollTo(topicId, anchor: .top)
                                    }
                                }
                            }
                            .onChange(of: feedModel.upNext.count) {
                                if feedModel.upNext.count < 5 && !fetchingNewTopics {
                                    fetchMoreTopics()
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
                .navigationTitle("Codec")
            }
        } else {
            ProgressView()
                .task {
                    await feedModel.load()
                }
        }
    }
    
    private func deleteFromHistory(at offsets: IndexSet) {
        for index in offsets {
            feedModel.deleteTopic(id: feedModel.history[index].id)
        }
    }
    
    private func deleteFromUpNext(at offsets: IndexSet) {
        for index in offsets {
            feedModel.deleteTopic(id: feedModel.upNext[index].id)
        }
    }
    
    private func fetchMoreTopics() {
        fetchingNewTopics = true
        Task {
            await feedModel.loadMoreTopics()
            DispatchQueue.main.async {
                fetchingNewTopics = false
            }
        }
    }
}

#Preview {
    return ContentView()
        .environmentObject(FeedModel())
}
