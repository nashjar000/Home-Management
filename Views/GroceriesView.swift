import SwiftUI

struct GroceriesView: View {
    @EnvironmentObject var groceryVM: GroceryViewModel
    @State private var newItemName = ""

    // Keep track if somehting needs to be bought still or not
    private var toBuy: [GroceryItem] {
        groceryVM.items.filter { !$0.isPurchased }
    }

    // Keep track of items that have been bought
    private var purchased: [GroceryItem] {
        groceryVM.items.filter { $0.isPurchased }
    }

    var body: some View {
        // Add items to a list:
        List {
            Section {
                HStack {
                    TextField("Add grocery item", text: $newItemName)
                        .textInputAutocapitalization(.words)

                    Button("Add") {
                        groceryVM.addItem(newItemName)
                        newItemName = ""
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            // Need to buy:
            Section("Need to Buy (\(toBuy.count))") {
                ForEach(toBuy) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Image(systemName: "circle")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { groceryVM.toggle(item) }
                }
            }

            // Purchased section:
            Section("Purchased") {
                ForEach(purchased) { item in
                    HStack {
                        Text(item.name).strikethrough()
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { groceryVM.toggle(item) }
                }
            }
        }
        .navigationTitle("Groceries")
    }
}

#Preview {
    NavigationStack {
        GroceriesView()
    }
    .environmentObject(GroceryViewModel())
}
