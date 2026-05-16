//
//  GroceryViewModel.swift
//  Home Management
//
//  Created by Jared Nash on 1/22/26.
//
// Make sure Grcoeries can be added and synced

import Foundation
import Combine
import Supabase

final class GroceryViewModel: ObservableObject {
    @Published private(set) var items: [GroceryRow] = []
    @Published var lastError: String? = nil

    // MARK: - Loading
    @MainActor
    func setItems(_ newItems: [GroceryRow]) {
        self.items = newItems
    }

    func loadGroceries(householdId: UUID) async {
        print("[Groceries] loadGroceries householdId=\(householdId.uuidString)")
        do {
            let rows: [GroceryRow] = try await SupabaseManager.shared.client
                .from("groceries")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            print("[Groceries] loaded rows=\(rows.count)")
            // Merge server rows into existing items, keep optimistic items
            await MainActor.run {
                var currentById = Dictionary(uniqueKeysWithValues: self.items.map { ($0.id, $0) })
                // Update/insert server rows
                for row in rows {
                    currentById[row.id] = row
                }
                // Build combined and sort by created_at desc
                let combined = Array(currentById.values).sorted { a, b in
                    let ad = a.created_at ?? .distantPast
                    let bd = b.created_at ?? .distantPast
                    return ad > bd
                }
                self.items = combined
            }
        } catch {
            print("Failed to load groceries:", error)
        }
    }

    // MARK: - Add
    func addItem(_ name: String, householdId: UUID) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        print("[Groceries] addItem householdId=\(householdId.uuidString) name=\(trimmed)")
        guard let currentUserId = SupabaseManager.shared.client.auth.currentUser?.id else {
            print("[Groceries] addItem aborted: no signed-in user")
            return
        }

        // Create an optimistic local item
        let tempId = UUID()
        let temp = GroceryRow(
            id: tempId,
            household_id: householdId,
            name: trimmed,
            is_purchased: false,
            created_at: Date(),
            created_by: currentUserId
        )
        await MainActor.run { self.items.insert(temp, at: 0) }

        struct InsertPayload: Encodable {
            let household_id: String
            let name: String
            let is_purchased: Bool
            let created_by: String?
        }
        let payload = InsertPayload(
            household_id: householdId.uuidString,
            name: trimmed,
            is_purchased: false,
            created_by: currentUserId.uuidString
        )

        do {
            let serverRow: GroceryRow = try await SupabaseManager.shared.client
                .from("groceries")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value

            print("[Groceries] inserted id=\(serverRow.id) is_purchased=\(serverRow.is_purchased)")

            // Replace the optimistic item with the server row
            await MainActor.run {
                if let idx = self.items.firstIndex(where: { $0.id == tempId }) {
                    self.items[idx] = serverRow
                } else {
                    self.items.insert(serverRow, at: 0)
                }
            }

            // Refresh to ensure we have the latest state (helps cross-device sync)
            await loadGroceries(householdId: householdId)
        } catch {
            // Roll back optimistic item on failure
            await MainActor.run { self.items.removeAll { $0.id == tempId } }
            print("[Groceries] insert error=", error)
        }
    }

    // MARK: - Toggle Purchased
    func toggle(_ item: GroceryRow, householdId: UUID) async {
        do {
            _ = try await SupabaseManager.shared.client
                .from("groceries")
                .update(["is_purchased": !item.is_purchased])
                .eq("id", value: item.id.uuidString)
                .execute()
            await loadGroceries(householdId: householdId)
        } catch {
            print("Failed to toggle grocery:", error)
        }
    }

    // MARK: - Delete
    @MainActor
    func delete(_ item: GroceryRow, householdId: UUID) async {
        lastError = nil
        do {
            try await SupabaseManager.shared.client
                .from("groceries")
                .delete()
                .eq("id", value: item.id.uuidString)
                .eq("household_id", value: householdId.uuidString)
                .execute()

            items.removeAll { $0.id == item.id }
            print("[Groceries] delete success id=\(item.id)")

            // Refresh to sync with server state
            await loadGroceries(householdId: householdId)
        } catch {
            lastError = "Delete failed: \(error.localizedDescription)"
            print("[Groceries] delete error=", error)
        }
    }
}
