import Foundation

struct GroceryRow: Codable, Identifiable, Equatable {
    let id: UUID
    let household_id: UUID
    let name: String
    let is_purchased: Bool
    let created_at: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case household_id
        case name
        case is_purchased
        case created_at
    }
}
