//
//  ProfileView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/22/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var feedModel: FeedModel

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Email")
                    .font(.headline)
                
                Text(feedModel.token ?? "not logged in")
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            .padding()

            Button(action: {
                feedModel.logout()
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                        .foregroundColor(.white)
                    Text("Log Out")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(Color.red)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button(action: {
                if let url = URL(string: "sms:9138277665") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "message.fill")
                        .foregroundColor(.white)
                    Text("Text Jacob")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationBarTitle("Profile", displayMode: .inline)
    }
}

#Preview {
    return ProfileView()
        .environmentObject(FeedModel())
}
