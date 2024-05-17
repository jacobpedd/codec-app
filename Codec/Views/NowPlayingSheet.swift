//
//  NowPlayingSheet.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/17/24.
//

import Foundation
import SwiftUI
import AVKit

struct RouteButtonView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.activeTintColor = .black
        routePickerView.tintColor = .black
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No update needed
    }
}

struct AirPlayView: UIViewRepresentable {
    
    private let routePickerView = AVRoutePickerView()

    func makeUIView(context: UIViewRepresentableContext<AirPlayView>) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<AirPlayView>) {
        routePickerView.tintColor = .black
        routePickerView.activeTintColor = .blue
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
    @EnvironmentObject private var playerModel: AudioPlayerModel
    @EnvironmentObject private var userModel: UserModel
    
    let speeds: [Double] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    var topic: Topic {
        return userModel.feed[userModel.playingIndex]
    }
    
    var duration: Double {
        return playerModel.duration
    }
    
    var image: Artwork? {
        return userModel.topicArtworks[topic.id]
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
        VStack() {
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
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    if isTranscriptShowing {
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(topic.script.trimmingCharacters(in: .whitespacesAndNewlines))
                                
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
            
            VStack(alignment: .leading, spacing: 0) {
                Text(topic.title)
                    .lineLimit(3)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                
                VStack {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10)
                                .frame(height: 5)
                                .foregroundColor(Color.gray)
                                .brightness(0.3)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .frame(width: geometry.size.width * playerModel.progress, height: 5)
                                .foregroundColor(.gray)
                                .animation(.linear, value: playerModel.progress)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .opacity(0.01)
                                .frame(height: 5)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let newProgress = value.location.x / geometry.size.width
                                            playerModel.seekToProgress(percentage: min(max(newProgress, 0), 1))
                                        }
                                )
                        }
                    }
                    .frame(height: 5)
                    
                    HStack {
                        Text(formattedTime(from: playerModel.currentTime))
                            .font(.caption)
                            .foregroundColor(Color.gray)
                        Spacer()
                        Text(formattedTime(from: playerModel.duration))
                            .font(.caption)
                            .foregroundColor(Color.gray)
                    }
                }
                
                Spacer()
                
                HStack {
                    Button(action: {
                        userModel.previous()
                    }) {
                        Image(systemName: "backward.fill")
                            .foregroundColor(.black)
                            .font(.system(size: 30))
                    }
                    Spacer()
                    Button(action: {
                        playerModel.playPause()
                    }) {
                        Image(systemName: playerModel.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.black)
                            .font(.system(size: 50))
                    }
                    Spacer()
                    Button(action: {
                        userModel.next()
                    }) {
                        Image(systemName: "forward.fill")
                            .foregroundColor(.black)
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
                                    playerModel.playbackSpeed = speed
                                }
                            }
                        } label: {
                            Text("\(formattedSpeed(playerModel.playbackSpeed))x")
                                .foregroundColor(.black)
                                .font(.system(size: 24))
                            
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isTranscriptShowing = !isTranscriptShowing
                        }) {
                            if isTranscriptShowing {
                                Image(systemName: "text.quote")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.gray)
                                    .cornerRadius(10)
                            } else {
                                Image(systemName: "text.quote")
                                    .foregroundColor(.black)
                                    .font(.system(size: 24))
                                    .padding(8)
                            }
                            
                        }
                            
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
            .padding(.top)
            
        }
        .padding(.horizontal)
        .padding(.top)
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    return VStack {
        Spacer()
        NowPlayingView()
            .environmentObject(AudioPlayerModel())
            .environmentObject(UserModel())
    }
}
