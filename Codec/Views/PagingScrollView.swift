//
//  PagingScrollView.swift
//  Codec
//
//  Created by Christian J Clampitt on 8/26/24.
//

import SwiftUI

struct ColorData: Equatable, Identifiable {
    let id: UUID
    let color: Color
}

let colors: [ColorData] = [
    .init(id: .init(), color: .red),
    .init(id: .init(), color: .blue),
    .init(id: .init(), color: .green),
    .init(id: .init(), color: .yellow),
    .init(id: .init(), color: .purple),
    .init(id: .init(), color: .indigo),
    .init(id: .init(), color: .cyan),
    .init(id: .init(), color: .brown),
    .init(id: .init(), color: .orange),
    .init(id: .init(), color: .gray),
    .init(id: .init(), color: .mint),
    .init(id: .init(), color: .pink),
    .init(id: .init(), color: .teal),
]

struct PagingScrollView: View {
    
    // cardWidth is 90% of screenWidth
    // cardHeight is cardWidth + ~25
    static let screenWidth = 344.0

    var itemLength: CGFloat {
        Self.screenWidth * 0.9
    }
        
    @State private var position: UUID? = nil // jump to specific item
    
    static let nonCenterScale = 0.8
    
    var scrollViewHeight: CGFloat {
        // some height such that a single item can fit cleanly in the middle
        self.itemLength * 3
    }
    
    var viewPortalHeight: CGFloat {
        // cut off half of the top-most and half of the bottom-most views
        self.scrollViewHeight - self.itemLength
    }
    
    var body: some View {
        scroll
            .scaleEffect(1.5) // DEBUG
    }
    
    var scroll: some View {
        ScrollView(.vertical, showsIndicators: false) {
        
            LazyVStack(spacing: 0) { // Lazy = don't load item until requested
                
                ForEach(colors, id: \.id) { colorDatum in
                    childView(colorDatum)
                        .opacity(colorDatum.color == .black ? 0.5 : 1) // DEBUG (TO SEE PADDING)
                    //                        .opacity(colorDatum.color == .black ? 0 : 1) // DEBUG (TO SEE PADDING)
                        .onTapGesture {
                            print("tapped \(colorDatum.color.description)")
                            guard colorDatum.color != .black else {
                                return // disallow interaction with "padding" elements
                            }
                            withAnimation {
                                self.position = colorDatum.id
                            }
                        }
                    
                    /*
                     Suppose we scale down non-centered items to 80% and that each item's height is 300. Thus:
                     - item's distance-from-center = 0, then scale = 1 - 0 i.e. 1.0
                     - distance = 300, then scale = 1 - 0.2 i.e. 0.8
                     - distance = 150, then scale = 1 - 0.1 i.e. 0.9
                     */
                        .visualEffect { content, proxy in
                            let _distanceFromCenter = distanceFromCenter(for: proxy).rounded(.towardZero)
                        
                            let shouldOffsetUp = _distanceFromCenter < 0
                            // Later calculations require absValue of distance
                            let distance = abs(_distanceFromCenter)
                            
                            let maxDistance = self.itemLength
                            let cappedDistance = min(distance, maxDistance) // e.g. treat distances greater than 300 as simply 300
                            let percentOfMaxDistance = cappedDistance/maxDistance
                            let maxScaleReduction = 1.0 - Self.nonCenterScale // e.g. never reduce scale by more than 20%
                            let scaleReduction = maxScaleReduction * percentOfMaxDistance
                            
                            let maxOffset = self.itemLength/2 // i.e. 50 if itmeLength = 100
                            let actualOffset = maxOffset * percentOfMaxDistance
                            
                            return content
                                .scaleEffect(0.5) // scale whole thing down by 50%
                                .scaleEffect(1.0 - scaleReduction) // apply center-based scaling
                                .offset(y: (shouldOffsetUp ? -1 : 1) * actualOffset)
                        }
                } // ForEach
            } // LazyVStack
            
        } // ScrollView
        
        // ScrollView must be height of paged-item when using `.paging` PagingScrollTargetBehavior
        .frame(width: self.itemLength,
                height: self.itemLength)
        .border(.yellow) // DEBUG
        .scrollTargetBehavior(.paging)
        
        // Setting ScrollView's position to some specific item
        .scrollPosition(id: self.$position,
                        anchor: .center)
        .frame(width: Self.screenWidth)
    } // body
    
    func childView(_ colorDatum: ColorData) -> some View {
        Text("\(colorDatum.color.description)")
            .frame(width: self.itemLength, height: self.itemLength)
            .background(colorDatum.color)
            .foregroundStyle(.white)
            .clipShape(.rect(cornerRadius: 30))
    }
    
    func distanceFromCenter(for proxy: GeometryProxy) -> Double {
        let scrollViewHeight = proxy.bounds(of: .scrollView)?.height ?? 100
        let center = proxy.frame(in: .scrollView).midY
//        let distance = abs(scrollViewHeight / 2 - center)
        let distance = scrollViewHeight / 2 - center
//        print("distance: \(distance)")
        return distance
    }
}
