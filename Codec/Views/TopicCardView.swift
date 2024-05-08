//
//  TopicCardView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/7/24.
//

import SwiftUI
import BigUIPaging

struct TopicView: View {
    var topic: Topic

    var body: some View {
        VStack {
            VStack {
                Spacer()
                Text(topic.title)
                    .font(.largeTitle)
                    .foregroundStyle(.white)
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
    let topic = Topic(id: 0, title: "TikTok Battles US Ban, Slams China Crackdown", audio: "4ddce98e811f426816ba3ef6a6880169", createdAt: .now)
    
    return VStack {
        PageView(selection: Binding(get: {
            return 0
        }, set: {_,_ in })) {
            ForEach(0..<1, id: \.self) { index in
                TopicView(topic: topic)
            }
        }
        .pageViewStyle(.cardDeck)
        .frame(height: 550)
    }
}
