//
//  ProfileView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/22/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var isLoading = false
    @State private var isEditMode: EditMode = .inactive
    @State private var newTopicText = ""
    @State private var isInterested = true
    @State private var unfollowingId: Int?
    @State private var deletingTopicId: Int?


    var body: some View {
        if let username = feedModel.username {
            List {
                Section(header: Text("Following")) {
                    if feedModel.followedFeeds.isEmpty {
                        Text("You're not following any shows.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(feedModel.followedFeeds) { follows in
                            HStack {
                                if let image = feedModel.feedArtworks[follows.feed.id] {
                                    Image(uiImage: image.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(5)
                                } else {
                                    Rectangle()
                                        .fill(Color.gray)
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(5)
                                }
                                Text(follows.feed.name)
                                Spacer()
                                if isEditMode == .active {
                                    Button(action: {
                                        unfollowingId = follows.id
                                        Task {
                                            await feedModel.unfollowShow(followId: follows.id)
                                            unfollowingId = nil
                                        }
                                    }) {
                                        if unfollowingId == follows.id {
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
                                    .disabled(unfollowingId != nil)
                                    .transition(.scale)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Topics")) {
                    if feedModel.interestedTopics.isEmpty {
                        addTopicInput
                    } else {
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
                        
                        if isEditMode == .active {
                            addTopicInput
                        }
                    }
                }
                
                Section {
                    Button(action: feedModel.logout) {
                        HStack {
                            Text("Log Out")
                            Spacer()
                            Image(systemName: "lock.fill")
                                .frame(width: 24, height: 24)
                        }
                    }
                    .foregroundColor(.red)
                    
                    Button(action: sendMessageToJacob) {
                        HStack {
                            Text("Text Jacob")
                            Spacer()
                            Image(systemName: "message.fill")
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("@\(username)", displayMode: .inline)
            .onAppear {
                if feedModel.followedFeeds.isEmpty || feedModel.interestedTopics.isEmpty {
                    loadProfileData()
                }
            }
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                    }
                }
            )
            .environment(\.editMode, $isEditMode)
            .animation(.default, value: isEditMode)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            isEditMode = isEditMode == .active ? .inactive : .active
                        }
                    }) {
                        Text(isEditMode == .active ? "Done" : "Edit")
                    }
                }
            }
        } else {
            Text("Not logged in")
                .font(.headline)
        }
    }
    
    private var addTopicInput: some View {
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
            Button(action: {
                Task {
                    await feedModel.addNewTopic(text: newTopicText, isInterested: isInterested)
                    newTopicText = ""
                    isInterested = true
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 24))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(newTopicText.isEmpty)
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
    
    private func sendMessageToJacob() {
        if let url = URL(string: "sms:9138277665") {
            UIApplication.shared.open(url)
        }
    }
    
    private func loadProfileData() {
        isLoading = true
        Task {
            await feedModel.loadProfileData()
            isLoading = false
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView()
                .environmentObject(FeedModel())
        }
    }
}

