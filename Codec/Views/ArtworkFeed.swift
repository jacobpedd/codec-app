import SwiftUI

private struct PositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint { .zero }
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
}

struct PositionObservingView<Content: View>: View {
    var coordinateSpace: CoordinateSpace
    @Binding var position: CGPoint
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(GeometryReader { geometry in
                Color.clear.preference(
                    key: PositionPreferenceKey.self,
                    value: geometry.frame(in: coordinateSpace).origin
                )
            })
            .onPreferenceChange(PositionPreferenceKey.self) { position in
                self.position = position
            }
    }
}

struct OffsetObservingScrollView<Content: View>: View {
    var axes: Axis.Set = [.vertical]
    var showsIndicators = false
    @Binding var offset: CGPoint
    @ViewBuilder var content: () -> Content

    private let coordinateSpaceName = UUID()

    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            PositionObservingView(
                coordinateSpace: .named(coordinateSpaceName),
                position: Binding(
                    get: { offset },
                    set: { newOffset in
                        offset = CGPoint(x: -newOffset.x, y: -newOffset.y)
                    }
                ),
                content: content
            )
        }
        .coordinateSpace(name: coordinateSpaceName)
    }
}

struct ArtworkFeed: View {
    @ObservedObject var categoryFeedVM: CategoryFeedViewModel
    
    @EnvironmentObject private var playerVM: PlayerViewModel
    @EnvironmentObject private var feedVM: FeedViewModel
    
    @State private var scrollOffset: CGPoint = .zero
    @State private var currentPage: Int = 0
    @State private var targetPage: Int? = nil
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.9
    private var cardHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    private var cardSize: CGSize { CGSize(width: cardWidth, height: cardHeight) }
    
    public init(categoryFeedVM: CategoryFeedViewModel) {
        self.categoryFeedVM = categoryFeedVM
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                backgroundView(geometry: geometry)
                visibleCards(geometry: geometry)
                ScrollViewReader { proxy in
                    OffsetObservingScrollView(offset: $scrollOffset) {
                        paginatedContent(geometry: geometry)
                    }
                    .scrollTargetBehavior(.paging)
                    .onChange(of: targetPage) {
                        withAnimation {
                            proxy.scrollTo(targetPage, anchor: .center)
                            targetPage = nil
                        }
                    }
                }
                tapNavigationView(geometry: geometry)
                    
            }
            .onChange(of: scrollOffset) {
                let newPage = Int(round(scrollOffset.y / geometry.size.height))
                if newPage != currentPage {
                    currentPage = newPage
                    playerVM.setIndex(index: currentPage)
                }
            }
            .onChange(of: categoryFeedVM.nowPlayingIndex) {
                if currentPage != categoryFeedVM.nowPlayingIndex {
                    targetPage = categoryFeedVM.nowPlayingIndex
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func backgroundView(geometry: GeometryProxy) -> some View {
        let pageHeight = geometry.size.height
        let scrollProgress = scrollOffset.y.truncatingRemainder(dividingBy: pageHeight) / pageHeight
        let currentIndex = Int(scrollOffset.y / pageHeight)
        
        return ZStack {
            // Current image
            backgroundImage(for: currentIndex)
                .opacity(1.0 - CGFloat(abs(scrollProgress)))

            // Next image (for scrolling down)
            backgroundImage(for: currentIndex + 1)
                .opacity(scrollProgress > 0 ? scrollProgress : 0)
            
            // Previous image (for scrolling up)
            backgroundImage(for: currentIndex - 1)
                .opacity(scrollProgress < 0 ? -scrollProgress : 0)
            
            // Overlay
            Rectangle()
                .fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
        .frame(width: geometry.size.width)
        .clipped()
    }
    
    private func backgroundImage(for index: Int) -> some View {
        Group {
            if index >= 0 && index < categoryFeedVM.clips.count {
                ArtworkView(feed: categoryFeedVM.clips[index].feedItem.feed)
                    .blur(radius: 50)
            } else {
                Color.clear
            }
        }
    }
    
    private func visibleCards(geometry: GeometryProxy) -> some View {
        let visibleRange = max(0, currentPage - 3)...min(categoryFeedVM.clips.count - 1, currentPage + 3)
        return ZStack {
            ForEach(visibleRange, id: \.self) { index in
                card(geometry: geometry, index: index)
            }
        }
    }

    private func card(geometry: GeometryProxy, index: Int) -> some View {
        let (yOffset, scale): (CGFloat, CGFloat) = {
            let pageHeight = geometry.size.height
            let baseOffset = CGFloat(index) * pageHeight
            let relativeScroll = scrollOffset.y - baseOffset
            let scrollProgress = relativeScroll / pageHeight
            
            // Calculate yOffset
            let yOffset = -scrollProgress * (pageHeight / 2)
            
            // Calculate scale
            let minScale: CGFloat = 0.8  // 80% scale at max offset
            let maxScale: CGFloat = 1.0  // 100% scale at center
            let scale = maxScale - (min(abs(scrollProgress), 1) * (maxScale - minScale))
            
            return (yOffset, scale)
        }()
        
        return VStack(spacing: 0) {
            Spacer()
            ClipCardView(categoryFeedVM: categoryFeedVM, index: index, cardSize: cardSize, labelOpacity: scale)
            .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
            .scaleEffect(scale)
            Spacer()
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .offset(y: yOffset)
    }
    
    private func paginatedContent(geometry: GeometryProxy) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<categoryFeedVM.clips.count, id: \.self) { index in
                ZStack {
                    Color.clear
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .id(index)
            }
        }.onAppear() {
            print("\(categoryFeedVM.category?.name ?? "FYP"): \(categoryFeedVM.clips.count)")
        }
    }
    
    private func tapNavigationView(geometry: GeometryProxy) -> some View {
        VStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    playerVM.previous()
                }
            // NOTE: This spacer has some tap targets because the underlying cards can't be tapped.
            // This is a pretty bad hack. We need it becasue the cards are under the scroll view so can't be tapped.
            VStack(spacing: 0) {
                Spacer()
                HStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: 175, height: 50)
                        .onTapGesture {
                            playerVM.playPause()
                        }
                    Spacer()
                    Menu {
                        Button(action: {
                            guard let clip = playerVM.nowPlaying else { return }
                            let feed = clip.feedItem.feed
                            Task {
                                await profileVM.followShow(feed: feed, isInterested: false)
                            }
                        }) {
                            Label("Mute Show", systemImage: "xmark.shield")
                        }
                        Button(action: {
                            guard let clip = playerVM.nowPlaying else { return }
                            let feed = clip.feedItem.feed
                            Task {
                                await profileVM.followShow(feed: feed, isInterested: true)
                            }
                        }) {
                            Label("Follow Show", systemImage: "plus.circle")
                        }
                    } label : {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: 50, height: 40)
                    }
                }
            }
            .frame(width: cardSize.width, height: cardSize.height)
            
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    playerVM.next()
                }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
}
