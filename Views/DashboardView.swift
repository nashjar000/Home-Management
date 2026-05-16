import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var groceryVM: GroceryViewModel

        private var itemsToBuyCount: Int {
            groceryVM.items.filter { !$0.isPurchased }.count
        }
    
    // Main Dashboard:
    var body: some View {
        VStack(spacing: 16) {
            // House icon
            Image(systemName: "house.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            // Dashboard text
            Text("Dashboard")
                .font(.title2)
                .bold()
            // Welcome message
            Text("Welcome to Home Management")
                .foregroundStyle(.secondary)
            // Items to buy
            Text("\(itemsToBuyCount) item(s) to buy")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    DashboardView()
        .environmentObject(GroceryViewModel())
}
