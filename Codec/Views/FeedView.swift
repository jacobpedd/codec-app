//
//  FeedView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/22/24.
//

import SwiftUI


struct FeedView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var fetchingNewTopics: Bool = false
    @State private var showProfile: Bool = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    ArtworkScrollFeed()
                    
                    VStack {
                        Spacer()
                        NowPlayingView()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView().environmentObject(feedModel)) {
                        Image(systemName: "person.crop.circle")
                            .imageScale(.large)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private func fetchMoreTopics() {
        fetchingNewTopics = true
        Task {
            await feedModel.loadMoreClips()
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
