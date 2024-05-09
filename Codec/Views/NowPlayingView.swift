//
//  NowPlayingView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/7/24.
//

import SwiftUI

struct AudioScrubberView: View {
    @ObservedObject var playerModel: AudioPlayerModel
    @State private var sliderValue: Double = 0.0
    @State private var isDragging: Bool = false

    var body: some View {
        Slider(value: $sliderValue, in: 0...1, onEditingChanged: sliderEditingChanged)
        HStack {
            Text(formatTime(seconds: playerModel.currentTime))
            Spacer()
            Text(formatTime(seconds: playerModel.duration))
        }
        .onReceive(playerModel.$progress) { progress in
            if !isDragging {
                sliderValue = progress
            }
        }
    }
    
    private func sliderEditingChanged(editingStarted: Bool) {
        isDragging = editingStarted
        if !editingStarted {
            playerModel.seekToProgress(percentage: sliderValue)
        }
    }
    
    private func formatTime(seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return formatter.string(from: seconds) ?? "0:00"
    }
}



struct NowPlayingView: View {
    var topic: Topic
    @State private var isPlayerShowing: Bool = false
    @EnvironmentObject private var playerModel: AudioPlayerModel
    @EnvironmentObject private var userDataModel: UserDataModel
    
    
    var body: some View {
        VStack {
            HStack {
                Text(topic.title)
                    .lineLimit(1)
                Spacer()
                Button(action: {
                    playerModel.playPause()
                }) {
                    Image(systemName: playerModel.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.black)
                }
                Button(action: {
                    userDataModel.next()
                }) {
                    Image(systemName: "forward.fill")
                        .foregroundColor(.black)
                }
                
            }
//            AudioScrubberView()
        }
        .padding()
        .background(.white)
        .cornerRadius(15)
        .frame(maxWidth: .infinity)
        .shadow(color: Color.gray.opacity(0.3), radius: 10)
        .padding()
        .onChange(of: topic.audio) { audio in
            playerModel.loadAudio(audioKey: audio, shouldPlay: true)
        }
//        .onTapGesture {
//            isPlayerShowing = true
//        }
        .sheet(isPresented: $isPlayerShowing, onDismiss: {
            isPlayerShowing = false
        }) {
            VStack(spacing: 15) {
                Text("Big Player Screen")
                    .font(.largeTitle)
                Spacer()
            }
            .padding()
            .presentationDragIndicator(.visible)
        }
        .onAppear() {
            playerModel.setupPlayer(audioKey: topic.audio)
        }
    }
}

#Preview {
    let topic = Topic(id: 0, title: "Deepfakes Shatter Trust in 2024 Election Reality", audio: "62a9e81834fbf4ebecea4403ed713117", image: "ae8e033c59cb551bc34e2f2279c91638", createdAt: .now)
    
    return VStack {
        Spacer()
        NowPlayingView(topic: topic)
            .environmentObject(AudioPlayerModel())
    }
}
