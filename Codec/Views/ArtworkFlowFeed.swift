import SwiftUI

struct ArtworkFlowFeed: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var dragPercentage: CGFloat = 0
    private let maxDragOffset = 150.0
    private let cardSizePercentage: CGFloat = 0.35
    
    var artwork: Artwork? {
        return feedModel.feedArtworks[feedModel.feed[feedModel.nowPlayingIndex].feedItem.feed.id]
    }
    
    var body: some View {
        GeometryReader { geo in
            let cardSize = geo.size.height * cardSizePercentage
            
            ZStack {
                backgroundView
                    .frame(width: geo.size.width, height: geo.size.height)
                
                if feedModel.feed.count > 0 {
                    feedContent(in: geo, cardSize: cardSize)
                } else {
                    emptyFeedView
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .edgesIgnoringSafeArea(.all)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragPercentage = value.translation.height / maxDragOffset
                    dragPercentage = max(-1, min(1, dragPercentage))
                }
                .onEnded { value in
                    handleSwipe(dragPercentage: dragPercentage)
                    withAnimation(.smooth()) {
                        dragPercentage = 0
                    }
                }
        )
    }
    
    private func feedContent(in geo: GeometryProxy, cardSize: CGFloat) -> some View {
        GeometryReader { innerGeo in
            VStack(spacing: 0) {
                cardsStack(in: geo, cardSize: cardSize)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    private func cardsStack(in geo: GeometryProxy, cardSize: CGFloat) -> some View {
        VStack {
            ForEach(feedModel.feed.indices, id: \.self) { index in
                if abs(index - feedModel.nowPlayingIndex) < 5 {
                    cardView(for: index, in: geo, cardSize: cardSize)
                        .transition(.opacity)
                }
            }
        }
    }
    
    private func cardView(for index: Int, in geo: GeometryProxy, cardSize: CGFloat) -> some View {
        let zIndex = Double(feedModel.feed.count - abs(feedModel.nowPlayingIndex - index))
        return HStack {
            Spacer()
            VStack {
                ClipCardView(index: index, cardSize: cardSize, labelOpacity: 1.0)
                    .rotation3DEffect(
                        .degrees(rotation(for: index)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .center,
                        perspective: 0.3
                    )
                    .scaleEffect(scale(for: index))
                    .offset(y: yOffset(for: index))
            }
            Spacer()
        }
        .zIndex(zIndex)
        .frame(width: geo.size.width, height: apparentHeight(for: index, cardSize: cardSize))
    }
    
    private func rotation(for index: Int) -> Double {
        let maxRotation = 45.0
        if index == feedModel.nowPlayingIndex {
            return maxRotation * Double(dragPercentage)
        } else if (index == feedModel.nowPlayingIndex - 1 && dragPercentage > 0) {
            return -maxRotation * (1 - Double(dragPercentage))
        } else if (index == feedModel.nowPlayingIndex + 1 && dragPercentage < 0) {
            return maxRotation * (1 + Double(dragPercentage))
        } else if index < feedModel.nowPlayingIndex {
            return -1 * maxRotation
        } else {
            return maxRotation
        }
    }
    
    private func scale(for index: Int) -> Double {
        let selectedScale = 1.0
        let bgScale = 0.6
        if index == feedModel.nowPlayingIndex {
            return selectedScale - ((selectedScale - bgScale) * abs(dragPercentage))
        } else if (index == feedModel.nowPlayingIndex - 1 && dragPercentage > 0) {
            return bgScale + ((selectedScale - bgScale) * abs(dragPercentage))
        } else if (index == feedModel.nowPlayingIndex + 1 && dragPercentage < 0) {
            return bgScale + ((selectedScale - bgScale) * abs(dragPercentage))
        } else {
            return bgScale
        }
    }
    
    private func yOffset(for index: Int) -> Double {
        if (index == feedModel.nowPlayingIndex) {
            return CGFloat(dragPercentage) * maxDragOffset
        } else if (index == feedModel.nowPlayingIndex - 1 && dragPercentage > 0) {
            return CGFloat(dragPercentage) * maxDragOffset
        } else if (index == feedModel.nowPlayingIndex + 1 && dragPercentage < 0) {
            return CGFloat(dragPercentage) * maxDragOffset
        } else {
            return 0
        }
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
    
    private var emptyFeedView: some View {
        Text("No clips available")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }
    
    private func apparentHeight(for index: Int, cardSize: CGFloat) -> CGFloat {
        index == feedModel.nowPlayingIndex ? cardSize * 1.2 : cardSize / 5
    }
    
    private func handleSwipe(dragPercentage: CGFloat) {
        if abs(dragPercentage) > 0.5 {
            withAnimation(.easeInOut(duration: 0.3)) {
                if dragPercentage > 0 {
                    feedModel.previous()
                } else {
                    feedModel.next()
                }
            }
        }
    }
}

