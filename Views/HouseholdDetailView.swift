// Main part for the Household details (member roles, house name, removing and adding to household)

import SwiftUI
import Supabase

struct HouseholdDetailView: View {
    @EnvironmentObject var appState: AppState

    @State private var members: [HouseholdService.HouseholdMember] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var confirmRemove: HouseholdService.HouseholdMember? = nil
    @State private var confirmLeave: Bool = false

    // Rename household (parent only)
    @State private var newHouseholdName: String = ""
    @State private var renameStatus: String? = nil
    @State private var isSavingHouseholdName: Bool = false

    private var isParent: Bool { appState.profile?.role == .parent }
    private var householdId: UUID? { appState.household?.id }
    private var currentUserId: UUID? { appState.session?.user.id }

    var body: some View {
        List {
            if isParent {
                Section("Household Name") {
                    TextField("Household name", text: $newHouseholdName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { Task { await saveHouseholdName() } }

                    Button {
                        Task { await saveHouseholdName() }
                    } label: {
                        Label(isSavingHouseholdName ? "Saving…" : "Save Name", systemImage: isSavingHouseholdName ? "hourglass" : "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSavingHouseholdName || newHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newHouseholdName == (appState.household?.name ?? ""))

                    if let renameStatus {
                        Text(renameStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    confirmLeave = true
                } label: {
                    Label("Leave Household", systemImage: "person.fill.xmark")
                }
            }

            Section("Members") {
                if isLoading {
                    ProgressView("Loading members…")
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
                if isParent {
                    ForEach(members) { member in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(memberColor(for: Optional(member.user_id), among: members.map(\.user_id).sorted { $0.uuidString < $1.uuidString }))
                                        .frame(width: 10, height: 10)
                                    Text(displayName(for: member))
                                }
                                Text(roleText(for: member))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isParent && member.user_id != currentUserId && roleText(for: member) == "Child" {
                                Button(role: .destructive) {
                                    confirmRemove = member
                                } label: {
                                    Text("Remove")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .onDelete { offsets in
                        handleDelete(at: offsets)
                    }
                } else {
                    ForEach(members) { member in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(memberColor(for: Optional(member.user_id), among: members.map(\.user_id).sorted { $0.uuidString < $1.uuidString }))
                                        .frame(width: 10, height: 10)
                                    Text(displayName(for: member))
                                }
                                Text(roleText(for: member))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isParent && member.user_id != currentUserId && roleText(for: member) == "Child" {
                                Button(role: .destructive) {
                                    confirmRemove = member
                                } label: {
                                    Text("Remove")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(appState.household?.name ?? "Household")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    triggerLoad()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task { triggerLoad() }
        .task(id: householdId) {
            await MainActor.run {
                self.newHouseholdName = appState.household?.name ?? ""
                self.renameStatus = nil
            }
        }
        .onDisappear { cancelLoad() }
        .alert(item: $confirmRemove, content: { member in
            Alert(
                title: Text("Remove \(displayName(for: member))?"),
                message: Text("This will remove the member from the household."),
                primaryButton: .destructive(Text("Remove")) {
                    Task { await remove(member: member) }
                },
                secondaryButton: .cancel()
            )
        })
        .refreshable { triggerLoad() }
        .alert("Leave Household?", isPresented: $confirmLeave) {
            Button("Leave", role: .destructive) {
                Task { await leaveHousehold() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be removed from this household.")
        }
    }

    private func triggerLoad() {
        cancelLoad()
        loadTask = Task { await loadMembers() }
    }

    private func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func loadMembers() async {
        guard let hid = householdId else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { @MainActor in isLoading = false } }
        do {
            let rows = try await HouseholdService.loadMembers(householdId: hid, timeoutSeconds: 8)
            if Task.isCancelled { return }
            await MainActor.run { self.members = rows }
        } catch {
            if Task.isCancelled { return }
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func saveHouseholdName() async {
        guard isParent, let hid = householdId else { return }
        let trimmed = newHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await MainActor.run {
            isSavingHouseholdName = true
            renameStatus = nil
        }
        defer { Task { @MainActor in isSavingHouseholdName = false } }

        do {
            try await SupabaseManager.shared.client
                .from("households")
                .update(["name": trimmed])
                .eq("id", value: hid.uuidString)
                .execute()

            let refreshed = try await HouseholdService.fetchMyHousehold()
            await MainActor.run {
                appState.household = refreshed
                renameStatus = "Saved ✅"
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            await MainActor.run {
                renameStatus = "Save failed: \(error.localizedDescription)"
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func handleDelete(at offsets: IndexSet) {
        guard isParent else { return }
        let items = offsets.map { members[$0] }
        for m in items {
            if m.user_id == currentUserId || roleText(for: m) == "Parent" { continue }
            confirmRemove = m
        }
    }

    private func remove(member: HouseholdService.HouseholdMember) async {
        guard let hid = householdId else { return }
        do {
            try await HouseholdService.removeMember(householdId: hid, userId: member.user_id)
            print("[HouseholdDetail] remove success hid=\(hid) user=\(member.user_id)")
            triggerLoad()
        } catch {
            print("[HouseholdDetail] remove failed hid=\(String(describing: householdId)) user=\(member.user_id) error=\(error)")
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func leaveHousehold() async {
        guard let hid = householdId, let uid = currentUserId else { return }
        do {
            try await HouseholdService.removeMember(householdId: hid, userId: uid)
            await MainActor.run {
                appState.household = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func displayName(for member: HouseholdService.HouseholdMember) -> String {
        if let dn = member.display_name, !dn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return dn }
        return String(member.user_id.uuidString.prefix(8))
    }

    private func roleText(for member: HouseholdService.HouseholdMember) -> String {
        // Some rows may use different field names or casing
        let roleRaw = member.member_role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if roleRaw.contains("parent") {
            return "Parent"
        } else if roleRaw.contains("child") {
            return "Child"
        } else {
            return roleRaw.capitalized.isEmpty ? "Child" : roleRaw.capitalized
        }
    }
}

#Preview {
    HouseholdDetailView()
        .environmentObject(AppState())
}
