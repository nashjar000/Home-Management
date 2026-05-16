import SwiftUI

struct GroceriesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Groceries")
                .font(.title2)
                .bold()
            Text("This is a placeholder Groceries screen.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        GroceriesView()
    }
}
