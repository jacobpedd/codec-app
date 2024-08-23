//
//  ProfileViewModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/20/24.
//

import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var followedFeeds: [UserFeedFollow] = [] {
        willSet {
            objectWillChange.send()
        }
    }
    @Published var isUserSelecting: Bool = false
    @Published private(set) var isLoading: Bool = true
    
    var feedService: FeedService? {
        didSet {
            guard feedService != nil else { return }
            Task {
                await loadUserProfile()
            }
        }
    }
    
    init() {
        loadFollowedFeedsFromUserDefaults()
    }
    
    func followShow(feed: Feed, isInterested: Bool = true) async -> Bool {
        guard let feedService = feedService else { return false }
        let success = await feedService.followShow(feedId: feed.id, isInterested: isInterested)
        if success {
            await loadFollowedFeeds()
        }
        return success
    }
    
    func unfollowShow(followId: Int) async {
        guard let feedService = feedService else { return }
        let success = await feedService.unfollowShow(followId: followId)
        if success {
            await MainActor.run {
                self.followedFeeds.removeAll { $0.id == followId }
            }
            cacheFollowedFeeds()
        }
    }
    
    func clearProfile() {
        followedFeeds = []
        isLoading = true
        UserDefaults.standard.removeObject(forKey: "cachedFollowedFeeds")
    }
    
    private func loadUserProfile() async {
        await loadFollowedFeeds()
    }
    
    func loadFollowedFeeds() async {
        guard let feedService = feedService else { return }
        await MainActor.run {
            self.isLoading = true
        }
        let followedFeeds = await feedService.loadFollowedShows()
        await MainActor.run {
            print("Loaded followed feeds: \(followedFeeds.count)")
            self.followedFeeds = followedFeeds
            self.isLoading = false
        }
        cacheFollowedFeeds()
    }
    
    private func cacheFollowedFeeds() {
        do {
            let data = try JSONEncoder().encode(self.followedFeeds)
            UserDefaults.standard.set(data, forKey: "cachedFollowedFeeds")
        } catch {
            print("Failed to encode followed feeds: \(error)")
        }
    }
    
    private func loadFollowedFeedsFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "cachedFollowedFeeds") {
            do {
                let feeds = try JSONDecoder().decode([UserFeedFollow].self, from: data)
                self.followedFeeds = feeds
            } catch {
                self.followedFeeds = []
                print("Failed to decode cached followed feeds: \(error)")
            }
        }
    }
}
