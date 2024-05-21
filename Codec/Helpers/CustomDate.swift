//
//  CustomDate.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/21/24.
//

import Foundation

extension Date {
    func customFormatted() -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .day], from: self, to: now)
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        
        // Check if the difference is less than 12 hours
        if let hour = components.hour, hour < 12 {
            return relativeFormatter.localizedString(for: self, relativeTo: now)
        }
        
        // Check if the difference is less than 7 days
        if let day = components.day, day < 7 {
            return relativeFormatter.localizedString(for: self, relativeTo: now)
        }
        
        // Otherwise, format the date in a standard way
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: self)
    }
}
