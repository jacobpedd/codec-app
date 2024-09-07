//
//  QueueListView.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/28/24.
//

import SwiftUI

struct QueueListView: View {
    @EnvironmentObject private var feedVM: FeedViewModel
    @EnvironmentObject private var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var upNextClips: [Clip] = []
    
    var body: some View {
        VStack(spacing: 0) {
            QueueListHeader(dismissAction: { dismiss() })
            
            if feedVM.currentFeed.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List {
                    ForEach(Array(upNextClips.enumerated()), id: \.element.id) { index, clip in
                        QueueRowView(clip: clip)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
                .listStyle(PlainListStyle())
            }
        }
        .onAppear {
            updateUpNextClips()
        }
        .onChange(of: feedVM.currentFeed) {
            updateUpNextClips()
        }
        .onChange(of: feedVM.nowPlayingIndex) {
            updateUpNextClips()
        }
    }
    
    private func updateUpNextClips() {
        upNextClips = Array(feedVM.currentFeed.dropFirst(feedVM.nowPlayingIndex + 1))
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        let offset = feedVM.nowPlayingIndex + 1
        let newSource = IndexSet(source.map { $0 + offset })
        let newDestination = destination + offset
        
        // Check if the clip is being dropped in its original position
        if newSource.contains(newDestination) || newSource.contains(newDestination - 1) {
            return // Exit the function if the position hasn't changed
        }
        
        feedVM.moveClips(from: newSource, to: newDestination)
        
        // Update the local upNextClips array
        let movedClips = source.map { upNextClips[$0] }
        upNextClips.remove(atOffsets: source)
        upNextClips.insert(contentsOf: movedClips, at: destination)
    }
    
    private func delete(at offsets: IndexSet) {
        let offset = feedVM.nowPlayingIndex + 1
        let adjustedOffsets = IndexSet(offsets.map { $0 + offset })
        
        for index in adjustedOffsets.sorted(by: >) {
            Task {
                await feedVM.deleteClip(at: index)
            }
        }
        upNextClips.remove(atOffsets: offsets)
    }
}
    

struct QueueListHeader: View {
    let dismissAction: () -> Void
    
    var body: some View {
        HStack {
            Text("Up Next")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Button("Done", action: dismissAction)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

struct QueueRowView: View {
    let clip: Clip
    
    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(feed: clip.feedItem.feed)
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(clip.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(clip.feedItem.feed.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

struct QueueListView_Previews: PreviewProvider {
    static var previews: some View {
        QueueListView()
            .previewWithEnvironment()
    }
}
