import SwiftUI

struct ArtworkFeed: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var dragOffset: CGFloat = 0
    @Namespace private var animation
    
    private let cardSize: CGFloat = UIScreen.main.bounds.width * 0.8
    
    var body: some View {
        ZStack {
            backgroundView
            
            ForEach(feedModel.feed.indices, id: \.self) { index in
                let offset = index - feedModel.nowPlayingIndex
                if abs(offset) <= 2 {
                    ClipCardView(index: index, cardSize: cardSize, labelOpacity: labelOpacity(for: offset))
                        .matchedGeometryEffect(id: feedModel.feed[index].id, in: animation)
                        .scaleEffect(scale(for: offset))
                        .offset(y: self.yOffset(for: offset))
                        .zIndex(Double(1000 - abs(offset)))
                }
            }
            
            VStack {
                progressiveBlurView(startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                    .onTapGesture { feedModel.previous() }
                Spacer()
                progressiveBlurView(startPoint: .bottom, endPoint: .top)
                    .frame(height: 150)
                    .onTapGesture { feedModel.next() }
            }
            .zIndex(2000)
        }
        .animation(.easeInOut, value: feedModel.nowPlayingIndex)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = max(min(value.translation.height, cardSize), -1 * (cardSize))
                }
                .onEnded { value in
                    withAnimation(.easeInOut) {
                        if dragOffset > cardSize / 2 {
                            feedModel.previous()
                        } else if dragOffset < -cardSize / 2 {
                            feedModel.next()
                        }
                        dragOffset = 0
                    }
                }
        )
        .edgesIgnoringSafeArea(.all)
    }
    
    private func yOffset(for offset: Int) -> Double {
        let baseOffset = CGFloat(offset) * (cardSize)
        return baseOffset + max(min(dragOffset, cardSize), -1 * (cardSize))
    }
    
    private func scale(for offset: Int) -> Double {
        let maxScale = 1.0
        let minScale = 0.8
        if dragOffset == 0 {
            return offset == 0 ? 1.0 : 0.8
        } else {
            let effect = abs(dragOffset / cardSize)
            if (offset == -1 && dragOffset > 0) || (offset == 1 && dragOffset < 0) {
                return minScale + (maxScale - minScale) * effect
            } else if offset == 0 {
                return maxScale - (maxScale - minScale) * effect
            } else {
                return 0.8
            }
        }
    }
    
    private func labelOpacity(for offset: Int) -> Double {
        if dragOffset == 0 {
            return offset == 0 ? 1.0 : 0.0
        } else {
            let effect = abs(dragOffset / cardSize)
            if (offset == -1 && dragOffset > 0) || (offset == 1 && dragOffset < 0) {
                return 1.0 * effect
            } else if offset == 0 {
                return 1.0 - 1.0 * effect
            } else {
                return 0
            }
        }
    }
}

extension ArtworkFeed {
    private var backgroundView: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(-1...1, id: \.self) { offset in
                    let index = feedModel.nowPlayingIndex + offset
                    if index >= 0 && index < feedModel.feed.count,
                       let image = feedModel.feedArtworks[feedModel.feed[index].feedItem.feed.id]?.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .blur(radius: 50)
                            .opacity(self.imageOpacity(for: offset))
                            .animation(.easeInOut, value: dragOffset)
                    }
                }
                
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        }
    }
    
    private func imageOpacity(for offset: Int) -> Double {
        // NOTE: This actually seems like it does the right thing
        return labelOpacity(for: offset)
    }
    
    private func progressiveBlurView(startPoint: UnitPoint, endPoint: UnitPoint) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.black.opacity(0)]),
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
    }
}
