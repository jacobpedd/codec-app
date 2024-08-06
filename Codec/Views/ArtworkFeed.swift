import SwiftUI

struct ArtworkFeed: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var dragOffset: CGPoint = .zero
    @State private var dragDirection: DragDirection = .none
    @State private var isConfirmed: Bool = false
    @Namespace private var animation
    @State private var isPlayerShowing: Bool = false
    @State private var isAnimating: Bool = false
    
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
                        ClipCardView(index: index, cardSize: cardSize, labelOpacity: labelOpacity(for: offset))
                            .matchedGeometryEffect(id: feedModel.feed[index].id, in: animation)
                            .scaleEffect(scale(for: offset))
                            .offset(x: horizontalOffset(for: offset), y: verticalOffset(for: offset))
                            .zIndex(Double(1000 - abs(offset)))
                            .onTapGesture {
                                if offset == 0 && !isAnimating {
                                    isPlayerShowing = true
                                }
                            }
                        if offset == 0 {
                            directionFeedbackView
                        }
                    }
                }
            }
            
            VStack {
                progressiveBlurView(startPoint: .top, endPoint: .bottom)
                    .onTapGesture {
                        animateWithTracking {
                            feedModel.previous()
                        }
                    }
                Spacer()
                    .frame(height: cardSize)
                progressiveBlurView(startPoint: .bottom, endPoint: .top)
                    .onTapGesture {
                        animateWithTracking {
                            feedModel.next()
                        }
                    }
            }
            .zIndex(2000)
        }
        .animation(.easeInOut, value: feedModel.nowPlayingIndex)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let translation = value.translation
                    
                    if abs(translation.width) < 1 && abs(translation.height) < 1 {
                        dragDirection = .none
                    }
                    
                    if dragDirection == .none {
                        dragDirection = abs(translation.width) > abs(translation.height) ? .horizontal : .vertical
                    }
                    
                    guard !isAnimating else { return }
                    
                    switch dragDirection {
                    case .horizontal:
                        dragOffset = CGPoint(x: max(min(translation.width, cardSize), -cardSize), y: 0)
                    case .vertical:
                        dragOffset = CGPoint(x: 0, y: max(min(translation.height, cardSize), -cardSize))
                    case .none:
                        break
                    }
                    
                    checkConfirmationPoint()
                }
                .onEnded { value in
                    guard !isAnimating else { return }
                    
                    animateWithTracking {
                        if dragDirection == .vertical {
                            if dragOffset.y > cardSize / 2 {
                                feedModel.previous()
                            } else if dragOffset.y < -cardSize / 2 {
                                feedModel.next()
                            }
                        } else if dragDirection == .horizontal && isConfirmed {
                            let isInterested = dragOffset.x > 0
                            if let nowPlaying = feedModel.nowPlaying {
                                Task {
                                    await feedModel.followShow(feed: nowPlaying.feedItem.feed, isInterested: isInterested)
                                }
                            }
                        }
                        dragOffset = .zero
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
    
    private func animateWithTracking(_ action: @escaping () -> Void) {
        if !isAnimating {
            let duration = 0.3
            withAnimation(.easeInOut(duration: duration)) {
                isAnimating = true
                action()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                isAnimating = false
            }
        }
    }
    
    private func verticalOffset(for offset: Int) -> Double {
        guard dragDirection == .vertical else { return CGFloat(offset) * cardSize }
        let baseOffset = CGFloat(offset) * cardSize
        return baseOffset + dragOffset.y
    }
    
    private func horizontalOffset(for offset: Int) -> Double {
        guard dragDirection == .horizontal && offset == 0 else { return 0 }
        return dragOffset.x
    }
    
    private func checkConfirmationPoint() {
        let wasConfirmed = isConfirmed
        isConfirmed = abs(dragDirection == .horizontal ? dragOffset.x : dragOffset.y) >= cardSize / 2
        
        if isConfirmed && !wasConfirmed {
            impactFeedback.impactOccurred()
        }
    }
    
    private func scale(for offset: Int) -> Double {
        let maxScale = 1.0
        let minScale = 0.8
        if dragOffset == .zero || dragDirection == .horizontal {
            return offset == 0 ? 1.0 : 0.8
        } else {
            let effect = abs(dragOffset.y / cardSize)
            if (((offset == -1 && dragOffset.y > 0) || (offset == 1 && dragOffset.y < 0))  && dragDirection == .vertical) {
                return minScale + (maxScale - minScale) * effect
            } else if offset == 0 {
                return maxScale - (maxScale - minScale) * effect
            } else {
                return 0.8
            }
        }
    }
    
    private func labelOpacity(for offset: Int) -> Double {
        if dragOffset == .zero || dragDirection == .horizontal {
            return offset == 0 ? 1.0 : 0.0
        } else {
            let effect = abs(dragOffset.y / cardSize)
            if (offset == -1 && dragOffset.y > 0) || (offset == 1 && dragOffset.y < 0) {
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
        return labelOpacity(for: offset)
    }
    
    private func progressiveBlurView(startPoint: UnitPoint, endPoint: UnitPoint) -> some View {
        Rectangle()
            .fill(.thinMaterial)
            .mask(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.black.opacity(0), Color.black.opacity(0)]),
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
                    if dragOffset.x < 0 {
                        Spacer()
                        VStack(alignment: dragOffset.x > 0 ? .leading : .trailing, spacing: 10) {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.white)
                                .font(.system(size: 32))
                            Text("Block Show")
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .multilineTextAlignment(dragOffset.x > 0 ? .leading : .trailing)
                        }
                        .padding()
                    } else if dragOffset.x > 0 {
                        VStack(alignment: dragOffset.x > 0 ? .leading : .trailing, spacing: 10) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.system(size: 32))
                            Text("Follow Show")
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .multilineTextAlignment(dragOffset.x > 0 ? .leading : .trailing)
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
        return dragOffset.x > 0 ? .green : .red
    }
    
    private var feedbackOpacity: Double {
        guard dragDirection == .horizontal else { return 0 }
        return isConfirmed ? 1.0 : min(abs(dragOffset.x) / (cardSize / 2), 0.8)
    }
}
