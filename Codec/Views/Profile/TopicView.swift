import SwiftUI

struct TopicView: View {
    @EnvironmentObject private var feedModel: FeedModel
    
    var groupedCategories: [String: [Category]] {
        Dictionary(grouping: feedModel.categories) { category in
            category.userFriendlyParentName ?? "Other"
        }
    }
    
    var sortedParentCategories: [(String, Int)] {
        groupedCategories.map { parentName, categories in
            let totalClipCount = categories.reduce(0) { $0 + ($1.clipCount ?? 0) }
            return (parentName, totalClipCount)
        }.sorted { $0.1 > $1.1 } // Sort by total clip count in descending order
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sortedParentCategories, id: \.0) { parentName, _ in
                    Section(header: Text(parentName)) {
                        ForEach(groupedCategories[parentName]?.sorted(by: { ($0.clipCount ?? 0) > ($1.clipCount ?? 0) }) ?? [], id: \.id) { category in
                            Text(category.userFriendlyName ?? category.name)
                        }
                    }
                }
            }
            .navigationTitle("Topics")
        }
        .onAppear {
            Task {
                await feedModel.loadCategories()
            }
        }
    }
}

#Preview {
    return TopicView()
        .environmentObject(FeedModel(debug: true))
}
