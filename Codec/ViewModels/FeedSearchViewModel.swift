//
//  FeedSearchViewModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/21/24.
//

import SwiftUI

class FeedSearchViewModel: ObservableObject {
    @Published var searchResults: [Feed] = []
    @Published var isSearching = false
    @Published var searchText: String = "" {
        didSet {
            debounceSearch()
        }
    }
    
    var feedService: FeedService?
    var profileVM: ProfileViewModel? {
        didSet {
            guard profileVM != nil else { return }
            performSearch()
        }
    }
    
    private let debounceManager = DebounceManager()
    
    private func debounceSearch() {
        debounceManager.debounce(delay: 0.5) { [weak self] in
            self?.performSearch()
        }
    }
    
    private func performSearch() {
        Task { @MainActor in
            await searchShows(query: searchText)
        }
    }
    
    private func searchShows(query: String, filterFollowedFeeds: Bool = true) async {
        isSearching = true
        defer { isSearching = false }

        guard let feedService = feedService else { return }
        guard let profileVM = profileVM else { return }
        
        let allResults = await feedService.searchShows(query: query)
        if filterFollowedFeeds {
            let followedFeedIds = Set(profileVM.followedFeeds.map { $0.feed.id })
            searchResults = allResults.filter { !followedFeedIds.contains($0.id) }
        } else {
            searchResults = allResults
        }
    }
}


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
