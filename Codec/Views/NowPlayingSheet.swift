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
    @EnvironmentObject private var feedVM: FeedViewModel
    @EnvironmentObject private var playerVM: PlayerViewModel
    @EnvironmentObject private var artworkVM: ArtworkViewModel
    @State private var isQueueListShowing: Bool = false
    @State private var airPlayView = AirPlayView()
    @Environment(\.colorScheme) var colorScheme
    
    let speeds: [Double] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    var clip: Clip? {
        playerVM.nowPlaying
    }
    
    var duration: Double {
        return playerVM.duration
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
                if let clip = clip {
                    GeometryReader { geometry in
                        ArtworkView(feed: clip.feedItem.feed)
                            .frame(width: geometry.size.height, height: geometry.size.height)
                            .clipped()
                            .cornerRadius(15)
                            .shadow(color: .gray.opacity(0.6), radius: 20)
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
                        
                        // Progress bar and time
                        VStack {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .frame(height: 5)
                                        .foregroundColor(.gray)
                                        .brightness(colorScheme == .light ? 0.3 : 0.0)
                                    
                                    RoundedRectangle(cornerRadius: 10)
                                        .frame(width: geometry.size.width * playerVM.progress, height: 5)
                                        .foregroundColor(.gray)
                                        .brightness(colorScheme == .light ? 0.0 : 0.3)
                                        .animation(.easeInOut(duration: 0.25), value: playerVM.progress)
                                    
                                    RoundedRectangle(cornerRadius: 10)
                                        .opacity(0.01)
                                        .frame(height: 5)
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    let newProgress = value.location.x / geometry.size.width
                                                    playerVM.seekToProgress(percentage: min(max(newProgress, 0), 1))
                                                }
                                        )
                                }
                            }
                            .frame(height: 5)
                            
                            HStack {
                                Text(formattedTime(from: playerVM.currentTime))
                                    .font(.caption)
                                    .foregroundColor(Color.gray)
                                Spacer()
                                Text(formattedTime(from: playerVM.duration))
                                    .font(.caption)
                                    .foregroundColor(Color.gray)
                            }
                        }
                        
                        Spacer()
                        
                        // Playback controls
                        HStack {
                            Button(action: {
                                playerVM.previous()
                            }) {
                                Image(systemName: "backward.fill")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 30))
                            }
                            Spacer()
                            Button(action: {
                                playerVM.playPause()
                            }) {
                                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 50))
                            }
                            Spacer()
                            Button(action: {
                                playerVM.next()
                            }) {
                                Image(systemName: "forward.fill")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 30))
                            }
                        }
                        
                        Spacer()
                        
                        // Bottom controls
                        ZStack {
                            airPlayView
                                .frame(width: 50, height: 50)
                            
                            HStack {
                                Menu {
                                    ForEach(speeds, id: \.self) { speed in
                                        Button("\(formattedSpeed(speed))x") {
                                            playerVM.playbackSpeed = speed
                                        }
                                    }
                                } label: {
                                    Text("\(formattedSpeed(playerVM.playbackSpeed))x")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 24))
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    isQueueListShowing.toggle()
                                }) {
                                    Image(systemName: "list.bullet")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 24))
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
        .onAppear {
            setWindowBackgroundColor(.black)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .sheet(isPresented: $isQueueListShowing, onDismiss: {
            isQueueListShowing = false
        }) {
            QueueListView()
        }
    }
}

private func setWindowBackgroundColor(_ color: UIColor) {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first
    {
        window.backgroundColor = color
    }
}

struct NowPlayingPreviewWrapper: View {
    @EnvironmentObject private var playerVM: PlayerViewModel
    
    var body: some View {
        VStack {
            Spacer()
        }
        .sheet(isPresented: .constant(true)) {
            if playerVM.nowPlaying != nil {
                NowPlayingSheet()
            } else {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            }
        }
    }
}

#Preview {
    NowPlayingPreviewWrapper()
        .previewWithEnvironment()
}
