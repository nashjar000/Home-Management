//
//  GroceriesView.swift
//  Home Management
//
//  Created by Jared Nash on 1/22/26.
//
import SwiftUI

struct GroceriesView: View {
    @EnvironmentObject var groceryVM: GroceryViewModel
    @State private var newItemName = ""

    var body: some View {
        // Grocery List
        List {
            Section {
                HStack {
                    // Add groceries
                    TextField("Add grocery item", text: $newItemName)

                    Button("Add") {
                        groceryVM.addItem(newItemName)
                        newItemName = ""
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            // Need to buy section:
            Section("Need to Buy") {
                ForEach(groceryVM.items.filter { !$0.isPurchased }) { item in
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
                ForEach(groceryVM.items.filter { $0.isPurchased }) { item in
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


