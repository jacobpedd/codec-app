import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var showProfile: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                GeometryReader { geometry in
                    ZStack {
                        ArtworkFeed()
                        
                        VStack {
                            Spacer()
                            NowPlayingView()
                        }
                    }
                }
                .edgesIgnoringSafeArea(.top)
                
                VStack {
                    ZStack {
                        // Tappable area for previous action
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                feedModel.previous()
                            }
                        
                        // Profile button
                        HStack {
                            Spacer()
                            NavigationLink(destination: ProfileView().environmentObject(feedModel)) {
                                Image(systemName: "person.crop.circle")
                                    .imageScale(.large)
                                    .foregroundColor(.primary)
                                    .padding()
                            }
                            .padding(.trailing, 5)
                        }
                    }
                    .frame(height: 44)
                    
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
