//
//  FollowingSection.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import SwiftUI

struct FeedFollowBlockView: View {
    @EnvironmentObject private var userVM: UserViewModel
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var artworkVM: ArtworkViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var unfollowingId: Int?
    @State private var showSearchView = false
    var isInterested: Bool

    private let minimumFeeds = 3

    var body: some View {
        let feeds = profileVM.followedFeeds.filter { $0.isInterested == isInterested }
        let title = isInterested ? "Following" : "Muted"
        
        NavigationStack {
            VStack {
                if (profileVM.followedFeeds.isEmpty) {
                    HStack(alignment: .center) {
                        Text("Use the + button in the top right corner to follow a podcast.")
                            .padding()
                            .padding()
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                }
                List {
                    ForEach(feeds) { follows in
                        HStack {
                            ArtworkView(feed: follows.feed)
                                .frame(width: 60, height: 60)
                                .cornerRadius(5)
                            Text(follows.feed.name)
                                .lineLimit(1)
                            Spacer()
                            actionButton(for: follows)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if profileVM.followedFeeds.filter({ $0.isInterested }).count < minimumFeeds {
                        Text("Please follow at least \(minimumFeeds) feeds")
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding()
                    }
                }
                if userVM.isOnboarding {
                    NavigationLink(destination: FeedView()) {
                        HStack {
                            Text("Continue")
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .opacity(profileVM.followedFeeds.filter({ $0.isInterested }).count >= minimumFeeds ? 1.0 : 0.3)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(profileVM.followedFeeds.filter({ $0.isInterested }).count < minimumFeeds)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle(title)
            .navigationBarItems(trailing: addButton)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if profileVM.followedFeeds.filter({ $0.isInterested }).count >= minimumFeeds {
                            profileVM.isUserSelecting = false
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .disabled(profileVM.followedFeeds.filter({ $0.isInterested }).count < minimumFeeds)
                }
            }
            .sheet(isPresented: $showSearchView) {
                SearchView(isInterested: isInterested)
            }
        }
        .onAppear() {
            profileVM.isUserSelecting = true
        }
    }
    
    private var addButton: some View {
        Button(action: {
            showSearchView = true
        }) {
            Image(systemName: "plus")
                .foregroundColor(.blue)
        }
    }
    
    private func actionButton(for follows: UserFeedFollow) -> some View {
        Button(action: {
            unfollowingId = follows.id
            Task {
                await profileVM.unfollowShow(followId: follows.id)
                unfollowingId = nil
            }
        }) {
            if unfollowingId == follows.id {
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
        .disabled(unfollowingId != nil)
        .transition(.scale)
    }
}

#Preview {
    NavigationStack {
        FeedFollowBlockView(isInterested: true)
    }
    .previewWithEnvironment()
}
