//
//  NowPlayingSheet.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/17/24.
//

import Foundation
import SwiftUI
import AVKit

struct AirPlayView: UIViewRepresentable {
    
    private let routePickerView = AVRoutePickerView()

    func makeUIView(context: UIViewRepresentableContext<AirPlayView>) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<AirPlayView>) {
        routePickerView.tintColor = UIColor(Color.primary)
        routePickerView.activeTintColor = UIColor(Color.primary)
        routePickerView.backgroundColor = .clear
        
        routePickerView.translatesAutoresizingMaskIntoConstraints = false
        uiView.addSubview(routePickerView)

        NSLayoutConstraint.activate([
            routePickerView.topAnchor.constraint(equalTo: uiView.topAnchor),
            routePickerView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
            routePickerView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor),
            routePickerView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor)
        ])
    }
    
    func showAirPlayMenu() {
        for view: UIView in routePickerView.subviews {
            if let button = view as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
    }
}

struct NowPlayingSheet: View {
    @State private var isTranscriptShowing: Bool = false
    @State private var airPlayView = AirPlayView()
    @EnvironmentObject private var feedModel: FeedModel
    @Environment(\.colorScheme) var colorScheme
    
    let speeds: [Double] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    var clip: Clip? {
        feedModel.nowPlaying
    }
    
    var duration: Double {
        return feedModel.duration
    }
    
    var image: Artwork? {
        if let clip {
            return feedModel.feedArtworks[clip.feedItem.feed.id]
        }
        return nil
    }
    
    var bgColor: Color {
        return image?.bgColor ?? .gray
    }
    
    var shadwoColor: Color {
        return image?.shadowColor ?? .gray
    }
    
    func formattedSpeed(_ speed: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: speed)) ?? "\(speed)"
    }
    
    func formattedTime(from seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "0:00"
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.thickMaterial)
                .ignoresSafeArea()
            
            VStack() {
                if let clip {
                    GeometryReader { geometry in
                        ZStack {
                            if let image = image {
                                Image(uiImage: image.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geometry.size.height, height: geometry.size.height)
                                    .clipped()
                                    .cornerRadius(15)
                                    .shadow(color: image.shadowColor, radius: 20)
                            } else {
                                    Rectangle()
                                        .fill(Color.gray)
                                        .scaledToFill()
                                        .frame(width: geometry.size.height, height: geometry.size.height)
                                        .clipped()
                                        .cornerRadius(15)
                            }
                            
                            if isTranscriptShowing {
                                ScrollView(.vertical, showsIndicators: true) {
                                    Text(clip.summary.trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                                .padding()
                                .padding(.horizontal)
                                .background(.ultraThickMaterial)
                                .cornerRadius(15)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    
                    VStack(spacing: 0) {
                        VStack {
                            Text(clip.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                        }
                        .frame(height: 100)
                        
                        Spacer()
                        
                        VStack {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .frame(height: 5)
                                        .foregroundColor(.gray)
                                        .brightness(colorScheme == .light ? 0.3 : 0.0)
                                    
                                    RoundedRectangle(cornerRadius: 10)
                                        .frame(width: geometry.size.width * feedModel.progress, height: 5)
                                        .foregroundColor(.gray)
                                        .brightness(colorScheme == .light ? 0.0 : 0.3)
                                        .animation(.linear, value: feedModel.progress)
                                    
                                    RoundedRectangle(cornerRadius: 10)
                                        .opacity(0.01)
                                        .frame(height: 5)
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    let newProgress = value.location.x / geometry.size.width
                                                    feedModel.seekToProgress(percentage: min(max(newProgress, 0), 1))
                                                }
                                        )
                                }
                            }
                            .frame(height: 5)
                            
                            HStack {
                                Text(formattedTime(from: feedModel.currentTime))
                                    .font(.caption)
                                    .foregroundColor(Color.gray)
                                Spacer()
                                Text(formattedTime(from: feedModel.duration))
                                    .font(.caption)
                                    .foregroundColor(Color.gray)
                            }
                        }
                        
                        Spacer()
                        
                        HStack {
                            Button(action: {
                                feedModel.previous()
                            }) {
                                Image(systemName: "backward.fill")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 30))
                            }
                            Spacer()
                            Button(action: {
                                feedModel.playPause()
                            }) {
                                Image(systemName: feedModel.isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 50))
                            }
                            Spacer()
                            Button(action: {
                                feedModel.next()
                            }) {
                                Image(systemName: "forward.fill")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 30))
                            }
                        }
                        
                        Spacer()
                        
                        ZStack {
                            airPlayView
                                .frame(width: 50, height: 50)
                            
                            HStack {
                                Menu {
                                    ForEach(speeds, id: \.self) { speed in
                                        Button("\(formattedSpeed(speed))x") {
                                            feedModel.playbackSpeed = speed
                                        }
                                    }
                                } label: {
                                    Text("\(formattedSpeed(feedModel.playbackSpeed))x")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 24))
                                    
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    isTranscriptShowing = !isTranscriptShowing
                                }) {
                                    if isTranscriptShowing {
                                        Image(systemName: "photo")
                                            .foregroundColor(.primary)
                                            .font(.system(size: 24))
                                    } else {
                                        Image(systemName: "text.quote")
                                            .foregroundColor(.primary)
                                            .font(.system(size: 24))
                                    }
                                    
                                }
                                
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal)
                    .padding(.top)
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .onAppear() {
            setWindowBackgroundColor(.black)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }
}

private func setWindowBackgroundColor(_ color: UIColor) {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
        let window = windowScene.windows.first
    {
        window.backgroundColor = color
    }
}

#Preview {
    return VStack {
        Spacer()
        NowPlayingView()
            .environmentObject(FeedModel())
    }
}
