//
//  Artwork.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/9/24.
//

import Foundation
import SwiftUI
import UIKit

extension UIImage {
    /// There are two main ways to get the color from an image, just a simple "sum up an average" or by squaring their sums. Each has their advantages, but the 'simple' option *seems* better for average color of entire image and closely mirrors CoreImage. Details: https://sighack.com/post/averaging-rgb-colors-the-right-way\
    
    func findAverageColor() -> UIColor? {
        guard let cgImage = cgImage else { return nil }
        
        // First, resize the image. We do this for two reasons, 1) less pixels to deal with means faster calculation and a resized image still has the "gist" of the colors, and 2) the image we're dealing with may come in any of a variety of color formats (CMYK, ARGB, RGBA, etc.) which complicates things, and redrawing it normalizes that into a base color format we can deal with.
        // 40x40 is a good size to resize to still preserve quite a bit of detail but not have too many pixels to deal with. Aspect ratio is irrelevant for just finding average color.
        let size = CGSize(width: 40, height: 40)
        
        let width = Int(size.width)
        let height = Int(size.height)
        let totalPixels = width * height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // ARGB format
        let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        
        // 8 bits for each color channel, we're doing ARGB so 32 bits (4 bytes) total, and thus if the image is n pixels wide, and has 4 bytes per pixel, the total bytes per row is 4n. That gives us 2^8 = 256 color variations for each RGB channel or 256 * 256 * 256 = ~16.7M color options in total. That seems like a lot, but lots of HDR movies are in 10 bit, which is (2^10)^3 = 1 billion color options!
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }

        // Draw our resized image
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        guard let pixelBuffer = context.data else { return nil }
        
        // Bind the pixel buffer's memory location to a pointer we can use/access
        let pointer = pixelBuffer.bindMemory(to: UInt32.self, capacity: width * height)

        // Keep track of total colors (note: we don't care about alpha and will always assume alpha of 1, AKA opaque)
        var totalRed = 0
        var totalBlue = 0
        var totalGreen = 0
        
        // Column of pixels in image
        for x in 0 ..< width {
            // Row of pixels in image
            for y in 0 ..< height {
                // To get the pixel location just think of the image as a grid of pixels, but stored as one long row rather than columns and rows, so for instance to map the pixel from the grid in the 15th row and 3 columns in to our "long row", we'd offset ourselves 15 times the width in pixels of the image, and then offset by the amount of columns
                let pixel = pointer[(y * width) + x]
                
                let r = red(for: pixel)
                let g = green(for: pixel)
                let b = blue(for: pixel)
                totalRed += Int(r)
                totalBlue += Int(b)
                totalGreen += Int(g)
            }
        }
        
        let averageRed: CGFloat
        let averageGreen: CGFloat
        let averageBlue: CGFloat
        
        averageRed = CGFloat(totalRed) / CGFloat(totalPixels)
        averageGreen = CGFloat(totalGreen) / CGFloat(totalPixels)
        averageBlue = CGFloat(totalBlue) / CGFloat(totalPixels)

        
        // Convert from [0 ... 255] format to the [0 ... 1.0] format UIColor wants
        return UIColor(red: averageRed / 255.0, green: averageGreen / 255.0, blue: averageBlue / 255.0, alpha: 1.0)
    }
    
    private func red(for pixelData: UInt32) -> UInt8 {
        return UInt8((pixelData >> 16) & 255)
    }

    private func green(for pixelData: UInt32) -> UInt8 {
        return UInt8((pixelData >> 8) & 255)
    }

    private func blue(for pixelData: UInt32) -> UInt8 {
        return UInt8((pixelData >> 0) & 255)
    }
}

extension Color {
    static func darkerColor(for color: UIColor, amount: CGFloat = 0.2) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return Color(UIColor(red: max(r - amount, 0.0), green: max(g - amount, 0.0), blue: max(b - amount, 0.0), alpha: a))
        }
        return Color(color)
    }
}

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
