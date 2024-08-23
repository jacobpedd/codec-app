//
//  AppCoordinator.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/20/24.
//

import SwiftUI

class AppCoordinator: ObservableObject {
    private let debug: Bool
    private var feedService: FeedService?

    @Published var playerVM: PlayerViewModel
    @Published var feedVM: FeedViewModel
    @Published var userVM: UserViewModel
    @Published var profileVM: ProfileViewModel
    @Published var categoryVM: CategoryViewModel
    @Published var artworkVM: ArtworkViewModel
    @Published var feedSearchVM: FeedSearchViewModel

    init(debug: Bool = false) {
        self.debug = debug
        
        let cache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: "imageCache")
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: config)
        
        self.playerVM = PlayerViewModel()
        self.feedVM = FeedViewModel()
        self.userVM = UserViewModel()
        self.categoryVM = CategoryViewModel()
        self.artworkVM = ArtworkViewModel(session: session)
        self.profileVM = ProfileViewModel()
        self.feedSearchVM = FeedSearchViewModel()

        updateFeedService(with: self.userVM.token)
        setupDependencies()
    }

    private func setupDependencies() {
        playerVM.artworkVM = artworkVM
        feedSearchVM.profileVM = profileVM
        playerVM.feedVM = feedVM
        
        categoryVM.delegate = self
        
        userVM.onLogin = { [weak self] newToken in
            self?.updateFeedService(with: newToken)
        }
        
        userVM.onLogout = { [weak self] in
            self?.updateFeedService(with: nil)
            self?.categoryVM.clearUserCategories()
            self?.profileVM.clearProfile()
            self?.feedSearchVM.searchText = ""
            self?.feedVM.clearFeed()
            self?.playerVM.clearPlayer()
            
        }
        
        feedVM.onFeedLoad = { [weak self] in
            self?.playerVM.updateNowPlaying()
        }
        
        Task {
            await feedVM.loadFeed()
        }
    }
    
    private func updateFeedService(with token: String?) {
        if let token {
            if let existingService = feedService {
                existingService.token = token
            } else {
                feedService = FeedService(token: token, debug: self.debug)
            }
        } else {
            feedService = nil
        }
        
        playerVM.feedService = feedService
        feedVM.feedService = feedService
        categoryVM.feedService = feedService
        profileVM.feedService = feedService
        feedSearchVM.feedService = feedService
    }
    
    private func syncCategories(_ categories: [Category]) {
        let categoryIds = Set(categories.map { $0.id })
        feedVM.categoryFeeds = feedVM.categoryFeeds.filter { $0.key == nil || categoryIds.contains($0.key!.id) }
        
        for category in categories {
            if feedVM.categoryFeeds[category] == nil {
                feedVM.addCategory(category: category)
            }
        }
        
        if let currentCategory = feedVM.currentCategory, !categoryIds.contains(currentCategory.id) {
            feedVM.currentCategory = nil
        }
    }
}

extension AppCoordinator: CategoryViewModelDelegate {
    func categoryViewModel(_ viewModel: CategoryViewModel, didUpdateUserCategories categories: [Category]) {
        syncCategories(categories)
    }
}

extension View {
    func withAppEnvironment(_ coordinator: AppCoordinator) -> some View {
        self
            .environmentObject(coordinator.playerVM)
            .environmentObject(coordinator.feedVM)
            .environmentObject(coordinator.userVM)
            .environmentObject(coordinator.profileVM)
            .environmentObject(coordinator.categoryVM)
            .environmentObject(coordinator.artworkVM)
            .environmentObject(coordinator.feedSearchVM)
    }
}

@ViewBuilder
func PreviewWithEnvironment<Content: View>(_ content: @escaping () -> Content) -> some View {
    let coordinator = AppCoordinator()
    content()
        .withAppEnvironment(coordinator)
}

private struct PreviewWithEnvironmentModifier: ViewModifier {
    @StateObject private var coordinator = AppCoordinator(debug: true)
    
    func body(content: Content) -> some View {
        content
            .withAppEnvironment(coordinator)
    }
}

extension View {
    func previewWithEnvironment() -> some View {
        modifier(PreviewWithEnvironmentModifier())
    }
}
