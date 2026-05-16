//
//  Modules.swift
//  Home Management
//
//  Created by Jared Nash on 2/4/26.
//
// Mostly for Supabase stuff...

import Foundation

enum UserRole: String, Codable, CaseIterable {
    case parent
    case child
}

struct ProfileRow: Codable {
    let id: UUID
    let role: UserRole
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case createdAt = "created_at"
    }
}

struct HouseholdRow: Codable {
    let id: UUID
    let name: String
    let created_by: UUID
    let invite_code: String
    let created_at: Date?
}

struct HouseholdMemberRow: Codable {
    let household_id: UUID
    let user_id: UUID
    let member_role: String
}
