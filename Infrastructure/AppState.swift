//
//  AppState.swift
//  Home Management
//
//  Created by Jared Nash on 2/4/26.
//
import Foundation
import Supabase
import Combine

@MainActor
// Refreshing sission checker:
final class AppState: ObservableObject {
    @Published var session: Session? {
        didSet { Task { await refreshHousehold() } }
    }
    @Published var profile: ProfileRow? {
        didSet { Task { await refreshHousehold() } }
    }
    @Published var household: HouseholdRow?

    var userId: UUID? { session?.user.id }

    func setSession(_ session: Session?) {
        self.session = session
    }

    func refreshHousehold() async {
        do {
            self.household = try await HouseholdService.fetchMyHousehold()
        } catch {
            // Non-fatal; keep previous household if fetch fails
            print("Fetch household error:", error)
        }
    }

    func signOut() async {
        do {
            try await SupabaseManager.shared.client.auth.signOut()
            session = nil
            profile = nil
            household = nil
        } catch {
            print("Sign out error:", error)
        }
    }
}
