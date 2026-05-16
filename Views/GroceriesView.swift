// Main UI for the groceries (adding & purchased items)

import SwiftUI

struct GroceriesView: View {
    @EnvironmentObject var groceryVM: GroceryViewModel
    @EnvironmentObject var appState: AppState

    @State private var newItemName = ""
    @State private var showAddedToast = false
    @FocusState private var isNewGroceryFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    private var toBuy: [GroceryRow] {
        groceryVM.items.filter { !$0.is_purchased }
    }

    private var purchased: [GroceryRow] {
        groceryVM.items.filter { $0.is_purchased }
    }

    private func reloadGroceriesIfPossible() {
        guard let householdId = appState.household?.id else { return }
        Task {
            await groceryVM.loadGroceries(householdId: householdId)
        }
    }
    
    var body: some View {
        if let householdId = appState.household?.id {
            List {
                Section {
                    HStack {
                        TextField("Add grocery item", text: $newItemName)
                            .textInputAutocapitalization(.words)
                            .focused($isNewGroceryFocused)

                        Button("Add") {
                            let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            Task {
                                await groceryVM.addItem(trimmed, householdId: householdId)
                                newItemName = ""
                                isNewGroceryFocused = false
                                withAnimation { showAddedToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation { showAddedToast = false }
                                }
                            }
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Need to Buy (\(toBuy.count))") {
                    ForEach(toBuy) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Image(systemName: "circle")
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            Task {
                                await groceryVM.toggle(item, householdId: householdId)
                            }
                        }
                    }
                    .onDelete { offsets in
                        Task {
                            for index in offsets {
                                await groceryVM.delete(toBuy[index], householdId: householdId)
                            }
                        }
                    }
                }

                if !purchased.isEmpty {
                    Section("Purchased") {
                        ForEach(purchased) { item in
                            HStack {
                                Text(item.name)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                Task {
                                    await groceryVM.toggle(item, householdId: householdId)
                                }
                            }
                        }
                        .onDelete { offsets in
                            Task {
                                for index in offsets {
                                    await groceryVM.delete(purchased[index], householdId: householdId)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Groceries")
            .navigationBarTitleDisplayMode(.large)
            .listStyle(.insetGrouped)
            .task(id: householdId) {
                await groceryVM.loadGroceries(householdId: householdId)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    reloadGroceriesIfPossible()
                }
            }
            .refreshable {
                await groceryVM.loadGroceries(householdId: householdId)
            }
        } else {
            Text("No household") // No Household message if no one is joined in a house yet...
        }
    }
}
