import SwiftUI

struct ArtworkFeed: View {
    @ObservedObject var categoryFeedVM: CategoryFeedViewModel
    
    @EnvironmentObject private var playerVM: PlayerViewModel
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var artworkVM: ArtworkViewModel
    
    var dragOffset: CGFloat {
        self.horizontalSwipeOffset?.0 ?? .zero
    }
    
    @State private var isConfirmed: Bool = false
    @Namespace private var animation
    @State private var isPlayerShowing: Bool = false
    @State private var isAnimating: Bool = false
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.9
    
    // TODO: Why +25 ?
    // private var cardHeight: CGFloat { cardWidth + 25 }
    nonisolated private var cardHeight: CGFloat { cardWidth }
    
    private var cardSize: CGSize { CGSize(width: cardWidth, height: cardHeight) }
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        
    init(categoryFeedVM: CategoryFeedViewModel) {
        self.categoryFeedVM = categoryFeedVM
    }
        
    // For programmatically scrolling to a specific item
    @State private var scrollPosition: Int? = nil
    
    // Tracks item which is currently in the center
    @State private var currentCenter: Int? = nil
    
    nonisolated static let nonCenterScale = 0.8
    
    var scrollViewHeight: CGFloat {
        // some height such that a single item can fit cleanly in the middle
        self.cardHeight * 3
    }
    
    var viewPortalHeight: CGFloat {
        // cut off half of the top-most and half of the bottom-most views
        self.scrollViewHeight - self.cardHeight
    }
    
    // (swipe offset amount, which index/card the offset is for)
    @State var horizontalSwipeOffset: (CGFloat, Int)?
    
    var body: some View {
        
        ZStack {
            backgroundView(self.currentCenter ?? 0)
            
            ScrollView(.vertical, showsIndicators: false) {
                
                // TODO: perf-wise, will VStack become okay? LazyVStack derenders the currentCenter-1 item *just if we have never scrolled*
//                LazyVStack(spacing: 0) { // Lazy = don't load item until requested
                VStack(spacing: 0) {
                    
                    ForEach(categoryFeedVM.clips.indices, id: \.self) { index in
                        childView(index)
                        
                        /*
                         Suppose we scale down non-centered items to 80% and that each item's height is 300. Thus:
                         - item's distance-from-center = 0, then scale = 1 - 0 i.e. 1.0
                         - distance = 300, then scale = 1 - 0.2 i.e. 0.8
                         - distance = 150, then scale = 1 - 0.1 i.e. 0.9
                         */
                            .visualEffect { content, proxy in
                                
                                let _distanceFromCenter = distanceFromCenter(index: index,
                                                                             for: proxy)
                                
                                let distanceRounded = _distanceFromCenter.rounded(.toNearestOrAwayFromZero)
                                let shouldOffsetUp = distanceRounded < 0
                                let shouldOffsetDown = distanceRounded > 0
                                
                                // Later calculations require absValue of distance
                                let distance = abs(_distanceFromCenter)
                                
                                let maxDistance = self.cardHeight
                                let cappedDistance = min(distance, maxDistance) // e.g. treat distances greater than 300 as simply 300
                                let percentOfMaxDistance = cappedDistance/maxDistance
                                let maxScaleReduction = 1.0 - Self.nonCenterScale // e.g. never reduce scale by more than 20%
                                let scaleReduction = maxScaleReduction * percentOfMaxDistance
                                
                                // TODO: is card offset too aggressive sometimes? e.g. when *slowly* pulling down on current card to go to card above, the card below the current card seems to move offscreen too quickly; is present in SwiftUI Playground as well.
//                                let maxOffset = self.cardHeight/1.3333333333
//                                
//                                let maxOffset = self.cardHeight/2.8
                                let maxOffset = self.cardHeight/2.5
                                let actualOffset = maxOffset * percentOfMaxDistance
                                              
                                return content
//                                    .scaleEffect(0.25) // scale down to 1/4th
                                    .scaleEffect(0.5) // scale down to 1/4th
//                                    .scaleEffect(1.0 - scaleReduction) // apply center-based scaling
                                    .offset(y: shouldOffsetUp ? (-1 * actualOffset) : 0)
                                    .offset(y: shouldOffsetDown ? actualOffset : 0)
                            }
                        
                    } // ForEach
                } // LazyVStack
            } // ScrollView
            
            // ScrollView must be height of paged-item when using `.paging` PagingScrollTargetBehavior
            .frame(width: self.cardWidth,
                   height: self.cardHeight)
            .border(.red, width: 4)
            
            .scrollTargetBehavior(.paging)
            
            // Setting ScrollView's position to some specific item
            .scrollPosition(id: self.$scrollPosition,
                            anchor: .center)
            
            // .scaleEffect(4) // Scale back up 4x
            .scaleEffect(2) // Scale back up
            
            // Change clip when ScrollView's centered-clip changes
            .onChange(of: self.currentCenter ?? 0, { oldValue, newValue in
                // print("onChange of self.currentCenter: oldValue: \(oldValue)")
                // print("onChange of self.currentCenter: newValue: \(newValue)")
                withAnimation(.easeIn(duration: 0.3)) {
                    if newValue > oldValue {
                        playerVM.next()
                    } else if newValue < oldValue  {
                        playerVM.previous()
                    }
                }
            })
            .sheet(isPresented: $isPlayerShowing) {
                NowPlayingSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(25)
                    .presentationBackground(.clear)
            }
        } // ZStack
        
        .overlay(alignment: .bottom) {
            progressiveBlurView(startPoint: .bottom,
                                endPoint: .top)
            .frame(width: UIScreen.main.bounds.width,
                   // Note: progressiveBlur is a bit imprecise; we want a particular level of blurEffect at a particular point in the screen
                   height: UIScreen.main.bounds.height - (self.cardHeight * 1.5))
            .allowsHitTesting(false) // ignores gestures
        }
    }
    
    @State private var isAnimatingFromTap: Bool = false
    
    @ViewBuilder
    func childView(_ index: Int) -> some View {
        let hasSwipeOffset = self.horizontalSwipeOffset?.1 == index
        let swipeOffset = self.horizontalSwipeOffset?.0 ?? .zero
        
        ZStack {
            
            directionFeedbackView
            
            ClipCardView(categoryFeedVM: categoryFeedVM,
                         index: index,
                         cardSize: .init(width: self.cardWidth,
                                         height: self.cardHeight),
                         labelOpacity: 1)
            .offset(x: hasSwipeOffset ? swipeOffset : .zero)
            .onTapGesture {
                guard !self.isAnimatingFromTap else {
                    // print("Already animating from tap")
                    return
                }
                
                // If we're not already paged to this item,
                // then page to it now.
                let scrollPositionIsAtIndex = self.scrollPosition == index
                
                // It can happen that the animation is interrupted, such that scrollPosition is set to this index but we did not actually fully scroll there.
                // So we also check against currentCenter.
                let currentCenterIsAtIndex = self.currentCenter == index
                
                if !scrollPositionIsAtIndex || !currentCenterIsAtIndex {
                    self.isAnimatingFromTap = true
                    
                    // First, reset scrollPosition, in case it was already at this index.
                    self.scrollPosition = nil
                    
                    // Then, on a separate render, set the scrollPosition to this index.
                    DispatchQueue.main.async {
                        withAnimation {
                            self.scrollPosition = index
                        }
                    }
                        
                    // 0.6 = assumed time of scroll animation;
                    // Note: `completion:` handler of `withAnimation` can sometimes not be called
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.isAnimatingFromTap = false
                    }
                }
                // Else, show the player:
                else {
                    isPlayerShowing = true
                }
            }
            .gesture(
                DragGesture()
                    .onChanged({ value in
                        
                        // Only allow swipe on the currently-centered item
                        guard self.currentCenter == index else {
                            return
                        }
                        
                        // let swipeThreshold = 8.0
                        // let swipeThreshold = 4.0
                        let swipeThreshold = 0.0
                        if value.translation.width.magnitude > swipeThreshold {
                            let swipeOffset = max(min(value.translation.width,
                                                      cardSize.width),
                                                  -cardSize.width)
                            
                            self.horizontalSwipeOffset = (swipeOffset, index)
                            checkConfirmationPoint()
                        }
                    })
                    .onEnded({ value in
                        withAnimation {
                            if let nowPlaying = playerVM.nowPlaying {
                                let isInterested = hasSwipeOffset && (swipeOffset > 0)
                                Task {
                                    await profileVM.followShow(feed: nowPlaying.feedItem.feed,
                                                               isInterested: isInterested)
                                }
                            }
                            
                            self.horizontalSwipeOffset = nil
                        }
                    })
            ) // .gesture
        }
    }
    
    @State var currentSmallestDistanceFromCenter: CGFloat? = nil
    
    // TODO: Move to `.visualEffects` modifier closure?
    nonisolated func distanceFromCenter(index: Int,
                                        for proxy: GeometryProxy) -> Double {
        let scrollViewHeight = proxy.bounds(of: .scrollView)?.height ?? 100
        let center = proxy.frame(in: .scrollView).midY
        let distance = scrollViewHeight / 2 - center
        
        // Allow some wiggle room; don't just test against 0
        if distance.magnitude.rounded(.towardZero) < 28 {
            DispatchQueue.main.async {
                withAnimation {
                    self.currentCenter = index
                }
            }
        }
        
        return distance
    }
  
    private func checkConfirmationPoint() {
        let wasConfirmed = isConfirmed
        isConfirmed = dragOffset >= cardSize.width / 2
        
        if isConfirmed && !wasConfirmed {
            impactFeedback.impactOccurred()
        }
    }
}

extension ArtworkFeed {
    
    func backgroundView(_ index: Int) -> some View {
        GeometryReader { geo in
            ZStack {
                if index >= 0 && index < categoryFeedVM.clips.count {
                    ArtworkView(feed: categoryFeedVM.clips[index].feedItem.feed)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 50)
                }
                
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
 
    private func progressiveBlurView(startPoint: UnitPoint, 
                                     endPoint: UnitPoint) -> some View {
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
            feedbackColor
            
            HStack(alignment: .center) {
                if dragOffset < 0 {
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
                } else if dragOffset > 0 {
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
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var feedbackColor: Color {
        if dragOffset == .zero {
            return .clear
        } else if dragOffset > 0 {
            return .green
        } else {
            return .red
        }
    }
}
