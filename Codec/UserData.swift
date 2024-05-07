//
//  UserData.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/7/24.
//

import Foundation

@Observable
class UserData {
    var feed = [Topic]()
    var feedIndex: Int = 0
    var history = [Topic]()
    var dismissed = [Topic]()
    
    init(feed: [Topic] = [Topic](), feedIndex: Int = 0, history: [Topic] = [Topic](), dismissed: [Topic] = [Topic]()) {
        self.feed = feed
        self.feedIndex = feedIndex
        self.history = history
        self.dismissed = dismissed
    }
}
