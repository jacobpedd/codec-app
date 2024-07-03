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
    @State private var password: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Login")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
            
            Button(action: {
                validateAndLogin()
            }) {
                if isLoggingIn {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Login")
                }
            }
            .disabled(isLoggingIn)
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Spacer()
        }
        .padding(.horizontal, 40)
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
                    feedModel.token = result.token
                    feedModel.username = result.username
                } catch {
                    errorMessage = "Invalid response from server"
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

#Preview {
    LoginView()
        .environmentObject(FeedModel())
}
