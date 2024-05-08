//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI
import BigUIPaging


struct ContentView: View {
    @State private var userData = UserData()
    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack {
            if (!userData.feed.isEmpty) {
                PageView(selection: $selectedIndex) {
                    ForEach(0..<userData.feed.count, id: \.self) { index in
                        TopicView(topic: userData.feed[index])
                    }
                }
                .pageViewStyle(.cardDeck)
                
                PageIndicator(selection: $selectedIndex, total: userData.feed.count) { (index, _) in
                    if index == userData.feedIndex {
                            Image(systemName: "play.fill")
                        }
                }
                .pageIndicatorColor(.gray)
                .pageIndicatorCurrentColor(.accentColor)
                .pageIndicatorBackgroundStyle(.prominent)
                .allowsContinuousInteraction(false)
                
                NowPlayingView(topic: userData.feed[userData.feedIndex])
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .task {
            await loadFeed()
        }
    }
    
    func loadFeed() async {
        guard let url = URL(string: "https://api.wirehead.tech/queue?email=jacob.peddicord@hey.com") else {
            print("Invalid URL")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            let decodedResponse = try! decoder.decode([Topic].self, from: data)
            userData.feed = decodedResponse
        } catch {
            print("Error: \(error)")
        }
    }
}

#Preview {
    return ContentView()
}
