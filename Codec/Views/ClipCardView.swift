//
//  ClipCardView.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/10/24.
//

import SwiftUI

struct ClipCardView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var dragOffset: CGFloat = 0.0
    @State private var isPlayingClip: Bool = false
    let index: Int
    let cardSize: CGSize
    let labelOpacity: CGFloat
    
    var labelHeight: CGFloat { return cardSize.height - cardSize.width }
    
    var clip: Clip {
        return feedModel.feed[index]
    }
    
    var artwork: Artwork? {
        return feedModel.feedArtworks[clip.feedItem.feed.id]
    }
    
    var gradientColor: Color {
        return artwork?.shadowColor ?? .black
    }
    
    var body: some View {
        ZStack() {
            if let image = artwork?.image {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardSize.width, height: cardSize.width)
                    Spacer()
                }
                VStack {
                    Spacer()
                        .frame(height: cardSize.width * 0.6)
                    labelOverlay
                }
            } else {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    ProgressView()
                }
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: feedModel.isPlaying) { updatePlayingState() }
        .onChange(of: feedModel.nowPlayingIndex) { updatePlayingState() }
    }
    
    private func updatePlayingState() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPlayingClip = feedModel.isPlaying && feedModel.nowPlayingIndex == index
        }
    }
    
    
    private var labelOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: gradientColor.opacity(0), location: 0),
                .init(color: gradientColor.opacity(0.2), location: 0.1),
                .init(color: gradientColor.opacity(0.5), location: 0.2),
                .init(color: gradientColor.opacity(0.9), location: 0.35),
                .init(color: gradientColor, location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(label)
    }
    
    private var label: some View {
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
            Spacer()
                .frame(height: 10)
            playButton
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var playButton: some View {
        Button(action: {
            feedModel.playPause()
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
                .foregroundColor(gradientColor)
                
                if isPlayingClip {
                    ZStack {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 10)
                                    .frame(height: 5)
                                    .foregroundColor(gradientColor)
                                    .opacity(0.3)
                                
                                RoundedRectangle(cornerRadius: 10)
                                    .frame(width: geometry.size.width * feedModel.progress, height: 5)
                                    .foregroundColor(gradientColor)
                            }
                        }
                    }
                    .frame(width: 50, height: 5)
                    .animation(.easeInOut(duration: 0.3), value: isPlayingClip)
                }
                
                Text(
                    feedModel.nowPlayingIndex == index
                        ? formattedDuration(isPlayingClip
                            ? (feedModel.duration - feedModel.currentTime)
                            : feedModel.duration)
                        : "Play"
                )
                    .font(.system(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(gradientColor)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(Color.white)
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
