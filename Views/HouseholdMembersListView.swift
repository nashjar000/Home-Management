import SwiftUI
import Supabase

struct HouseholdMembersListView: View {
    @EnvironmentObject var appState: AppState
    @State private var members: [Member] = []
    @State private var isLoading = false

    struct Member: Identifiable, Equatable {
        let id: UUID
        let email: String?
        let role: String
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading members…")
            } else if members.isEmpty {
                Text("No members found").foregroundStyle(.secondary)
            } else {
                ForEach(members) { m in
                    HStack {
                        if let email = m.email, !email.isEmpty {
                            Text(email)
                        } else {
                            Text(shortId(m.id))
                        }
                        Spacer()
                        Text(m.role.capitalized).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task { await loadMembersAndProfiles() }
    }

    private func loadMembersAndProfiles() async {
        guard let hid = appState.household?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // Step 1: Fetch household_members for the household id
            struct HM: Decodable { let household_id: UUID; let user_id: UUID; let member_role: String }
            let householdMembers: [HM] = try await SupabaseManager.shared.client
                .from("household_members")
                .select()
                .eq("household_id", value: hid.uuidString)
                .execute()
                .value
            
            let userIds = householdMembers.map { $0.user_id.uuidString }
            
            guard !userIds.isEmpty else {
                await MainActor.run { self.members = [] }
                return
            }
            
            // Step 2: Fetch profiles for user_ids
            struct Profile: Decodable {
                let id: UUID
                let email: String?
            }
            
            // Supabase filter for multiple ids
            // .in() requires the column name and array of values
            let profiles: [Profile] = try await SupabaseManager.shared.client
                .from("profiles")
                .select(columns: "id,email")
                .in(column: "id", list: userIds)
                .execute()
                .value
            
            // Map user_id to email for quick lookup
            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.email) })
            
            // Construct members with email if available, otherwise nil
            let combined = householdMembers.map { hm in
                Member(id: hm.user_id, email: profileMap[hm.user_id] ?? nil, role: hm.member_role)
            }
            
            await MainActor.run {
                self.members = combined
            }
        } catch {
            print("Failed to load members or profiles:", error)
            await MainActor.run { self.members = [] }
        }
    }

    private func shortId(_ id: UUID) -> String {
        let s = id.uuidString
        return String(s.prefix(8))
    }
}

#Preview {
    HouseholdMembersListView().environmentObject(AppState())
}
