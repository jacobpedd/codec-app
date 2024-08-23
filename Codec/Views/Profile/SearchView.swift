//
//  SearchView.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var feedSearchVM: FeedSearchViewModel
    @Environment(\.presentationMode) var presentationMode
    var isInterested: Bool

    var body: some View {
        NavigationView {
            List {
                if feedSearchVM.searchResults.isEmpty {
                    Text("No results")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(feedSearchVM.searchResults) { show in
                        Button(action: {
                            followOrBlockShow(show)
                        }) {
                            HStack {
                                Text(show.name)
                                    .lineLimit(2)
                                Spacer()
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .navigationTitle(isInterested ? "Follow Show" : "Block Show")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(text: $feedSearchVM.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for shows")
    }

    private func followOrBlockShow(_ show: Feed) {
        Task {
            let success = await profileVM.followShow(feed: show, isInterested: isInterested)
            if success {
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchView(isInterested: true)
    }
    .previewWithEnvironment()
}

