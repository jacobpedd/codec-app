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
                    await feedModel.setInterested(for: topic.id, isInterested: !topic.isInterested)
                }
            }) {
                Image(systemName: topic.isInterested ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .foregroundColor(topic.isInterested ? .green : .red)
                    .frame(width: 24, height: 24)
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
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
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
                Image(systemName: isInterested ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .foregroundColor(isInterested ? .green : .red)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: addNewTopic) {
                Image(systemName: "plus")
                    .foregroundColor(.blue)
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
