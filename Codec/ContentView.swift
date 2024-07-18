//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var showOnboarding = false
    
    var body: some View {
        Group {
            if feedModel.token != nil && feedModel.username != nil {
                if feedModel.nowPlaying != nil {
                    FeedView()
                } else {
                    VStack {
                        ProgressView()
                            .task {
                                await feedModel.load()
                            }
                        Text("Loading your feed...")
                            .padding(.top)
                    }
                }
            } else {
                LoginView()
            }
        }
        .onChange(of: feedModel.needsOnboarding) {
            if feedModel.needsOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet(isPresented: $showOnboarding)
                .interactiveDismissDisabled()
        }
    }
}

#Preview {
    return ContentView()
        .environmentObject(FeedModel(debug: true))
}
