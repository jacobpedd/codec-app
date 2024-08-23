//
//  LoginView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/22/24.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var userVM: UserViewModel
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var hasAccount: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Welcome")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !hasAccount {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
            }
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button(action: {
                submit()
            }) {
                ZStack {
                    if userVM.isLoggingIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(hasAccount ? "Log In" : "Sign Up")
                    }
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(userVM.isLoggingIn)
            }
            
            HStack {
                Text(hasAccount ? "Don't have an account?" : "Already have an account?")
                Button {
                    hasAccount.toggle()
                    userVM.errorMessage = nil
                } label: {
                    Text(hasAccount ? "Sign up" : "Log in")
                }
                .foregroundStyle(.blue)
            }
            
            if let errorMessage = userVM.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .animation(.easeInOut, value: hasAccount)
    }
    
    private func submit() {
        if hasAccount {
            validateAndLogin()
        } else {
            validateAndSignup()
        }
    }
    
    private func validateAndLogin() {
        userVM.errorMessage = nil
        
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            userVM.errorMessage = "Username is required"
            return
        }
        
        guard !password.isEmpty else {
            userVM.errorMessage = "Password is required"
            return
        }
        
        Task {
            await userVM.login(username: username, password: password)
        }
    }
    
    private func validateAndSignup() {
        userVM.errorMessage = nil
        
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            userVM.errorMessage = "Username is required"
            return
        }
        
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            userVM.errorMessage = "Email is required"
            return
        }
        
        guard !password.isEmpty else {
            userVM.errorMessage = "Password is required"
            return
        }
        
        // Additional password validation
        guard password.count >= 8 else {
            userVM.errorMessage = "Password must be at least 8 characters long"
            return
        }
        
        guard password.rangeOfCharacter(from: .letters) != nil else {
            userVM.errorMessage = "Password must contain at least one letter"
            return
        }
        
        guard password.rangeOfCharacter(from: .decimalDigits) != nil else {
            userVM.errorMessage = "Password must contain at least one digit"
            return
        }
        
        signup()
    }
    
    private func signup() {
        Task {
            await userVM.signup(username: username, email: email, password: password)
        }
    }
}

#Preview {
    LoginView()
        .previewWithEnvironment()
}
