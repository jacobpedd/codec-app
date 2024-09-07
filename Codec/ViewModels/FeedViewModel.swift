//
//  FeedViewModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/21/24.
//

import SwiftUI

@MainActor
class FeedViewModel: ObservableObject {
    private let audioManager = AudioManager()
    private let excludeClipIds: [Int] = []
    var feedService: FeedService? {
        didSet {
            for (_, categoryFeedVM) in categoryFeeds {
                categoryFeedVM.feedService = feedService
            }
        }
    }
    
    @Published var currentCategory: Category? {
        didSet {
            nowPlayingIndex = categoryFeeds[currentCategory]?.nowPlayingIndex ?? 0
        }
    }
    @Published var categoryFeeds: [Category?: CategoryFeedViewModel] = [:]
    @Published private(set) var nowPlayingIndex: Int = 0
    
    var currentCategoryFeedVM: CategoryFeedViewModel? {
        categoryFeeds[currentCategory]
    }
    
    var currentFeed: [Clip] {
        currentCategoryFeedVM?.clips ?? []
    }

    var nowPlayingClip: Clip? {
        guard nowPlayingIndex < currentFeed.count else { return nil }
        return currentFeed[nowPlayingIndex]
    }
    
    var onFeedLoad: (() -> Void)?
    
    init() {
        self.addCategory(category: nil)
        self.categoryFeeds[nil]?.onNowPlayingIndexChanged = { [weak self] index in
            self?.nowPlayingIndex = index
        }
    }
    
    func addCategory(category: Category?) {
        self.categoryFeeds[category] = CategoryFeedViewModel(category: category)
        self.categoryFeeds[category]?.feedService = feedService
        self.categoryFeeds[category]?.onFeedLoad = {
            self.onFeedLoad?()
        }
        self.categoryFeeds[category]?.onNowPlayingIndexChanged = { [weak self] index in
            self?.nowPlayingIndex = index
        }
    }
    
    func clearFeed() {
        categoryFeeds.removeAll()
        currentCategory = nil
        nowPlayingIndex = 0
    }
    
    func loadFeed() async {
        await currentCategoryFeedVM?.loadFeed()
    }
    
    func moveClips(from source: IndexSet, to destination: Int) {
        currentCategoryFeedVM?.moveClips(from: source, to: destination)
    }
    
    func deleteClip(at index: Int) async {
        await currentCategoryFeedVM?.deleteClip(at: index)
    }
    
    // WARNING: These move functions should only ever be called from playerVM
    func moveToNextClip() { currentCategoryFeedVM?.moveToNextClip() }
    func moveToPreviousClip() { currentCategoryFeedVM?.moveToPreviousClip() }
    func moveToIndex(index: Int) { currentCategoryFeedVM?.moveToIndex(index: index) }
}

@MainActor
class CategoryFeedViewModel: ObservableObject {
    var category: Category?
    private let audioManager = AudioManager()
    var feedService: FeedService?
    var onFeedLoad: (() -> Void)?
    
    @Published private(set) var clips: [Clip] = []
    @Published private(set) var isLoading = false
    @Published private(set) var nowPlayingIndex: Int = 0 {
        didSet {
            onNowPlayingIndexChanged?(nowPlayingIndex)
            checkForMoreClips()
        }
    }
    
    var onNowPlayingIndexChanged: ((Int) -> Void)?
    var onLoadedNewClipIds: (([Int]) -> Void)?
    
    init(category: Category?) {
        self.category = category
    }
    
    func loadFeed() async {
        guard !isLoading else { return }
        guard let feedService else { return }
        isLoading = true
        
        let newClips = await feedService.loadQueue(category: category)
        print("Loaded clips for \(category?.userFriendlyName ?? "FYP"): \(newClips.count)")
        
        clips = newClips
        nowPlayingIndex = 0
        isLoading = false
        onFeedLoad?()
    }
    
    func moveToNextClip() {
        if nowPlayingIndex < clips.count - 1 {
            nowPlayingIndex += 1
        }
    }

    func moveToPreviousClip() {
        if nowPlayingIndex > 0 {
            nowPlayingIndex -= 1
        }
    }
    
    func moveToIndex(index: Int) {
        nowPlayingIndex = index
    }
    
    func checkForMoreClips() {
        if clips.count - nowPlayingIndex - 1 < 7 {
            Task {
                await loadMoreClips()
            }
        }
    }
    
    func loadMoreClips() async {
        guard !isLoading else { return }
        guard let feedService else { return }
        print("Loading more clips")
        
        await MainActor.run { isLoading = true }
        
        let newClips = await feedService.loadQueue(category: category)
        print("Loaded more clips for \(category?.userFriendlyName ?? "FYP"): \(newClips.count)")
        
        await MainActor.run {
            clips.append(contentsOf: newClips)
            isLoading = false
        }
    }
    
    func moveClips(from source: IndexSet, to destination: Int) {
        clips.move(fromOffsets: source, toOffset: destination)
        
        // Adjust nowPlayingIndex if necessary
        if let first = source.first, first <= nowPlayingIndex {
            if destination <= nowPlayingIndex {
                nowPlayingIndex += source.count
            } else {
                nowPlayingIndex -= 1
            }
        }
    }
    
    func deleteClip(at index: Int) async {
        guard index < clips.count else { return }
        
        let clipToDelete = clips[index]
        clips.remove(at: index)
        
        // Adjust nowPlayingIndex if necessary
        if index <= nowPlayingIndex {
            nowPlayingIndex = max(0, nowPlayingIndex - 1)
        }
        
        // Track 0 duration view for deleted clip
        await feedService?.updateView(clipId: clipToDelete.id, duration: 0)
        checkForMoreClips()
    }
}
