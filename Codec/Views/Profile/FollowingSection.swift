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
    @Binding var showSearchView: Bool

    var body: some View {
        Section(header: Text("Following")) {
            ForEach(feedModel.followedFeeds) { follows in
                HStack() {
                    if let image = feedModel.feedArtworks[follows.feed.id] {
                        Image(uiImage: image.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(5)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(.ultraThickMaterial)
                                .frame(width: 60, height: 60)
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                    Text(follows.feed.name)
                        .lineLimit(1)
                    Spacer()
                    if isEditMode == .active {
                        unfollowButton(for: follows)
                    }
                }
            }
            if feedModel.followedFeeds.isEmpty || isEditMode == .active {
                Button(action: { showSearchView = true }) {
                    HStack {
                        Text("Add Show")
                        Spacer()
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
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
