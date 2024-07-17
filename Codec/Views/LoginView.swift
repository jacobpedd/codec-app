//
//  LoginView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/22/24.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var errorMessage: String?
    @State private var hasAccount: Bool = true
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Welcome")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
            
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
                    if isLoggingIn {
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
                .disabled(isLoggingIn)
            }
            
            HStack {
                Text(hasAccount ? "Don't have an account?" : "Already have an account?")
                Button {
                    hasAccount.toggle()
                    errorMessage = nil
                } label: {
                    Text(hasAccount ? "Sign up" : "Log in")
                }
                .foregroundStyle(.blue)
            }
            
            if let errorMessage = errorMessage {
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
        errorMessage = nil
        
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Username is required"
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Password is required"
            return
        }
        
        login()
    }
    
    private func login() {
        isLoggingIn = true
        
        guard let url = URL(string: "https://codec.fly.dev/auth/") else {
            errorMessage = "Invalid URL"
            isLoggingIn = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["username": username, "password": password]
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoggingIn = false
                
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                    feedModel.username = result.username
                    feedModel.token = result.token
                } catch {
                    errorMessage = "Invalid response from server"
                }
            }
        }.resume()
    }
    
    private func validateAndSignup() {
        errorMessage = nil
        
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Username is required"
            return
        }
        
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Email is required"
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Password is required"
            return
        }
        
        // Additional password validation
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters long"
            return
        }
        
        guard password.rangeOfCharacter(from: .letters) != nil else {
            errorMessage = "Password must contain at least one letter"
            return
        }
        
        guard password.rangeOfCharacter(from: .decimalDigits) != nil else {
            errorMessage = "Password must contain at least one digit"
            return
        }
        
        signup()
    }
    
    private func signup() {
        isLoggingIn = true
        
        guard let url = URL(string: "https://codec.fly.dev/register/") else {
            errorMessage = "Invalid URL"
            isLoggingIn = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["username": username, "email": email, "password": password]
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoggingIn = false
                
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                    feedModel.username = result.username
                    feedModel.token = result.token
                } catch {
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        errorMessage = errorResponse.error
                    } else {
                        errorMessage = "Invalid response from server"
                    }
                }
            }
        }.resume()
    }
}

struct AuthResponse: Codable {
    let token: String
    let userId: Int
    let username: String
    let email: String
    
    enum CodingKeys: String, CodingKey {
        case token
        case userId = "user_id"
        case username
        case email
    }
}

struct ErrorResponse: Codable {
    let error: String
}

#Preview {
    LoginView()
        .environmentObject(FeedModel())
}
