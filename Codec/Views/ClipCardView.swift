//
//  ClipCardView.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/10/24.
//

import SwiftUI

struct ClipCardView: View {
    @ObservedObject var categoryFeedVM: CategoryFeedViewModel
    
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject private var playerVM: PlayerViewModel
    @EnvironmentObject private var artworkVM: ArtworkViewModel
    @State private var dragOffset: CGFloat = 0.0
    @State private var artwork: Artwork?
    let index: Int
    let cardSize: CGSize
    let labelOpacity: CGFloat
    
    var labelHeight: CGFloat { return cardSize.height - cardSize.width }
    
    var clip: Clip? {
        guard index >= 0 && index < categoryFeedVM.clips.count else { return nil }
        return categoryFeedVM.clips[index]
    }
    
    var artworkColor: Color {
        return artwork?.bgColor ?? Color.black
    }
    
    var isPlayingClip: Bool {
        return playerVM.isPlaying && playerVM.nowPlaying == clip && clip != nil
    }
    
    init(categoryFeedVM: CategoryFeedViewModel, index: Int, cardSize: CGSize, labelOpacity: CGFloat) {
        self.categoryFeedVM = categoryFeedVM
        self.index = index
        self.cardSize = cardSize
        self.labelOpacity = labelOpacity
    }
    
    var body: some View {
        ZStack {
            if let clip = clip {
                cardContent(for: clip)
            } else {
                emptyCardView
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: clip) { loadArtwork() }
        .onAppear {
            loadArtwork()
        }
    }
    
    private func cardContent(for clip: Clip) -> some View {
        ZStack {
            VStack {
                ArtworkView(feed: clip.feedItem.feed)
                .frame(width: cardSize.width, height: cardSize.width)
                Spacer()
            }
            VStack {
                Spacer()
                    .frame(height: cardSize.width * 0.6)
                labelOverlay(for: clip)
            }
        }
    }
    
    private var emptyCardView: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            Text("No clip available")
                .foregroundColor(.secondary)
        }
    }
    
    private func labelOverlay(for clip: Clip) -> some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.clear, location: 0),
                .init(color: artworkColor.opacity(0.2), location: 0.1),
                .init(color: artworkColor.opacity(0.5), location: 0.2),
                .init(color: artworkColor.opacity(0.9), location: 0.35),
                .init(color: artworkColor, location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(label(for: clip))
    }
    
    private func label(for clip: Clip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("\(clip.feedItem.postedAt.formattedAsDayAndMonth()) • \(clip.feedItem.feed.name)")
                .foregroundStyle(.white)
                .lineLimit(1)
                .font(.caption)
            Spacer()
                .frame(height: 2)
            Text(clip.name)
                .foregroundColor(.white)
                .fontWeight(.bold)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
                .frame(height: 10)
            HStack(alignment: .center) {
                playButton
                    .animation(.easeIn, value: isPlayingClip)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                }
                
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var playButton: some View {
        Button(action: {
            playerVM.playPause()
        }) {
            HStack(spacing: 5) {
                ZStack {
                    Image(systemName: "play.fill")
                        .opacity(isPlayingClip ? 0 : 1)
                    Image(systemName: "waveform")
                        .opacity(isPlayingClip ? 1 : 0)
                        .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing, isActive: isPlayingClip)
                }
                .frame(width: 16, height: 16)
                .font(Font.system(size: 16))
                .foregroundColor(artworkColor)
                
                if isPlayingClip {
                    ZStack {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 10)
                                    .frame(height: 5)
                                    .foregroundColor(artworkColor)
                                    .opacity(0.3)
                                
                                RoundedRectangle(cornerRadius: 10)
                                    .frame(width: geometry.size.width * playerVM.progress, height: 5)
                                    .foregroundColor(artworkColor)
                            }
                        }
                    }
                    .frame(width: 50, height: 5)
                    .animation(.easeInOut(duration: 0.3), value: isPlayingClip)
                }
                
                Text(
                    categoryFeedVM.nowPlayingIndex == index
                        ? formattedDuration(isPlayingClip
                            ? (playerVM.duration - playerVM.currentTime)
                            : playerVM.duration)
                        : "Play"
                )
                    .font(.system(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(artworkColor)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(.white)
            .cornerRadius(15)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedDuration(_ totalSeconds: Double) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func loadArtwork() {
        guard let clip = clip else { return }
        artworkVM.loadArtwork(for: clip.feedItem.feed) { loadedArtwork in
            self.artwork = loadedArtwork
        }
    }
}

extension Date {
    func formattedAsDayAndMonth() -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: self, to: now)
            if let daysAgo = components.day, daysAgo < 10 {
                return "\(daysAgo) days ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "E MMM d"
                let dayString = formatter.string(from: self)
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "d"
                let day = Int(dayFormatter.string(from: self))!
                
                switch day % 10 {
                case 1:
                    return dayString + (day == 11 ? "th" : "st")
                case 2:
                    return dayString + (day == 12 ? "th" : "nd")
                case 3:
                    return dayString + (day == 13 ? "th" : "rd")
                default:
                    return dayString + "th"
                }
            }
        }
    }
}

struct ClipCardPreviewView: View {
    @EnvironmentObject var feedVM: FeedViewModel
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.9
    private var cardHeight: CGFloat { cardWidth + 25 }
    private var cardSize: CGSize { CGSize(width: cardWidth, height: cardHeight) }
    
    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                if let currentCategoryFeedVM = feedVM.currentCategoryFeedVM {
                    ClipCardView(categoryFeedVM: currentCategoryFeedVM, index: 2, cardSize: cardSize, labelOpacity: 1.0)
                }
            }
        }
    }
}

#Preview {
    ClipCardPreviewView()
        .previewWithEnvironment()
}
