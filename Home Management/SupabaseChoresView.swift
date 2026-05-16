import SwiftUI

public struct SupabaseChoresView: View {
    @State private var items: [String] = ["Take out trash", "Dishes"]

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                ForEach(items, id: \.self) { item in
                    Text(item)
                }
                .onDelete { indexSet in
                    items.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("Chores")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { items.append("New Chore") }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    SupabaseChoresView()
}
