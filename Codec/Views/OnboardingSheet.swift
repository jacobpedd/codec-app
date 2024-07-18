//
//  OnboardingSheet.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/16/24.
//

import SwiftUI

struct OnboardingSheet: View {
    @EnvironmentObject private var feedModel: FeedModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isEditMode: EditMode = .active
    @State private var showingSearchView = false
    
    private var canContinue: Bool {
        !feedModel.needsOnboarding && !isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Add at least 3 shows so our algorithm\ncan learn your taste.")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.clear)
                    .padding(.bottom)
                
                List {
                    FollowingSection(isEditMode: $isEditMode, showSearchView: $showingSearchView)
                        .disabled(isLoading)
                }
                .listStyle(InsetGroupedListStyle())
                
                Spacer()
                
                Button(action: onboard) {
                    HStack {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Generating your feed...")
                            }
                        } else {
                            Text("Continue")
                        }
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .opacity(canContinue ? 1.0 : 0.3)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!canContinue)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Get Started")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear(perform: loadProfileData)
        .sheet(isPresented: $showingSearchView) {
            NavigationStack {
                SearchView()
            }
        }
        .disabled(isLoading)
    }
    
    private func loadProfileData() {
        isLoading = true
        Task {
            await feedModel.load()
            isLoading = false
        }
    }
    
    private func onboard() {
        Task {
            isLoading = true
            await feedModel.load()
            isLoading = false
            isPresented = false
        }
    }
}
