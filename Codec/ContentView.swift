//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI
import SwiftData
import BigUIPaging

struct TopicView: View {
    var topic: Topic

    var body: some View {
        VStack {
            VStack {
                Spacer()
                Text("Page \(topic.title)")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.blue)
        .cornerRadius(10)
    }
}

struct ContentView: View {
    @Query(
        filter: #Predicate<Topic> {
            $0.viewedAt == nil &&
            $0.dismissedAt == nil
        },
        sort: \Topic.addedAt
    ) private var feed: [Topic]
    @State private var isPlayerShowing: Bool = false
    @State private var selectedId: String = "0"
    var selectedIndex: Int {
        feed.firstIndex(where: { $0.id == selectedId }) ?? 0
    }

    var body: some View {
        VStack {
            PageView(selection: $selectedId) {
                ForEach(feed, id: \.id) { topic in
                    TopicView(topic: topic)
                }
            }
            .pageViewStyle(.cardDeck)
            
            PageIndicator(selection: Binding(
                get: { selectedIndex },
                set: { newIndex in
                    guard newIndex >= 0 && newIndex < feed.count else { return }
                    selectedId = feed[newIndex].id}), total: feed.count) { (page, selected) in
                    if page == 0 {
                        Image(systemName: "play.fill")
                    }
                }
                .pageIndicatorColor(.gray)
                .pageIndicatorCurrentColor(.accentColor)
                .pageIndicatorBackgroundStyle(.prominent)
                .allowsContinuousInteraction(false)
            
            HStack {
                Text("Now Playing")
                    .font(.title2)
                Spacer()
                Image(systemName: "play.fill")
            }
            .padding()
            .background(.white)
            .cornerRadius(10)
            .frame(maxWidth: .infinity)
            .shadow(color: .gray, radius: 10)
            .padding()
            .onTapGesture {
                isPlayerShowing = true
            }
            .sheet(isPresented: $isPlayerShowing, onDismiss: {
                isPlayerShowing = false
            }) {
                VStack(spacing: 15) {
                    Text("Big Player Screen")
                        .font(.largeTitle)
                    Spacer() 
                }
                .padding()
                .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Topic.self, configurations: config)
    
    let feed = [
        Topic(id: "0", title: "SwiftUI Introduction", preview: "Learn the basics of SwiftUI.", addedAt: Date()),
        Topic(id: "1", title: "Advanced SwiftUI", preview: "Dive deeper into SwiftUI.", addedAt: Date()),
        Topic(id: "2", title: "SwiftUI and Combine", preview: "Combine with SwiftUI for reactive programming.", addedAt: Date())
    ]

    for topic in feed {
        container.mainContext.insert(topic)
    }

    return ContentView()
        .modelContainer(container)
}
