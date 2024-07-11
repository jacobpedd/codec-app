import SwiftUI
import SwiftUIX

struct ArtworkScrollFeed: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var contentOffset: CGPoint = .zero
    @State private var isInitialAppearance = true
    @State private var cardCenters: [Int: CGFloat] = [:]
    
    private let cardSize: CGFloat = UIScreen.main.bounds.width * 0.8
    private var verticalPadding: CGFloat { (UIScreen.main.bounds.height - cardSize) / 2 }
    
    var artwork: Artwork? {
        return feedModel.feedArtworks[feedModel.feed[feedModel.nowPlayingIndex].feedItem.feed.id]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundView
                    .frame(width: geo.size.width, height: geo.size.height)
                
                if feedModel.feed.isEmpty {
                    Text("No clips available")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.gray.opacity(0.1))
                } else {
                    scrollContent
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private var scrollContent: some View {
        CocoaScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(feedModel.feed.indices, id: \.self) { index in
                    cardView(for: index)
                }
            }
            .frame(width: UIScreen.main.bounds.width)
            .padding(.vertical, verticalPadding)
        }
        .decelerationRate(.fast)
        .contentOffset($contentOffset)
        .onDragEnd { handleDragEnd() }
        .onAppear(perform: handleAppear)
        .onChange(of: feedModel.nowPlayingIndex) { scrollToCurrentIndex() }
    }
    
    private var backgroundView: some View {
        GeometryReader { geo in
            ZStack {
                if let image = artwork?.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 50)
                } else {
                    Color.gray
                }
                
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: artwork?.image)
    }
    
    private func cardView(for index: Int) -> some View {
        GeometryReader { geo in
            HStack {
                Spacer()
                ClipCardView(index: index, cardSize: cardSize, labelOpacity: labelOpacity(for: index, centerY: geo.frame(in: .global).midY))
                    .frame(height: cardSize)
                    .scaleEffect(scale(for: index, centerY: geo.frame(in: .global).midY))
                Spacer()
            }
            .onChange(of: geo.frame(in: .global).minY) {
                cardCenters[index] = geo.frame(in: .global).midY
            }
        }
        .frame(height: cardSize)
    }
    
    private func handleDragEnd() {
        let screenMidY = UIScreen.main.bounds.height / 2
        let closestIndex = cardCenters.min(by: { abs($0.value - screenMidY) < abs($1.value - screenMidY) })?.key ?? 0
        feedModel.nowPlayingIndex = closestIndex
        scrollToCurrentIndex()
    }
    
    private func handleAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToCurrentIndex()
        }
    }
    
    private func scrollToCurrentIndex() {
        let yOffset = CGFloat(feedModel.nowPlayingIndex) * cardSize
        let animation = isInitialAppearance ? nil : Animation.easeInOut(duration: 0.3)
        
        withAnimation(animation) {
            contentOffset = CGPoint(x: 0, y: yOffset)
        }
        
        isInitialAppearance = false
    }
    
    private func scale(for index: Int, centerY: CGFloat) -> CGFloat {
        guard let cardCenter = cardCenters[index] else { return 1.0 }
        
        let distanceFromCenter = abs(UIScreen.main.bounds.height / 2 - cardCenter)
        let effect = distanceFromCenter / (cardSize / 2)
        return 1.0 - (0.2 * min(effect, 1.0))
    }
    
    private func labelOpacity(for index: Int, centerY: CGFloat) -> CGFloat {
        guard let cardCenter = cardCenters[index] else { return 1.0 }
        
        let distanceFromCenter = abs(UIScreen.main.bounds.height / 2 - cardCenter)
        let effect = distanceFromCenter / (cardSize / 2)
        return 1.0 - effect
    }
}
