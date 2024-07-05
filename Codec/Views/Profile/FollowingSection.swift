//
//  FollowingSection.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import SwiftUI

struct FollowingSection: View {
    @EnvironmentObject private var feedModel: FeedModel
    @Binding var isEditMode: EditMode
    @State private var unfollowingId: Int?

    var body: some View {
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
                            unfollowButton(for: follows)
                        }
                    }
                }
            }
        }
    }
    
    private func unfollowButton(for follows: UserFeedFollow) -> some View {
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
