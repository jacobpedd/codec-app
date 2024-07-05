//
//  TopicsSection.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import SwiftUI

struct TopicsSection: View {
    @EnvironmentObject private var feedModel: FeedModel
    @Binding var isEditMode: EditMode
    @State private var deletingTopicId: Int?

    var body: some View {
        Section(header: Text("Topics")) {
            ForEach(feedModel.interestedTopics) { topic in
                HStack {
                    Text(topic.text)
                    Spacer()
                    if isEditMode == .inactive {
                        interestButtons(for: topic)
                    } else {
                        deleteButton(for: topic)
                    }
                }
            }
            
            if (isEditMode == .active || feedModel.interestedTopics.isEmpty) {
                AddTopicInput()
            }
        }
    }
    
    private func interestButtons(for topic: Topic) -> some View {
        Group {
            Button(action: {
                Task {
                    if (topic.isInterested) {
                        await feedModel.setInterested(for: topic.id, isInterested: false)
                    }
                }
            }) {
                Image(systemName: topic.isInterested ? "hand.thumbsdown.circle" : "hand.thumbsdown.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 24))
                    .frame(width: 24, height: 24)
                    .opacity(topic.isInterested ? 0.5 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: {
                Task {
                    if (!topic.isInterested) {
                        await feedModel.setInterested(for: topic.id, isInterested: true)
                    }
                }
            }) {
                Image(systemName: topic.isInterested ? "hand.thumbsup.circle.fill" : "hand.thumbsup.circle")
                    .foregroundColor(.green)
                    .font(.system(size: 24))
                    .frame(width: 24, height: 24)
                    .opacity(topic.isInterested ? 1.0 : 0.5)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func deleteButton(for topic: Topic) -> some View {
        Button(action: {
            deletingTopicId = topic.id
            Task {
                await feedModel.deleteTopic(id: topic.id)
                deletingTopicId = nil
            }
        }) {
            if deletingTopicId == topic.id {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "trash.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 24))
                    .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(deletingTopicId != nil)
        .transition(.scale)
    }
}

struct AddTopicInput: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var newTopicText = ""
    @State private var isInterested = true

    var body: some View {
        HStack {
            TextField("Add Topic", text: $newTopicText)
            Spacer()
            Button(action: {
                isInterested.toggle()
            }) {
                Image(systemName: isInterested ? "hand.thumbsup.circle.fill" : "hand.thumbsdown.circle.fill")
                    .foregroundColor(isInterested ? .green : .red)
                    .font(.system(size: 24))
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: addNewTopic) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 24))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(newTopicText.isEmpty)
        }
    }
    
    private func addNewTopic() {
        Task {
            await feedModel.addNewTopic(text: newTopicText, isInterested: isInterested)
            newTopicText = ""
            isInterested = true
        }
    }
}
