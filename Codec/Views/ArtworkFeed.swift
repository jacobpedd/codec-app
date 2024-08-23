import SwiftUI

struct ArtworkFeed: View {
    @ObservedObject var categoryFeedVM: CategoryFeedViewModel
    
    @EnvironmentObject private var playerVM: PlayerViewModel
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var artworkVM: ArtworkViewModel
    @State private var dragOffset: CGPoint = .zero
    @State private var dragDirection: DragDirection = .none
    @State private var isConfirmed: Bool = false
    @Namespace private var animation
    @State private var isPlayerShowing: Bool = false
    @State private var isAnimating: Bool = false
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.9
    private var cardHeight: CGFloat { cardWidth + 25 }
    private var cardSize: CGSize { CGSize(width: cardWidth, height: cardHeight) }
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    enum DragDirection {
        case vertical, horizontal, none
    }
    
    init(categoryFeedVM: CategoryFeedViewModel) {
        self.categoryFeedVM = categoryFeedVM
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            ForEach(categoryFeedVM.clips.indices, id: \.self) { index in
                let offset = index - categoryFeedVM.nowPlayingIndex
                ZStack {
                    ClipCardView(categoryFeedVM: categoryFeedVM, index: index, cardSize: cardSize, labelOpacity: labelOpacity(for: offset))
                        .matchedGeometryEffect(id: categoryFeedVM.clips[index].id, in: animation)
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
            
            VStack {
                progressiveBlurView(startPoint: .top, endPoint: .bottom)
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.3)) {
                            playerVM.previous()
                        }
                    }
                Spacer()
                    .frame(height: cardSize.height)
                progressiveBlurView(startPoint: .bottom, endPoint: .top)
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.3)) {
                            playerVM.next()
                        }
                    }
            }
            .zIndex(2000)
        }
        .animation(.easeInOut, value: categoryFeedVM.nowPlayingIndex)
        .animation(.easeInOut, value: categoryFeedVM.clips)
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
                        dragOffset = CGPoint(x: max(min(translation.width, cardSize.width), -cardSize.width), y: 0)
                    case .vertical:
                        dragOffset = CGPoint(x: 0, y: max(min(translation.height, cardSize.height), -cardSize.height))
                    case .none:
                        break
                    }
                    
                    checkConfirmationPoint()
                }
                .onEnded { value in
                    guard !isAnimating else { return }
                    
                    withAnimation(.easeIn(duration: 0.3)) {
                        if dragDirection == .vertical {
                            if dragOffset.y > cardSize.height / 2 {
                                playerVM.previous()
                            } else if dragOffset.y < -cardSize.height / 2 {
                                playerVM.next()
                            }
                        } else if dragDirection == .horizontal && isConfirmed {
                            let isInterested = dragOffset.x > 0
                            if let nowPlaying = playerVM.nowPlaying {
                                Task {
                                    await profileVM.followShow(feed: nowPlaying.feedItem.feed, isInterested: isInterested)
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
    
    private func verticalOffset(for offset: Int) -> Double {
        guard dragDirection == .vertical else { return CGFloat(offset) * cardSize.height }
        let baseOffset = CGFloat(offset) * cardSize.height
        return baseOffset + dragOffset.y
    }
    
    private func horizontalOffset(for offset: Int) -> Double {
        guard dragDirection == .horizontal && offset == 0 else { return 0 }
        return dragOffset.x
    }
    
    private func checkConfirmationPoint() {
        let wasConfirmed = isConfirmed
        isConfirmed = abs(dragDirection == .horizontal ? dragOffset.x : dragOffset.y) >= cardSize.width / 2
        
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
            let effect = abs(dragOffset.y / cardSize.height)
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
            let effect = abs(dragOffset.y / cardSize.height)
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
                    let index = categoryFeedVM.nowPlayingIndex + offset
                    if index >= 0 && index < categoryFeedVM.clips.count {
                        ArtworkView(feed: categoryFeedVM.clips[index].feedItem.feed)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .blur(radius: 50)
                            .opacity(self.imageOpacity(for: offset))
                            .animation(.easeInOut, value: dragOffset)
                    }
                }
                
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
            .contentShape(Rectangle())
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
                        VStack(alignment: .trailing, spacing: 10) {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.white)
                                .font(.system(size: 32))
                            Text("Block Show")
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding()
                    } else if dragOffset.x > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.system(size: 32))
                            Text("Follow Show")
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(feedbackOpacity)
    }
    
    private var feedbackColor: Color {
        guard dragDirection == .horizontal else { return .clear }
        return dragOffset.x > 0 ? .green : .red
    }
    
    private var feedbackOpacity: Double {
        guard dragDirection == .horizontal else { return 0 }
        return isConfirmed ? 1.0 : min(abs(dragOffset.x) / (cardSize.width / 2), 0.8)
    }
}
