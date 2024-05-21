////
////  ViewRecorder.swift
////  Codec
////
////  Created by Jacob Peddicord on 5/20/24.
////
//
//import SwiftUI
//
//struct ViewRecorder: View {
//    @EnvironmentObject var userModel: UserModel
//    @EnvironmentObject var playerModel: AudioPlayerModel
//    
//    @State var currentTopicUuid: String?
//    @State var currentTime: Double = 0
//    
//    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
//    
//    var body: some View {
//        VStack {}
//        .frame(width: 0, height: 0)
//        .onReceive(timer) { _ in
//            if let playingTopicUuid = userModel.playingTopic?.uuid {
//                if playingTopicUuid != currentTopicUuid {
//                    // Topic change, should update
//                    print("\(userModel.playingTopic?.title): \(playerModel.currentTime)")
//                    currentTopicUuid = playingTopicUuid
//                    currentTime = currentTime
//                    recordView(id: playingTopicUuid, time: currentTime)
//                } else {
//                    // Same topic, update if time chaged
//                    let timeDiff = abs(playerModel.currentTime - currentTime)
//                    if timeDiff > 1 {
//                        // Time changed, should update
//                        print("\(userModel.playingTopic?.title): \(playerModel.currentTime)")
//                        currentTime = playerModel.currentTime
//                        recordView(id: playingTopicUuid, time: currentTime)
//                    }
//                }
//            }
//        }
//    }
//    
//    private func recordView(id: String, time: Double) {
//        guard let url = URL(string: "https://api.wirehead.tech/view") else {
//            print("Invalid URL")
//            return
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        
//        let body: [String: Any] = ["itemId": id, "duration": time, "email": "jacob.peddicord@hey.com"]
//        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                print("Error: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let data = data else {
//                print("No data received")
//                return
//            }
//            
//            if let responseString = String(data: data, encoding: .utf8) {
//                print("Response: \(responseString)")
//            }
//        }.resume()
//    }
//}
