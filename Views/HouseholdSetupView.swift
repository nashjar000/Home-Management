// Main logic for setting up the household:

import SwiftUI
import UIKit

struct HouseholdSetupView: View {
    @EnvironmentObject var appState: AppState

    @State private var householdName = "My Household"
    @State private var inviteCodeInput = ""
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var showShare = false
    @State private var copyStatus: String?

    var body: some View {
        Form {
            Section {
                Text("Your role: \(roleText)")
                    .foregroundStyle(.secondary)
            }

            if isParent {
                if appState.household == nil {
                    parentSection
                } else {
                    currentHouseholdSection
                }
            } else if isChild {
                childSection
                
            // Just in case something weird happens:
            } else {
                Section {
                    Text("We couldn't determine your role. Please sign out and sign back in.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Household")
        .disabled(isWorking)
        .sheet(isPresented: $showShare) {
            if let code = appState.household?.invite_code {
                ShareSheet(activityItems: ["Join my household on Home Management. Invite code: \(code)"])
            }
        }
    }

    private var isParent: Bool { appState.profile?.role == .parent }
    private var isChild: Bool { appState.profile?.role == .child }
    private var roleText: String { isParent ? "Parent" : (isChild ? "Child" : "Unknown") }

    private var parentSection: some View {
        Section("Create Household") {
            TextField("Household name", text: $householdName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            Button {
                Task { await createHousehold() }
            } label: { Text(isWorking ? "Creating…" : "Create Household") }
            .disabled(isWorking || householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var currentHouseholdSection: some View {
        Section("Current Household") {
            if let household = appState.household {
                HStack {
                    Text(household.name)
                    Spacer()
                    Text(household.invite_code).monospaced().foregroundStyle(.secondary)
                }
                inviteActionsRow(inviteCode: household.invite_code)
                if let copyStatus {
                    Text(copyStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var childSection: some View {
        Section("Join Household") {
            TextField("Invite code", text: $inviteCodeInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: inviteCodeInput) { _, newValue in
                    let upper = newValue.uppercased()
                    if upper != newValue {
                        inviteCodeInput = upper
                    }
                }
            Button {
                Task { await joinHousehold() }
            } label: { Text(isWorking ? "Joining…" : "Join Household") }
            .disabled(isWorking || inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private func inviteActionsRow(inviteCode: String) -> some View {
        HStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = inviteCode
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                copyStatus = "Invite code copied"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copyStatus == "Invite code copied" {
                        copyStatus = nil
                    }
                }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Button {
                copyStatus = nil
                showShare = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()
        }
    }

    private func createHousehold() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let household = try await HouseholdService.createHousehold(name: householdName)
            await MainActor.run { appState.household = household }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func joinHousehold() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let code = inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let household = try await HouseholdService.joinHousehold(inviteCode: code)
            await MainActor.run { appState.household = household }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    HouseholdSetupView().environmentObject(AppState())
}
