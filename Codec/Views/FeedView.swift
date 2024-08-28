import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var playerVM: PlayerViewModel
    @EnvironmentObject private var feedVM: FeedViewModel
    @EnvironmentObject private var categoryVM: CategoryViewModel
    
    @State private var currentPage = 0
    
    var categories: [Category?] {
        return [nil] + categoryVM.userCategories
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ZStack {
                    // Custom paged view
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            ForEach(categories.indices, id: \.self) { index in
                                let category = categories[index]
                                    if let categoryFeedVM = feedVM.categoryFeeds[category] {
                                        if !categoryFeedVM.clips.isEmpty {
                                            ArtworkFeed(categoryFeedVM: categoryFeedVM)
                                        } else {
                                            ProgressView()
                                        }
                                    } else {
                                        ProgressView()
                                            .onAppear {
                                                feedVM.addCategory(category: category)
                                            }
                                    }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                        }
                        .offset(x: -CGFloat(currentPage) * geometry.size.width)
                    }
                    .ignoresSafeArea()
                    .animation(.easeInOut, value: currentPage)
                    
                    // Now playing pill
                    VStack {
                        Spacer()
                        if playerVM.nowPlaying != nil {
                            NowPlayingView()
                        }
                    }
                }
                .edgesIgnoringSafeArea(.top)
                
                // Feed header
                VStack (alignment: .leading) {
                    FeedHeaderView()
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        
        .onAppear() {
            if feedVM.currentFeed.isEmpty {
                Task {
                    await feedVM.loadFeed()
                }
            }
        }
        .onChange(of: feedVM.currentCategory) {
            if let index = categories.firstIndex(where: { $0?.id == feedVM.currentCategory?.id }) {
                currentPage = index
            } else {
                print("Nill page or not found")
                currentPage = categories.firstIndex(of: nil) ?? 0
            }
            
            if feedVM.currentFeed.isEmpty {
                Task {
                    await feedVM.loadFeed()
                }
            }
        }
    }
}

#Preview {
    FeedView()
        .previewWithEnvironment()
}
