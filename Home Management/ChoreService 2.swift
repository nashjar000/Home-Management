import Foundation
import Supabase

struct ChoreRow: Codable, Identifiable {
    let id: UUID
    let household_id: UUID
    let title: String
    let due_date: Date?
    let is_complete: Bool
    let assigned_to: UUID?
    let created_at: Date?
}

struct ChoreService {
    // Load chores for a household, newest first
    static func loadChores(householdId: UUID) async throws -> [ChoreRow] {
        let client = SupabaseManager.shared.client
        let rows: [ChoreRow] = try await client
            .from("chores")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    // Add a new chore
    static func addChore(householdId: UUID, title: String, dueDate: Date?, assignedTo: UUID?) async throws {
        let client = SupabaseManager.shared.client
        struct Insert: Encodable {
            let id: String
            let household_id: String
            let title: String
            let due_date: Date?
            let is_complete: Bool
            let assigned_to: String?
        }
        let payload = Insert(
            id: UUID().uuidString,
            household_id: householdId.uuidString,
            title: title,
            due_date: dueDate,
            is_complete: false,
            assigned_to: assignedTo?.uuidString
        )
        _ = try await client
            .from("chores")
            .insert(payload)
            .execute()
    }

    // Set completion state
    static func setComplete(choreId: UUID, isComplete: Bool) async throws {
        let client = SupabaseManager.shared.client
        struct Update: Encodable { let is_complete: Bool }
        _ = try await client
            .from("chores")
            .update(Update(is_complete: isComplete))
            .eq("id", value: choreId.uuidString)
            .execute()
    }

    // Delete a chore
    static func deleteChore(choreId: UUID) async throws {
        let client = SupabaseManager.shared.client
        _ = try await client
            .from("chores")
            .delete()
            .eq("id", value: choreId.uuidString)
            .execute()
    }

    // Assign a chore (or unassign with nil)
    static func assignChore(choreId: UUID, assignedTo: UUID?) async throws {
        let client = SupabaseManager.shared.client
        struct Update: Encodable { let assigned_to: String? }
        _ = try await client
            .from("chores")
            .update(Update(assigned_to: assignedTo?.uuidString))
            .eq("id", value: choreId.uuidString)
            .execute()
    }
}
