//
//  SearchView.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import SwiftUI

class DebounceManager {
    private var workItem: DispatchWorkItem?

    func debounce(delay: TimeInterval, action: @escaping () -> Void) {
        // Cancel the previous work item
        workItem?.cancel()

        // Create a new work item
        let newWorkItem = DispatchWorkItem {
            action()
        }

        // Assign the new work item
        workItem = newWorkItem

        // Execute the work item after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
}

struct SearchView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    private let debounceManager = DebounceManager()

    var body: some View {
        List {
            if feedModel.searchResults.isEmpty {
                Text("No results")
                    .foregroundColor(.secondary)
            } else {
                ForEach(feedModel.searchResults) { show in
                    Button(action: {
                        followShow(show)
                    }) {
                        HStack {
                            Text(show.name)
                                .foregroundStyle(.foreground)
                            Spacer()
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Show")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for shows")
        .onChange(of: searchText) {
            debounceSearch()
        }
        .onAppear {
            performSearch()
        }
    }

    private func followShow(_ show: Feed) {
        Task {
            let success = await feedModel.followShow(feed: show)
            if success {
                await feedModel.loadProfileData()
                presentationMode.wrappedValue.dismiss()
            }
        }
    }


    private func debounceSearch() {
        debounceManager.debounce(delay: 0.5) { [self] in
            performSearch()
        }
    }

    private func performSearch() {
        Task {
            await feedModel.searchShows(query: searchText)
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VStack {
                SearchView()
                    .environmentObject(FeedModel())
            }
        }
    }
}

