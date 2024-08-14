//
//  FeedHeaderView.swift
//  Codec
//
//  Created by Jacob Peddicord on 8/14/24.
//

import SwiftUI

struct CategoryButton: View {
    let text: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(text)
                    .font(.system(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(isActive ? .primary : .secondary)
                    .padding(.vertical, 12)
                
                Rectangle()
                    .fill(isActive ? Color.black : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

struct UnderlineModifier: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 2)
            content
            GeometryReader { geometry in
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width, height: 2)
            }
            .frame(height: 2)
        }
    }
}

struct FeedHeaderView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @State private var selectedCategory: String = "For You"
    
    let categories = ["For You", "Sports", "Tech", "Entertainment", "Basketball"]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ScrollViewReader { reader in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(categories, id: \.self) { category in
                                CategoryButton(text: category, isActive: category == selectedCategory) {
                                    withAnimation {
                                        selectedCategory = category
                                        reader.scrollTo(category)
                                    }
                                }
                                .id(category)
                            }
                        }
                    }
                }
                
                Spacer()
                
                NavigationLink(destination: ProfileView().environmentObject(feedModel)) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .contentShape(Rectangle()) // Capture all taps
        .onTapGesture { }
        .background(.thinMaterial)
        
    }
}
