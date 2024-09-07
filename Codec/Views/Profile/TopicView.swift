import SwiftUI

struct TopicView: View {
    @EnvironmentObject private var userVM: UserViewModel
    @EnvironmentObject private var categoryVM: CategoryViewModel
    @Environment(\.dismiss) private var dismiss
    @GestureState private var dragOffset: CGFloat = 0
    
    // Minimum number of categories required
    private let minimumCategories = 5
    
    var groupedCategories: [String: [Category]] {
        Dictionary(grouping: categoryVM.allCategories) { category in
            category.name ?? "Other"
        }
    }
    
    var sortedParentCategories: [(String, Int)] {
        groupedCategories.map { parentName, categories in
            let totalClipCount = categories.reduce(0) { $0 + ($1.clipCount ?? 0) }
            return (parentName, totalClipCount)
        }.sorted { $0.1 > $1.1 }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(sortedParentCategories, id: \.0) { parentName, _ in
                        Section(header: Text(parentName)) {
                            ForEach(groupedCategories[parentName]?.sorted(by: { ($0.clipCount ?? 0) > ($1.clipCount ?? 0) }) ?? [], id: \.id) { category in
                                CategoryRow(category: category)
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if categoryVM.userCategories.count < minimumCategories {
                        VStack {
                            Text("Please select at least \(minimumCategories) topics")
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding()
                        }
                    }
                }
                if userVM.isOnboarding {
                    NavigationLink(destination: FeedFollowBlockView(isInterested: true)) {
                        HStack {
                            Text("Continue")
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .opacity(categoryVM.userCategories.count >= minimumCategories ? 1.0 : 0.3)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(categoryVM.userCategories.count < minimumCategories)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Topics")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if !userVM.isOnboarding {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: attemptDismiss) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                        .disabled(!canDismiss)
                    }
                }
            }
        }
        .interactiveDismissDisabled(!canDismiss)
        .gesture(
            DragGesture().updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }.onEnded { value in
                if value.translation.width > 100 && canDismiss {
                    attemptDismiss()
                }
            }
        )
        .onAppear() {
            categoryVM.isUserSelecting = true
        }
    }
    
    private var canDismiss: Bool {
        categoryVM.userCategories.count >= minimumCategories
    }
    
    private func attemptDismiss() {
        if canDismiss {
            categoryVM.isUserSelecting = false
            dismiss()
        }
    }
}

struct CategoryRow: View {
    let category: Category
    @EnvironmentObject private var categoryVM: CategoryViewModel
    @State private var isLoading: Bool = false
    @State private var isSelected: Bool = false
    
    var body: some View {
        HStack {
            Text(category.name)
            Spacer()
            if isLoading {
                ProgressView()
            } else {
                if isSelected {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "square")
                        .foregroundColor(.gray)
                }
            }
        }
        .contentShape(Rectangle()) // Make entire row tappable
        .onTapGesture {
            isLoading = true
            Task {
                if isSelected {
                    await categoryVM.removeUserCategory(category: category)
                } else {
                    await categoryVM.addUserCategory(category: category)
                }
                isLoading = false
            }
        }
        .onChange(of: categoryVM.userCategories) {
            updateIsSelected()
        }
        .onAppear {
            updateIsSelected()
        }
    }
    
    private func updateIsSelected() {
        isSelected = categoryVM.userCategories.first(where: { $0.id == category.id }) != nil
    }
}

#Preview {
    NavigationStack {
        TopicView()
    }
    .previewWithEnvironment()
}
