// Was trying to have it track who added a grocery item, but, ran out of time...future update

import Foundation

struct GroceryRow: Codable, Identifiable, Equatable {
    let id: UUID
    let household_id: UUID
    let name: String // user's name
    let is_purchased: Bool // yes or no
    let created_at: Date? // might not need this, actually?
    let created_by: UUID? // user who added the item

    // Some schemas name this column `is_purchased`, others `is_completed`.
    // Decode either one so the app doesn’t break if the DB uses the other name.
    enum CodingKeys: String, CodingKey {
        case id
        case household_id
        case name
        case is_purchased
        case is_done
        case created_at
        case created_by
    }

    init(id: UUID, household_id: UUID, name: String, is_purchased: Bool, created_at: Date?, created_by: UUID?) {
        self.id = id
        self.household_id = household_id
        self.name = name
        self.is_purchased = is_purchased
        self.created_at = created_at
        self.created_by = created_by
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        household_id = try container.decode(UUID.self, forKey: .household_id)
        name = try container.decode(String.self, forKey: .name)

        // Prefer `is_purchased` if present; fall back to `is_completed`.
        if let purchased = try container.decodeIfPresent(Bool.self, forKey: .is_purchased) {
            is_purchased = purchased
        } else if let completed = try container.decodeIfPresent(Bool.self, forKey: .is_done) {
            is_purchased = completed
        } else {
            is_purchased = false
        }

        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at)
        created_by = try container.decodeIfPresent(UUID.self, forKey: .created_by)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(household_id, forKey: .household_id)
        try container.encode(name, forKey: .name)
        // Encode using `is_purchased` (the app’s canonical name).
        try container.encode(is_purchased, forKey: .is_purchased)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(created_by, forKey: .created_by)
    }
}
