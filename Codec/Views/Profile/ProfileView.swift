//
//  ProfileView.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var userVM: UserViewModel
    @State private var isLoading = false

    var body: some View {
        List {
            Section {
                NavigationLink(destination: TopicView()) {
                    Label("Manage Topics", systemImage: "tag")
                        .foregroundColor(.primary)
                }
                NavigationLink(destination: FeedFollowBlockView(isInterested: true)) {
                    Label("Followed Feeds", systemImage: "plus.circle")
                        .foregroundColor(.primary)
                }
                NavigationLink(destination: FeedFollowBlockView(isInterested: false)) {
                    Label("Blocked Feeds", systemImage: "xmark.shield")
                        .foregroundColor(.primary)
                }
// TODO: History tab
//                NavigationLink(destination: Text("History")) {
//                    Label("View History", systemImage: "book")
//                        .foregroundColor(.primary)
//                }
            }
            ActionSection()
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitle("@\(userVM.username ?? "error")", displayMode: .inline)
        .overlay(
            Group {
                if isLoading {
                    ProgressView()
                }
            }
        )
    }
}


#Preview {
    NavigationStack {
        ProfileView()
    }
    .previewWithEnvironment()
}
