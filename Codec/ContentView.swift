//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var fetchingNewTopics: Bool = false
    @State private var emailInput: String = ""
    
    var body: some View {
        if feedModel.email != "" {
            if feedModel.nowPlaying != nil {
                FeedView()
            } else {
                ProgressView()
                    .task {
                        await feedModel.load()
                    }
            }
        } else {
            EmailInputView(emailInput: $emailInput) {
                feedModel.email = emailInput
                // Dismiss the keyboard
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

struct EmailInputView: View {
    @Binding var emailInput: String
    var onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Login")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Enter your email to continue")
                .font(.body)
                .foregroundColor(.gray)
            
            TextField("Email", text: $emailInput)
                .keyboardType(.emailAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.vertical, 10)
            
            Button(action: {
                onSubmit()
            }) {
                Text("Submit")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Text("Warning: Auth isn't really implemented yet. I just use your email to track your views.")
                .font(.footnote)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    return ContentView()
        .environmentObject(FeedModel())
}
