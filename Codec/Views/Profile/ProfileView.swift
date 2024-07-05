//
//  ProfileView.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var isLoading = false
    @State private var isEditMode: EditMode = .inactive

    var body: some View {
        if let username = feedModel.username {
            List {
                FollowingSection(isEditMode: $isEditMode)
                TopicsSection(isEditMode: $isEditMode)
                ActionSection()
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("@\(username)", displayMode: .inline)
            .onAppear(perform: loadProfileData)
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
                    Button(action: toggleEditMode) {
                        Text(isEditMode == .active ? "Done" : "Edit")
                    }
                }
            }
        } else {
            Text("Not logged in")
                .font(.headline)
        }
    }
    
    private func loadProfileData() {
        if feedModel.followedFeeds.isEmpty || feedModel.interestedTopics.isEmpty {
            isLoading = true
            Task {
                await feedModel.loadProfileData()
                isLoading = false
            }
        }
    }
    
    private func toggleEditMode() {
        withAnimation {
            isEditMode = isEditMode == .active ? .inactive : .active
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
