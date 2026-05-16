// Got assistance with AI on this. Not sure why I need this here, might add to the other chore service file instead

import Foundation
import Supabase

struct ChoreServiceV2 {
    // Shared date-only formatter for Postgres DATE (yyyy-MM-dd), interpreted in LOCAL time so UI buckets (Today/Overdue) match.
    private static let dateOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    // Load chores for a household, newest first
    static func loadChores(householdId: UUID) async throws -> [ChoreRow] {
        let client = SupabaseManager.shared.client

        let response = try await client
            .from("chores")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        func parseCreatedAt(_ raw: String?) -> Date? {
            guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let str = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            let isoWithFractional = ISO8601DateFormatter()
            isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = isoWithFractional.date(from: str) { return d }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: str) { return d }

            return nil
        }

        // Decode into a DTO so `ChoreRow` only needs to be Encodable elsewhere in the app.
        struct ChoreRowDTO: Decodable {
            let id: UUID
            let household_id: UUID
            let title: String
            let due_date: String?
            let is_done: Bool
            let assigned_to: UUID?
            let created_at: String?
        }
        let dtos = try JSONDecoder().decode([ChoreRowDTO].self, from: response.data)
        return dtos.map { dto in
            let parsedDate: Date? = {
                guard let s = dto.due_date, !s.isEmpty else { return nil }
                return ChoreServiceV2.dateOnlyFormatter.date(from: s)
            }()
            let parsedCreatedAt = parseCreatedAt(dto.created_at)
            return ChoreRow(
                id: dto.id,
                householdId: dto.household_id,
                title: dto.title,
                dueDate: parsedDate,
                isDone: dto.is_done,
                assignedTo: dto.assigned_to,
                createdAt: parsedCreatedAt
            )
        }
    }

    // Add a new chore
    static func addChore(householdId: UUID, title: String, dueDate: Date?, assignedTo: UUID?) async throws {
        let client = SupabaseManager.shared.client
        struct Insert: Encodable {
            let id: String
            let household_id: String
            let title: String
            let due_date: String?
            let is_done: Bool
            let assigned_to: String?
        }
        let dueString: String? = dueDate.map { ChoreServiceV2.dateOnlyFormatter.string(from: $0) }
        let payload = Insert(
            id: UUID().uuidString,
            household_id: householdId.uuidString,
            title: title,
            due_date: dueString,
            is_done: false,
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
        struct Update: Encodable { let is_done: Bool }
        _ = try await client
            .from("chores")
            .update(Update(is_done: isComplete))
            .eq("id", value: choreId.uuidString)
            .execute()
    }

    // Update or clear a chore's due date (nil clears the date)
    static func setDueDate(choreId: UUID, dueDate: Date?) async throws {
        let client = SupabaseManager.shared.client
        let payload: [String: AnyJSON]
        if let date = dueDate {
            let s = ChoreServiceV2.dateOnlyFormatter.string(from: date)
            payload = ["due_date": .string(s)]
        } else {
            payload = ["due_date": .null]
        }
        _ = try await client
            .from("chores")
            .update(payload)
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
