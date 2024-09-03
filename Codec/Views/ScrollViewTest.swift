import SwiftUI

struct ScrollViewTest: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 0) {
                Spacer()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(0..<100) { number in
                                VStack(alignment: .center, spacing: 0) {
                                    Spacer()
                                        .frame(height: geometry.size.width * 0.05)
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.blue)
                                        .overlay(
                                            Text("\(number)")
                                                .font(.largeTitle)
                                                .foregroundColor(.white)
                                        )
                                        .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
                                    Spacer()
                                        .frame(height: geometry.size.width * 0.05)
                                }
                                .id(number)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .border(.green)
                    .scrollClipDisabled(true)
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.never)
                    .overlay {
                        Rectangle()
                            .frame(height: 1)
                    }
                    .foregroundStyle(.green)
                }
                Spacer()
            }
            .frame(height: .infinity)
            .border(.red)
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ScrollViewTest()
}
