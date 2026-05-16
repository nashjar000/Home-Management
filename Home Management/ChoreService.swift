// Got some help from AI on this. This is to "talk" to the backend on Supabase
import Foundation
import Supabase

// DB row model for the "chores" table.
// Keep this separate from UI model "Chore" in ChoresViewModel.swift.
struct ChoreRow: Identifiable, Equatable {
    let id: UUID // user's id
    let householdId: UUID // household id
    let title: String // Chore title (what the chore is)
    let dueDate: Date? // Due date for the chore
    let isDone: Bool // yes or no
    let assignedTo: UUID? // Who the chore is assigned to
    let createdAt: Date? // created date (might not need?)
}

// DTO used only for decoding PostgREST JSON (Postgres `date` comes back as "yyyy-MM-dd" string).
private struct ChoreRowDTO: Decodable {
    let id: UUID
    let householdId: UUID
    let title: String
    let dueDate: String?
    let isDone: Bool
    let assignedTo: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case title
        case dueDate = "due_date"
        case isDone = "is_done"
        case assignedTo = "assigned_to"
        case createdAt = "created_at"
    }
}

final class ChoreService {
    private static func dateOnlyFormatter() -> DateFormatter {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        // Interpret date-only strings in the user's local time zone.
        // (For grouping into Today/Overdue, we care about local calendar days.)
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }

    private static func parseDateOnly(_ s: String) -> Date? {
        dateOnlyFormatter().date(from: s)
    }

    private static func formatDateOnly(_ date: Date) -> String {
        // Convert Date -> "yyyy-MM-dd" in LOCAL calendar terms (prevents timezone off-by-one)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func loadChores(householdId: UUID) async throws -> [ChoreRow] {
        let client = SupabaseManager.shared.client

        let dtos: [ChoreRowDTO] = try await client
            .from("chores")
            .select("id, household_id, title, due_date, is_done, assigned_to, created_at")
            .eq("household_id", value: householdId.uuidString)
            .order("due_date", ascending: true)
            .execute()
            .value

        return dtos.map { dto in
            ChoreRow(
                id: dto.id,
                householdId: dto.householdId,
                title: dto.title,
                dueDate: dto.dueDate.flatMap(parseDateOnly(_:)),
                isDone: dto.isDone,
                assignedTo: dto.assignedTo,
                createdAt: dto.createdAt
            )
        }
    }

    static func addChore(householdId: UUID, title: String, dueDate: Date?, assignedTo: UUID?) async throws {
        let client = SupabaseManager.shared.client
        guard client.auth.currentUser?.id != nil else {
            throw NSError(
                domain: "ChoreService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not signed in"]
            )
        }

        // Build an AnyJSON payload so PostgREST gets explicit column values
        let insert: [String: AnyJSON] = [
            "household_id": .string(householdId.uuidString),
            "title": .string(title),
            // If the caller accidentally passes nil, default to *today* so the UI
            // doesn't create chores with a NULL due_date (which breaks Today/Upcoming logic).
            // If you later want truly optional due dates, handle that at the call site.
            "due_date": .string(formatDateOnly(dueDate ?? Date())),
            "is_done": .bool(false),
            "assigned_to": assignedTo == nil ? .null : .string(assignedTo!.uuidString)
        ]

        // Insert
        _ = try await client
            .from("chores")
            .insert(insert)
            .execute()
    }

    static func assignChore(choreId: UUID, assignedTo: UUID?) async throws {
        let client = SupabaseManager.shared.client

        let update: [String: AnyJSON] = [
            "assigned_to": assignedTo == nil ? .null : .string(assignedTo!.uuidString)
        ]

        _ = try await client
            .from("chores")
            .update(update)
            .eq("id", value: choreId.uuidString)
            .execute()
    }

    static func setComplete(choreId: UUID, isComplete: Bool) async throws {
        let client = SupabaseManager.shared.client

        let update: [String: AnyJSON] = [
            "is_done": .bool(isComplete)
        ]

        _ = try await client
            .from("chores")
            .update(update)
            .eq("id", value: choreId.uuidString)
            .execute()
    }

    static func deleteChore(choreId: UUID) async throws {
        let client = SupabaseManager.shared.client

        _ = try await client
            .from("chores")
            .delete()
            .eq("id", value: choreId.uuidString)
            .execute()
    }
}
