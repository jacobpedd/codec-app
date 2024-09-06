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
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(categories.indices, id: \.self) { index in
                            Group {
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
                            // NOTE: This is a total hack, I double space the feeds
                            // because otherwise the scroll view interfere with eachother
                            Spacer()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    // NOTE: See the above note for why there is a * 2
                    .offset(x: geometry.size.width * CGFloat(currentPage) * -1 * 2)
                }
                .ignoresSafeArea()
                
                // Now playing pill
                VStack {
                    Spacer()
                    if playerVM.nowPlaying != nil {
                        NowPlayingView()
                    }
                }
                
                // Feed header
                VStack (alignment: .leading) {
                    FeedHeaderView()
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: feedVM.currentCategory) {
            if let index = categories.firstIndex(where: { $0?.id == feedVM.currentCategory?.id }) {
                currentPage = index
            } else {
                print("Nil page or not found")
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
