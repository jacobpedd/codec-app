//
//  TopicCardView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/7/24.
//

import SwiftUI
import BigUIPaging
import ColorKit

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

struct TopicView: View {
    var index: Int
    @EnvironmentObject var userModel: UserModel
    @EnvironmentObject var playerModel: AudioPlayerModel
    var topic: Topic {
        return userModel.feed[index]
    }
    
    var image: Artwork? {
        return userModel.topicArtworks[topic.id]
    }
    
    var bgColor: Color {
        return image?.bgColor ?? .gray
    }
    
    var shadwoColor: Color {
        return image?.shadowColor ?? .gray
    }
    
    func onPlay() {
        // Switch to the current index
        userModel.playingIndex = index
        
        // Play if it wasn't already playing
        if (!playerModel.isPlaying) {
            playerModel.playPause()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                VStack {
                    if let image = image {
                        Image(uiImage: image.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.height, height: geometry.size.height)
                            .clipped()
                            .cornerRadius(15)
                            .shadow(color: image.shadowColor, radius: 20)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(
                    topic.createdAt.customFormatted()
                )
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.bottom, 2)
                
                Text(topic.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(3)
                    .foregroundStyle(.white)
                
                Spacer()
                HStack {
                    if (userModel.playingIndex == index) {
                        Text("Now Playing")
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                    } else {
                        Button(action: onPlay) {
                            HStack {
                                Image(systemName: "play.fill")
                                    .foregroundStyle(bgColor)
                                Text("Play")
                                    .fontWeight(.bold)
                                    .foregroundStyle(bgColor)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .background(.white)
                        .cornerRadius(30)
                        .shadow(color: shadwoColor, radius: 20)
                    }
                    Spacer()
                }
                .frame(minHeight: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bgColor)
        .cornerRadius(10)
    }
}

#Preview {
    let topic = Topic(id: 0, title: "Deepfakes Shatter Trust in 2024 Election Reality", script: "", audio: "62a9e81834fbf4ebecea4403ed713117", image: "495b1a1f839200a3ea096019a582f176", createdAt: .now)
    
    return VStack {
        PageView(selection: Binding(get: {
            return 0
        }, set: {_,_ in })) {
            ForEach(0..<1, id: \.self) { index in
                TopicView(index: 0)
            }
        }
        .pageViewStyle(.cardDeck)
        .pageViewCardCornerRadius(15)
        .frame(height: 550)
    }
    .environmentObject(UserModel())
}
