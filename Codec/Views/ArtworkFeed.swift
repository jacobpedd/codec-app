import SwiftUI

struct ArtworkFeed: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var dragOffset: CGFloat = 0
    @State private var dragDirection: DragDirection = .none
    @State private var isConfirmed: Bool = false
    @Namespace private var animation
    @State private var isPlayerShowing: Bool = false
    
    private let cardSize: CGFloat = UIScreen.main.bounds.width * 0.8
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    enum DragDirection {
        case vertical, horizontal, none
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            ForEach(feedModel.feed.indices, id: \.self) { index in
                let offset = index - feedModel.nowPlayingIndex!
                if abs(offset) <= 2 {
                    ZStack {
                        ClipCardView(isPlayerShowing: $isPlayerShowing, index: index, cardSize: cardSize, labelOpacity: labelOpacity(for: offset))
                            .matchedGeometryEffect(id: feedModel.feed[index].id, in: animation)
                            .scaleEffect(scale(for: offset))
                            .offset(x: horizontalOffset(for: offset), y: verticalOffset(for: offset))
                            .zIndex(Double(1000 - abs(offset)))
                        if offset == 0 {
                            directionFeedbackView
                        }
                    }
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
                    if dragDirection == .none {
                        dragDirection = abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
                    }
                    
                    switch dragDirection {
                    case .horizontal:
                        dragOffset = max(min(value.translation.width, cardSize), -cardSize)
                        checkConfirmationPoint()
                    case .vertical:
                        dragOffset = max(min(value.translation.height, cardSize), -cardSize)
                    case .none:
                        break
                    }
                }
                .onEnded { value in
                    withAnimation(.easeInOut) {
                        if dragDirection == .vertical {
                            if dragOffset > cardSize / 2 {
                                feedModel.previous()
                            } else if dragOffset < -cardSize / 2 {
                                feedModel.next()
                            }
                        } else if dragDirection == .horizontal && isConfirmed {
                            let isInterested = dragOffset > 0 ? true : false
                            if let nowPlaying = feedModel.nowPlaying {
                                Task {
                                    await feedModel.followShow(feed: nowPlaying.feedItem.feed, isInterested: isInterested)
                                }
                            }
                        }
                        dragOffset = 0
                        dragDirection = .none
                        isConfirmed = false
                    }
                }
        )
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: $isPlayerShowing) {
            NowPlayingSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(25)
                .presentationBackground(.clear)
        }
    }
    
    private func verticalOffset(for offset: Int) -> Double {
        guard dragDirection == .vertical else { return CGFloat(offset) * cardSize }
        let baseOffset = CGFloat(offset) * cardSize
        return baseOffset + dragOffset
    }
    
    private func horizontalOffset(for offset: Int) -> Double {
        guard dragDirection == .horizontal && offset == 0 else { return 0 }
        return dragOffset
    }
    
    private func checkConfirmationPoint() {
        let wasConfirmed = isConfirmed
        isConfirmed = abs(dragOffset) >= cardSize / 2
        
        if isConfirmed && !wasConfirmed {
            impactFeedback.impactOccurred()
        }
    }
    
    private func scale(for offset: Int) -> Double {
        let maxScale = 1.0
        let minScale = 0.8
        if dragOffset == 0 || dragDirection == .horizontal {
            return offset == 0 ? 1.0 : 0.8
        } else {
            let effect = abs(dragOffset / cardSize)
            if (((offset == -1 && dragOffset > 0) || (offset == 1 && dragOffset < 0))  && dragDirection == .vertical) {
                return minScale + (maxScale - minScale) * effect
            } else if offset == 0 {
                return maxScale - (maxScale - minScale) * effect
            } else {
                return 0.8
            }
        }
    }
    
    private func labelOpacity(for offset: Int) -> Double {
        if dragOffset == 0 || dragDirection == .horizontal {
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
                    let index = feedModel.nowPlayingIndex! + offset
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

extension ArtworkFeed {
    private var directionFeedbackView: some View {
        ZStack {
            Rectangle()
                .fill(feedbackColor)
            HStack(alignment: .center) {
                if dragDirection == .horizontal {
                    if dragOffset < 0 {
                        Spacer()
                        VStack(alignment: dragOffset > 0 ? .leading : .trailing, spacing: 10) {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.white)
                                .font(.system(size: 32))
                            Text("Block Show")
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .multilineTextAlignment(dragOffset > 0 ? .leading : .trailing)
                        }
                        .padding()
                    } else if dragOffset > 0 {
                        VStack(alignment: dragOffset > 0 ? .leading : .trailing, spacing: 10) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.system(size: 32))
                            Text("Follow Show")
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .multilineTextAlignment(dragOffset > 0 ? .leading : .trailing)
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
        }
        .frame(width: cardSize, height: cardSize)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(feedbackOpacity)
    }
    
    private var feedbackColor: Color {
        guard dragDirection == .horizontal else { return .clear }
        return dragOffset > 0 ? .green : .red
    }
    
    private var feedbackOpacity: Double {
        guard dragDirection == .horizontal else { return 0 }
        return isConfirmed ? 1.0 : min(abs(dragOffset) / (cardSize / 2), 0.8)
    }
}
