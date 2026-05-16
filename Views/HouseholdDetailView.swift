import SwiftUI
import Supabase
import PostgREST

struct HouseholdDetailView: View {
    @EnvironmentObject var appState: AppState
    @State private var members: [HouseholdMember] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var isParent: Bool { appState.profile?.role == .parent }
    private var household: Household? { appState.household }

    var body: some View {
        List {
            if let household {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(household.name, systemImage: "house")
                            Spacer()
                            if let code = household.invite_code {
                                Button {
                                    UIPasteboard.general.string = code
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                ShareLink(items: ["Join my household on Home Management. Invite code: \(code)"]) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                        if let code = household.invite_code {
                            Text("Invite code: \(code)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Members") {
                if members.isEmpty && !isLoading {
                    Text("No members yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(members) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member.display_name ?? "Unknown")
                            Text(roleText(for: member))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .onDelete(perform: handleDelete)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Household")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    private func refresh() async {
        guard let id = household?.id else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { @MainActor in isLoading = false } }
        do {
            let loaded = try await HouseholdService.loadMembers(householdId: id)
            await MainActor.run { members = loaded }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func handleDelete(at offsets: IndexSet) {
        guard isParent, let selfId = appState.session?.user.id else { return }
        let toDelete = offsets.compactMap { members[$0] }
        Task {
            for member in toDelete {
                // Disallow removing self or other parents
                if member.user_id == selfId { continue }
                if roleText(for: member) == "Parent" { continue }
                do {
                    if let hid = household?.id {
                        try await HouseholdService.removeMember(householdId: hid, userId: member.user_id)
                    }
                } catch {
                    await MainActor.run { errorMessage = error.localizedDescription }
                }
            }
            await refresh()
        }
    }

    private func roleText(for member: HouseholdMember) -> String {
        switch member.member_role.lowercased() {
        case "parent": return "Parent"
        case "child": return "Child"
        default: return member.member_role
        }
    }
}

#Preview {
    HouseholdDetailView()
        .environmentObject(AppState())
}
