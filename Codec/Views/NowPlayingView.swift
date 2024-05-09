//
//  NowPlayingView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/7/24.
//

import SwiftUI
import AVFoundation

// TODO: Don't display the Topic change until the audio is loaded

class AudioPlayerViewModel: ObservableObject {
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?

    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0

    init(audioKey: String) {
        setupPlayer(audioKey: audioKey)
    }

    func setupPlayer(audioKey: String) {
        if let audioURL = URL(string: "https://bucket.wirehead.tech/\(audioKey)") {
            let asset = AVAsset(url: audioURL)
            playerItem = AVPlayerItem(asset: asset)
            
            if (audioPlayer != nil) {
                audioPlayer?.replaceCurrentItem(with: playerItem)
            } else {
                audioPlayer = AVPlayer(playerItem: playerItem)
            }
            
            loadDuration()
            setupProgressListener()
        }
    }

    func playNewAudio(audioKey: String) {
        if (isPlaying) {
            playPause()
            isPlaying = false
        }
        if let token = timeObserverToken {
            audioPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        setupPlayer(audioKey: audioKey)
        
        playPause()
        isPlaying = true
        currentTime = 0
        progress = 0
    }

    deinit {
        if let token = timeObserverToken {
            audioPlayer?.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func loadDuration() {
        Task {
            if let duration = try? await playerItem?.asset.load(.duration)
            {
                DispatchQueue.main.async { [weak self] in
                    if !duration.isIndefinite {
                        self?.duration = duration.seconds
                    }
                }
            }
        }
    }

    func playPause() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        isPlaying.toggle()
    }

    private func setupProgressListener() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let durationSeconds = CMTimeGetSeconds(self.playerItem?.duration ?? .zero)
            let currentSeconds = CMTimeGetSeconds(time)
            self.currentTime = currentSeconds
            self.progress = (durationSeconds > 0) ? currentSeconds / durationSeconds : 0
        }
    }

    func seekToTime(seconds: Double) {
        let seekTime = CMTime(seconds: seconds, preferredTimescale: 1)
        audioPlayer?.seek(to: seekTime)
    }

    func seekToProgress(percentage: Double) {
        guard let duration = playerItem?.duration else { return }
        let totalSeconds = CMTimeGetSeconds(duration)
        let seekTimeSeconds = totalSeconds * percentage
        let seekTime = CMTime(seconds: seekTimeSeconds, preferredTimescale: 1)
        audioPlayer?.seek(to: seekTime)
    }
}

struct AudioScrubberView: View {
    @ObservedObject var playerModel: AudioPlayerViewModel
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
    @StateObject private var playerModel: AudioPlayerViewModel
    
    init(topic: Topic) {
        self.topic = topic
        _playerModel = StateObject(wrappedValue: AudioPlayerViewModel(audioKey: topic.audio))
    }
    
    
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
                    playerModel.seekToTime(seconds: 0)
                }) {
                    Image(systemName: "forward.fill")
                        .foregroundColor(.black)
                }
                
            }
//            AudioScrubberView(playerModel: playerModel)
        }
        .padding()
        .background(.white)
        .cornerRadius(15)
        .frame(maxWidth: .infinity)
        .shadow(color: Color.gray.opacity(0.3), radius: 10)
        .padding()
        .onChange(of: topic.audio) { audio in
            playerModel.playNewAudio(audioKey: audio)
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
    }
}

#Preview {
    let topic = Topic(id: 0, title: "Deepfakes Shatter Trust in 2024 Election Reality", audio: "62a9e81834fbf4ebecea4403ed713117", image: "ae8e033c59cb551bc34e2f2279c91638", createdAt: .now)
    
    return VStack {
        Spacer()
        NowPlayingView(topic: topic)
    }
}
