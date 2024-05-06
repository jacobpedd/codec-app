//
//  ContentView.swift
//  Codec
//
//  Created by Jacob Peddicord on 5/6/24.
//

import SwiftUI
import SwiftData
import BigUIPaging

struct ContentView: View {
    @State private var selection: Int = 0
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .gray, .mint, .teal, .indigo]

    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                PageView(selection: $selection) {
                    ForEach(0...10, id: \.self) { id in
                        VStack {
                            VStack {
                                Spacer()
                                Text("Page \(id)")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white)
                                
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .background(colors[id % colors.count])
                        .gesture(DragGesture())
                    }
                }
                .pageViewStyle(.cardDeck)
                PageIndicator(selection: $selection, total: 11){ (page, selected) in
                    if page == 0 {
                        Image(systemName: "play.fill")
                    }
                }
                    .pageIndicatorColor(.gray)
                    .pageIndicatorCurrentColor(.accentColor)
                    .pageIndicatorBackgroundStyle(.prominent)
                    .allowsContinuousInteraction(false)
            }
            .padding(.bottom)
            .frame(height: geometry.size.height * 0.7)
            .edgesIgnoringSafeArea(.bottom)
            .sheet(isPresented: .constant(true), onDismiss: {}) {
                VStack(spacing: 15) {
                    TextField("Search", text: .constant(""))
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.ultraThickMaterial)
                        }
                    Spacer()
                }
                .padding()
                .presentationDetents([.large, .fraction(0.3)])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .presentationBackgroundInteraction(.enabled)
                
            }
            
        }
    }
}

#Preview {
    ContentView()
}
