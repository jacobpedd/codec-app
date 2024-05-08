//
//  TopicCardView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/7/24.
//

import SwiftUI
import BigUIPaging

// TODO: Add Image
// TODO: Dynamically set bgColor based on image

struct TopicView: View {
    var topic: Topic
    var bgColor: Color = .blue
    var isPlaying: Bool
    var onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            Text(topic.title)
                .font(.largeTitle)
                .foregroundStyle(.white)
            HStack {
                if (isPlaying) {
                    Text("Now Playing")
                        .foregroundStyle(.white)
                        .padding(.vertical, 5)
                } else {
                    Button(action: onPlay) {
                        HStack {
                            Text("Play")
                                .font(.body)
                                .foregroundStyle(bgColor)
                            Image(systemName: "play.fill")
                                .foregroundStyle(bgColor)
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal)
                    .background(.white)
                    .cornerRadius(10)
                }
                Spacer()
            }
        }
        .padding()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.blue)
        .cornerRadius(10)
    }
}

#Preview {
    let topic = Topic(id: 0, title: "Disney's Fading Streaming Magic", audio: "4ddce98e811f426816ba3ef6a6880169", createdAt: .now)
    
    return VStack {
        PageView(selection: Binding(get: {
            return 0
        }, set: {_,_ in })) {
            ForEach(0..<1, id: \.self) { index in
                TopicView(topic: topic, isPlaying: true, onPlay: {})
            }
        }
        .pageViewStyle(.cardDeck)
        .frame(height: 550)
    }
}
