//
//  SettingsView.swift
//  Home Management
//
//  Created by Jared Nash on 1/27/26.
//
import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    // Display name editing
    @State private var displayName: String = ""
    @State private var profileStatus: String? = nil
    @State private var isSavingName: Bool = false

    // Member count
    @State private var membersCount: Int? = nil
    @State private var isLoadingMembersCount: Bool = false

    // Join household (children)
    @State private var inviteCodeInput: String = ""
    @State private var joinStatus: String? = nil
    @State private var isJoiningHousehold: Bool = false

    // Delete account
    @State private var showDeleteConfirm = false
    @State private var deleteError: String? = nil

    private var userEmail: String { appState.session?.user.email ?? "Unknown" }
    private var householdId: UUID? { appState.household?.id }
    private var householdName: String { appState.household?.name ?? "Household" }

    private var isParent: Bool { appState.profile?.role == .parent }
    private var roleText: String {
        if let role = appState.profile?.role {
            switch role { case .parent: return "Parent"; case .child: return "Child" }
        }
        return "Unknown"
    }

    var body: some View {
        NavigationStack {
            List {
                // Section 1: Account
                Section("Account") {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Signed in as", systemImage: "envelope")
                        Spacer()
                        Text(userEmail)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    HStack {
                        Label("Role", systemImage: "person.crop.circle")
                        Spacer()
                        Text(roleText)
                            .foregroundStyle(.secondary)
                    }
                }

                // Section 2: Display Name
                Section("Display Name") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("Your name", text: $displayName)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.done)
                                .onSubmit { Task { await saveDisplayName() } }

                            Button {
                                Task { await saveDisplayName() }
                            } label: {
                                Label("Save Name", systemImage: isSavingName ? "hourglass" : "checkmark.circle")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isSavingName || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if let profileStatus {
                            Text(profileStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }
                }

                // Section 3: Household (summary only)
                if let _ = householdId {
                    Section("Household") {
                        NavigationLink {
                            HouseholdDetailView()
                                .environmentObject(appState)
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Label("\(householdName)", systemImage: "house")
                                Spacer()
                                Text(membersCountText)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if isParent, let code = appState.household?.invite_code {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Invite Code", systemImage: "key")
                                    Spacer()
                                    Text(code)
                                        .monospaced()
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }

                                HStack(spacing: 12) {
                                    Button {
                                        UIPasteboard.general.string = code
                                        joinStatus = "Copied ✅"
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            if joinStatus == "Copied ✅" { joinStatus = nil }
                                        }
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    .buttonStyle(.bordered)

                                    ShareLink(items: ["Join my household on Home Management. Invite code: \(code)"]) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        if let joinStatus {
                            Text(joinStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // No household yet
                    Section("Household") {
                        if isParent {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("You are not in a household yet.")
                                    .foregroundStyle(.secondary)

                                NavigationLink {
                                    HouseholdSetupView()
                                        .environmentObject(appState)
                                } label: {
                                    Label("Create Household", systemImage: "house.badge.plus")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Join Household", systemImage: "person.badge.plus")
                                        .font(.headline)
                                    Spacer()
                                }

                                HStack(spacing: 8) {
                                    TextField("House code", text: $inviteCodeInput)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled(true)
                                        .onChange(of: inviteCodeInput) { _, newValue in
                                            let upper = newValue.uppercased()
                                            if upper != newValue {
                                                inviteCodeInput = upper
                                            }
                                        }
                                        .padding(10)
                                        .background(.ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    

                                    Button {
                                        Task { await joinHousehold() }
                                    } label: {
                                        if isJoiningHousehold {
                                            ProgressView()
                                                .frame(minWidth: 60)
                                        } else {
                                            Text("Join")
                                                .frame(minWidth: 60)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isJoiningHousehold || inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }

                                if let joinStatus {
                                    Text(joinStatus)
                                        .font(.footnote)
                                        .foregroundStyle(joinStatus.lowercased().contains("fail") ? .red : .secondary)
                                }
                            }
                        }
                    }
                }

                // Section 4: Actions
                Section("Actions") {
                    Button {
                        Task { await appState.signOut() }
                    } label: { Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: { Label("Delete Account", systemImage: "trash") }
                }
            }
            .navigationTitle("Settings")
            .task { await loadDisplayNameFromProfile() }
            .task(id: householdId) { await loadMembersCount() }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { Task { await deleteAccount() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .alert("Delete Failed", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "Unknown error")
            }
        }
    }

    // MARK: - Derived UI
    private var membersCountText: String {
        if isLoadingMembersCount { return "Loading…" }
        if let c = membersCount { return "\(c) member\(c == 1 ? "" : "s")" }
        return "—"
    }

    // MARK: - Data Loading
    private func loadDisplayNameFromProfile() async {
        do {
            guard let userId = appState.session?.user.id else { return }
            struct Row: Decodable { let display_name: String? }
            let row: Row = try await SupabaseManager.shared.client
                .from("profiles")
                .select("display_name")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            await MainActor.run { self.displayName = row.display_name ?? "" }
        } catch {
            // Not fatal—just leave field empty
            print("[Settings] load display_name error:", error)
        }
    }

    private func loadMembersCount() async {
        guard let hid = householdId else {
            await MainActor.run { self.membersCount = nil; self.isLoadingMembersCount = false }
            return
        }
        await MainActor.run { self.isLoadingMembersCount = true }
        defer { Task { @MainActor in self.isLoadingMembersCount = false } }
        do {
            let count = try await HouseholdService.loadMembersCount(householdId: hid)
            await MainActor.run { self.membersCount = count }
        } catch {
            print("[Settings] loadMembersCount error:", error)
            await MainActor.run { self.membersCount = nil }
        }
    }

    // MARK: - Actions
    private func saveDisplayName() async {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let userId = appState.session?.user.id else { return }

        await MainActor.run { isSavingName = true; profileStatus = nil }
        defer { Task { @MainActor in isSavingName = false } }

        do {
            try await SupabaseManager.shared.client
                .from("profiles")
                .update(["display_name": trimmed])
                .eq("id", value: userId.uuidString)
                .execute()
            await MainActor.run { profileStatus = "Saved ✅" }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("[Settings] saveDisplayName error:", error)
            await MainActor.run { profileStatus = "Save failed: \(error.localizedDescription)" }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func joinHousehold() async {
        let cleaned = inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        await MainActor.run {
            isJoiningHousehold = true
            joinStatus = nil
        }
        defer { Task { @MainActor in isJoiningHousehold = false } }

        do {
            _ = try await HouseholdService.joinHousehold(inviteCode: cleaned)
            // Refresh the app state household
            let refreshed = try await HouseholdService.fetchMyHousehold()
            await MainActor.run {
                appState.household = refreshed
                joinStatus = "Joined ✅"
                inviteCodeInput = ""
            }
        } catch {
            await MainActor.run {
                joinStatus = "Join failed: \(error.localizedDescription)"
            }
        }
    }

    // Delete Account option:
    private func deleteAccount() async {
        await MainActor.run { deleteError = nil }
        do {
            try await SupabaseManager.shared.client
                .rpc("delete_self")
                .execute()
            await appState.signOut()
        } catch {
            print("[Account] delete error:", error)
            await MainActor.run { self.deleteError = error.localizedDescription }
        }
    }
}

#Preview {
    SettingsView().environmentObject(AppState())
}
