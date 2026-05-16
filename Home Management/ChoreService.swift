import Foundation
import Supabase

struct Chore: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var dueDate: Date?
    var isComplete: Bool
    var assignedTo: UUID?
    var householdId: UUID
    var createdAt: Date?
    var updatedAt: Date?
}

class ChoreService {
    static let shared = ChoreService()
    private let client = SupabaseManager.shared.client
    private let tableName = "chores"

    private init() {}

    func fetchChores(for householdId: UUID) async throws -> [Chore] {
        let response = try await client
            .from(tableName)
            .select()
            .eq(column: "household_id", value: householdId.uuidString)
            .order(column: "due_date", ascending: true)
            .execute()
        guard let data = response.data else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try data.decoded(to: [Chore].self, decoder: decoder)
    }

    func addChore(_ chore: Chore) async throws -> Chore? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(chore)
        let json = try JSONSerialization.jsonObject(with: data)
        let response = try await client
            .from(tableName)
            .insert(values: json)
            .execute()
        guard let insertedData = response.data else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try insertedData.decoded(to: Chore.self, decoder: decoder)
    }

    func updateChore(_ chore: Chore) async throws -> Chore? {
        guard let id = chore.id.uuidString as String? else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(chore)
        let json = try JSONSerialization.jsonObject(with: data)
        let response = try await client
            .from(tableName)
            .update(values: json)
            .eq(column: "id", value: id)
            .execute()
        guard let updatedData = response.data else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try updatedData.decoded(to: Chore.self, decoder: decoder)
    }

    func deleteChore(id: UUID) async throws {
        try await client
            .from(tableName)
            .delete()
            .eq(column: "id", value: id.uuidString)
            .execute()
    }
}

import SwiftUI

struct ChoreRow: View {
    let chore: Chore

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(chore.title)
                    .font(.headline)
                if let dueDate = chore.dueDate {
                    Text("Due: \(dueDate, formatter: dateFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            if chore.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}
