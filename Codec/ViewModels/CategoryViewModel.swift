//
//  CategoryViewModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/20/24.
//

import SwiftUI

protocol CategoryViewModelDelegate: AnyObject {
    func categoryViewModel(_ viewModel: CategoryViewModel, didUpdateUserCategories categories: [Category])
}

@MainActor
class CategoryViewModel: ObservableObject {
    weak var delegate: CategoryViewModelDelegate?
    
    var feedService: FeedService? {
        didSet {
            guard feedService != nil else { return }
            Task {
                await loadUserCategories()
                await loadAllCategories()
            }
        }
    }
    
    @Published private(set) var userCategories: [Category] = []
    @Published private(set) var allCategories: [Category] = []
    @Published private(set) var isLoading: Bool = true
    @Published var isUserSelecting: Bool = false
    
    private var userCategoryScores: [UserCategoryScore] = []
    
    init() {
        loadUserCategoryScoresFromUserDefaults()
        loadAllCategoriesFromUserDefaults()
    }
    
    func removeUserCategory(category: Category) async {
        guard let feedService = feedService else { return }
        guard let score = userCategoryScores.first(where: { $0.category.id == category.id }) else { return }
        let success = await feedService.deleteUserCategoryScore(categoryScoreId: score.id)
        if success {
            await loadUserCategories()
        }
    }
    
    func addUserCategory(category: Category) async {
        guard let feedService = feedService else { return }
        let success = await feedService.updateUserCategoryScore(categoryId: category.id, score: 1.0)
        if success {
            await loadUserCategories()
        }
    }
    
    private func loadUserCategories() async {
        guard let feedService else { return }
        await MainActor.run {
            self.isLoading = true
        }
        let scores = await feedService.getUserCategoryScores()
        
        await MainActor.run {
            self.userCategoryScores = scores
            self.userCategories = scores.map { $0.category }
            self.isLoading = false
            self.delegate?.categoryViewModel(self, didUpdateUserCategories: self.userCategories)
        }
        
        do {
            let data = try JSONEncoder().encode(self.userCategoryScores)
            UserDefaults.standard.set(data, forKey: "cachedUserCategoryScores")
        } catch {
            print("Failed to encode user categories: \(error)")
        }
    }
    
    func clearUserCategories() {
        userCategories = []
        userCategoryScores = []
        UserDefaults.standard.removeObject(forKey: "cachedUserCategoryScores")
        delegate?.categoryViewModel(self, didUpdateUserCategories: [])
        isLoading = true
    }
    
    private func loadUserCategoryScoresFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "cachedUserCategoryScores") {
            do {
                let scores = try JSONDecoder().decode([UserCategoryScore].self, from: data)
                self.userCategoryScores = scores
                self.userCategories = scores.map { $0.category }
                delegate?.categoryViewModel(self, didUpdateUserCategories: self.userCategories)
            } catch {
                self.userCategories = []
            }
        }
    }
    
    private func loadAllCategories() async {
        guard let feedService else { return }
        await MainActor.run {
            self.isLoading = true
        }
        let categories = await feedService.loadCategories()
        
        await MainActor.run {
            self.allCategories = categories
            self.isLoading = false
        }
        
        do {
            let data = try JSONEncoder().encode(self.allCategories)
            UserDefaults.standard.set(data, forKey: "cachedCategories")
        } catch {
            print("Failed to encode categories: \(error)")
        }
    }
    
    private func loadAllCategoriesFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "cachedCategories") {
            do {
                let categories = try JSONDecoder().decode([Category].self, from: data)
                print("categories in cache: \(categories.count)")
                self.allCategories = categories
            } catch {
                self.allCategories = []
            }
        }
    }
}
