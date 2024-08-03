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
    @State private var showingSearchView = false
    @State private var isAddingToBlocked = false

    var body: some View {
        if let username = feedModel.username {
            List {
                FollowingSection(isEditMode: $isEditMode, showSearchView: showSearchViewBinding, isAddingToBlocked: $isAddingToBlocked)
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
            .sheet(isPresented: $showingSearchView) {
                NavigationView {
                    SearchView(isAddingToBlocked: $isAddingToBlocked)
                }
            }
        } else {
            Text("Not logged in")
                .font(.headline)
        }
    }
    
    private var showSearchViewBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.showingSearchView },
            set: { newValue in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showingSearchView = newValue
                }
            }
        )
    }
    
    private func loadProfileData() {
        if feedModel.followedFeeds.isEmpty {
            isLoading = true
            Task {
                await feedModel.load()
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
