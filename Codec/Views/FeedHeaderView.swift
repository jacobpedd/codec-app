//
//  FeedHeaderView.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/14/24.
//

import SwiftUI

struct CategoryButton: View {
    let category: Category?
    let action: () -> Void
    
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var categoryVM: CategoryViewModel
    @State private var isActive: Bool = false
    
    private var labelText: String {
        return category?.name ?? "For You"
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(labelText)
                    .font(.system(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(isActive ? .primary : .secondary)
                    .padding(.vertical, 12)
                
                Rectangle()
                    .fill(isActive ? .primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .onAppear {
            updateActiveState()
        }
        .onChange(of: feedVM.currentCategory) {
            updateActiveState()
        }
    }
    
    private func updateActiveState() {
        if feedVM.currentCategory == nil && category == nil {
            self.isActive = true
        } else {
            self.isActive = feedVM.currentCategory == category
        }
    }
}

struct ScrollableCategoryList: View {
    @EnvironmentObject var categoryVM: CategoryViewModel
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // For you button
                    CategoryButton(category: nil) {
                        withAnimation {
                            reader.scrollTo("For You", anchor: .center)
                            if feedVM.currentCategory != nil {
                                feedVM.currentCategory = nil
                                playerVM.updateNowPlaying()
                            } else {
                                playerVM.setIndex(index: 0)
                            }
                        }
                    }
                    .id("For You")
                    
                    if categoryVM.isLoading == true && categoryVM.userCategories.isEmpty {
                        // Category loader
                        ProgressView()
                    } else {
                        // Category buttons
                        ForEach(categoryVM.userCategories) { category in
                            CategoryButton(category: category) {
                                withAnimation {
                                    reader.scrollTo(category.id, anchor: .center)
                                    if feedVM.currentCategory != category {
                                        feedVM.currentCategory = category
                                        playerVM.updateNowPlaying()
                                    } else {
                                        playerVM.setIndex(index: 0)
                                    }
                                }
                            }
                            .id(category.id)
                        }
                    }
                    Spacer()
                        .frame(width: 20, height: 20)
                }
            }
            .mask(
                LinearGradient(gradient: Gradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.88),
                    .init(color: .clear, location: 0.92)
                ]), startPoint: .leading, endPoint: .trailing)
            )
        }
        .padding(.horizontal)
    }
}

struct ProfileIconLink: View {
    var body: some View {
        HStack {
            Spacer()
            NavigationLink(destination: ProfileView()) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
    }
}

struct FeedHeaderView: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ScrollableCategoryList()
                ProfileIconLink()
            }
            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .contentShape(Rectangle()) // Capture all taps
        .onTapGesture { }
        .background(.thinMaterial)
    }
}


#Preview {
    return NavigationStack {
        VStack {
            FeedHeaderView()
            Spacer()
        }
    }
    .previewWithEnvironment()
}
