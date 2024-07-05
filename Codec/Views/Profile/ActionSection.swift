//
//  ActionSection.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/5/24.
//

import SwiftUI

struct ActionSection: View {
    @EnvironmentObject private var feedModel: FeedModel

    var body: some View {
        Section {
            Button(action: feedModel.logout) {
                HStack {
                    Text("Log Out")
                    Spacer()
                    Image(systemName: "lock.fill")
                        .frame(width: 24, height: 24)
                }
            }
            .foregroundColor(.red)
            
            Button(action: sendMessageToJacob) {
                HStack {
                    Text("Text Jacob")
                    Spacer()
                    Image(systemName: "message.fill")
                        .frame(width: 24, height: 24)
                }
            }
        }
    }
    
    private func sendMessageToJacob() {
        if let url = URL(string: "sms:9138277665") {
            UIApplication.shared.open(url)
        }
    }
}
