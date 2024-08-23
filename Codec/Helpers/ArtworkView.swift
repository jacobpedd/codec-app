//
//  ArtworkView.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/22/24.
//

import SwiftUI

struct ArtworkView: View {
    @EnvironmentObject private var artworkVM: ArtworkViewModel
    @State private var artwork: Artwork?
    let feed: Feed

    var body: some View {
        Group {
            if let image = artwork?.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.ultraThickMaterial)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
        }
        .onChange(of: feed) {
            loadArtwork()
        }
        .onAppear {
            loadArtwork()
        }
        .id(feed.id) // Force view update when feed changes
    }

    private func loadArtwork() {
        artworkVM.loadArtwork(for: feed) { loadedArtwork in
            DispatchQueue.main.async {
                self.artwork = loadedArtwork
            }
        }
    }
}
