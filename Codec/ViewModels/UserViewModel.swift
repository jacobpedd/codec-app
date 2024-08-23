//
//  UserViewModel.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/20/24.
//

import SwiftUI

class UserViewModel: ObservableObject {
    @Published var token: String? {
        didSet {
            UserDefaults.standard.set(token, forKey: "token")
        }
    }
    @Published var username: String? {
        didSet {
            UserDefaults.standard.set(username, forKey: "username")
        }
    }
    @Published var isLoggingIn = false
    @Published var isOnboarding: Bool = false
    @Published var errorMessage: String?
    
    var onLogin: ((String?) -> Void)?
    var onLogout: (() -> Void)?
    
    init() {
        self.token = UserDefaults.standard.string(forKey: "token")
        self.username = UserDefaults.standard.string(forKey: "username")
    }
    
    func login(username: String, password: String) async {
        await MainActor.run {
            isLoggingIn = true
            errorMessage = nil
        }
        
        do {
            let (data, response) = try await loginRequest(username: username, password: password)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            await MainActor.run {
                self.username = authResponse.username
                self.token = authResponse.token
                isLoggingIn = false
                self.onLogin?(self.token)
            }
        } catch {
            await MainActor.run {
                isLoggingIn = false
                errorMessage = "Error logging in."
            }
        }
    }
    
    private func loginRequest(username: String, password: String) async throws -> (Data, URLResponse) {
        guard let url = URL(string: "https://codec.fly.dev/auth/") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await URLSession.shared.data(for: request)
    }
    
    func logout() {
        // Clear all published properties
        token = nil
        username = nil
        isLoggingIn = false
        isOnboarding = false
        errorMessage = nil
        
        // Remove data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "token")
        UserDefaults.standard.removeObject(forKey: "username")
        onLogout?()
    }

    
    func signup(username: String, email: String, password: String) async {
        await MainActor.run {
            isLoggingIn = true
            errorMessage = nil
        }
        
        do {
            let (data, response) = try await signupRequest(username: username, email: email, password: password)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            await MainActor.run {
                self.isOnboarding = true
                self.username = authResponse.username
                self.token = authResponse.token
                isLoggingIn = false
                self.onLogin?(self.token)
            }
        } catch {
            await MainActor.run {
                isLoggingIn = false
                errorMessage = "Error signing up"
            }
        }
    }
    
    private func signupRequest(username: String, email: String, password: String) async throws -> (Data, URLResponse) {
        guard let url = URL(string: "https://codec.fly.dev/register/") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["username": username, "email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await URLSession.shared.data(for: request)
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
