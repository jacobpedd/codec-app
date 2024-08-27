//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var userVM: UserViewModel
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var categoryVM: CategoryViewModel
    @State private var showOnboarding = false
    @State private var navigateToTopics = false
    @State private var navigateToFollows = false

    var body: some View {
        Group {
            if userVM.token != nil && userVM.username != nil {
                AuthenticatedView(showOnboarding: $showOnboarding, navigateToTopics: $navigateToTopics, navigateToFollows: $navigateToFollows)
            } else {
                LoginView()
            }
        }
        .onAppear {
            showOnboarding = userVM.isOnboarding
        }
        .onChange(of: userVM.token) {
            if userVM.token == nil {
                // Reset navigation state on logout
                showOnboarding = false
                navigateToTopics = false
                navigateToFollows = false
            }
        }
    }
}

struct AuthenticatedView: View {
    @Binding var showOnboarding: Bool
    @Binding var navigateToTopics: Bool
    @Binding var navigateToFollows: Bool
    @EnvironmentObject private var userVM: UserViewModel
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var categoryVM: CategoryViewModel

    var body: some View {
        NavigationStack {
            if !userVM.isOnboarding {
                FeedView()
                    .border(.black, width: 8)
                    .onAppear {
                        checkTopics()
                        checkFollows()
                    }
                    .onChange(of: categoryVM.userCategories) {
                        checkTopics()
                    }
                    .onChange(of: categoryVM.isLoading) {
                        checkTopics()
                    }
                    .onChange(of: profileVM.followedFeeds) {
                        checkFollows()
                    }
                    .onChange(of: profileVM.isLoading) {
                        checkFollows()
                    }
                    .navigationDestination(isPresented: $navigateToTopics) {
                        TopicView()
                    }
                    .navigationDestination(isPresented: $navigateToFollows) {
                        FeedFollowBlockView(isInterested: true)
                    }
            } else {
                // TopicView in onboarding mode
                TopicView()
            }
        }
    }

    func checkTopics() {
        if categoryVM.userCategories.count < 5 && !categoryVM.isUserSelecting && !categoryVM.isLoading {
            categoryVM.isUserSelecting = true
            navigateToTopics = true
        }
    }

    func checkFollows() {
        if profileVM.followedFeeds.count < 3 && !profileVM.isUserSelecting && !profileVM.isLoading {
            navigateToFollows = true
        }
    }
}

#Preview {
    ContentView()
        .previewWithEnvironment()
}
