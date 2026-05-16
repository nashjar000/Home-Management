//
//  AuthService.swift
//  Home Management
//
//  Created by Jared Nash on 2/4/26.
//
import Foundation
import Supabase

struct AuthService {

    static func signUp(email: String, password: String) async throws -> Session {
        let client = SupabaseManager.shared.client
        let response = try await client.auth.signUp(email: email, password: password)
        guard let session = response.session else {
            throw NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No session returned"])
        }
        return session
    }

    static func signIn(email: String, password: String) async throws -> Session {
        let client = SupabaseManager.shared.client
        let session = try await client.auth.signIn(email: email, password: password)
        return session
    }

    /// Create/update profile row after auth
    static func upsertProfile(userId: UUID, role: UserRole) async throws -> ProfileRow {
        let client = SupabaseManager.shared.client

        // IMPORTANT: profiles table should use id = auth.users.id
        let payload = ["id": userId.uuidString, "role": role.rawValue]

        let result: [ProfileRow] = try await client
            .from("profiles")
            .upsert(payload) // upsert by primary key
            .select()
            .execute()
            .value

        guard let row = result.first else {
            throw NSError(domain: "AuthService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Profile upsert returned no rows"])
        }
        return row
    }

    static func fetchMyProfile() async throws -> ProfileRow {
        let client = SupabaseManager.shared.client
        let result: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .limit(1)
            .execute()
            .value

        guard let row = result.first else {
            throw NSError(domain: "AuthService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No profile found"])
        }
        return row
    }
}
