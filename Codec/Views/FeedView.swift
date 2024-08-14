import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var showProfile: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                ZStack {
                    ArtworkFeed()
                    
                    VStack {
                        Spacer()
                        NowPlayingView()
                    }
                }
                .edgesIgnoringSafeArea(.top)
                
                VStack (alignment: .leading) {
                    FeedHeaderView()
                    Spacer()
                }
                
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(FeedModel())
}
