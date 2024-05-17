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

import SwiftUI

struct NowPlayingSheet: View {
    @EnvironmentObject private var playerModel: AudioPlayerModel
    @EnvironmentObject private var userModel: UserModel
    
    let speeds: [Double] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    var topic: Topic {
        return userModel.feed[userModel.playingIndex]
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
    
    var body: some View {
        VStack() {
            GeometryReader { geometry in
                VStack {
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
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
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
                        Text("0:00")
                            .font(.caption)
                            .foregroundColor(Color.gray)
                        Spacer()
                        Text("-1:00")
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
                    RouteButtonView()
                        .frame(height: 50)
                    
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
                            userModel.next()
                        }) {
                            Image(systemName: "text.quote")
                                .foregroundColor(.black)
                                .font(.system(size: 24))
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
    let topic = Topic(id: 0, title: "Deepfakes Shatter Trust in 2024 Election Reality", audio: "62a9e81834fbf4ebecea4403ed713117", image: "ae8e033c59cb551bc34e2f2279c91638", createdAt: .now)
    
    return VStack {
        Spacer()
        NowPlayingView()
            .environmentObject(AudioPlayerModel())
            .environmentObject(UserModel())
    }
}
