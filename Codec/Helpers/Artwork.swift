//
//  Artwork.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/9/24.
//

import Foundation
import UIKit
import SwiftUI

struct Artwork {
    var image: UIImage
    var bgColor: Color
    var shadowColor: Color
    
    init(image: UIImage) {
        self.image = image
        self.bgColor = Color(image.findAverageColor() ?? UIColor.gray)
        self.shadowColor = Color.darkerColor(for: UIColor(bgColor)).opacity(0.3)
    }
}
