//
//  LoginView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/22/24.
//

import SwiftUI

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
                .autocapitalization(.none)
            
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
