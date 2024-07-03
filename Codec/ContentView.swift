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
        if feedModel.token != nil {
            if feedModel.nowPlaying != nil {
                FeedView()
            } else {
                ProgressView()
                    .task {
                        await feedModel.load()
                    }
                Text("Loading your feed...")
                    .padding(.top)
            }
        } else {
            LoginView()
        }
    }
}

#Preview {
    return ContentView()
        .environmentObject(FeedModel())
}
