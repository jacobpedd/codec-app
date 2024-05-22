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
    @State private var emailInput: String = ""
    
    var body: some View {
        if feedModel.email != "" {
            if feedModel.nowPlaying != nil {
                FeedView()
            } else {
                ProgressView()
                    .task {
                        await feedModel.load()
                    }
            }
        } else {
            EmailInputView(emailInput: $emailInput) {
                feedModel.email = emailInput
                // Dismiss the keyboard
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

#Preview {
    return ContentView()
        .environmentObject(FeedModel())
        .preferredColorScheme(.dark)
}
