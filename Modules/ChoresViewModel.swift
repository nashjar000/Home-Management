import Foundation
import SwiftUI
import Combine

// MARK: - Chore model used by the Chores module
struct Chore: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var dueDate: Date?
    var isComplete: Bool
    var assignedTo: UUID?

    init(id: UUID = UUID(), title: String, dueDate: Date? = nil, isComplete: Bool = false, assignedTo: UUID? = nil) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isComplete = isComplete
        self.assignedTo = assignedTo
    }
}

// MARK: - View Model
@MainActor
final class ChoresViewModel: ObservableObject {
    @Published var chores: [Chore] = []
    @Published var newTitle: String = ""
    @Published var newDueDate: Date? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var members: [HouseholdService.HouseholdMember] = []
    @Published var selectedAssigneeId: UUID? = nil

    private weak var appState: AppState?

    var isParentUser: Bool {
        appState?.profile?.role == .parent
    }

    init(appState: AppState? = nil) {
        self.appState = appState
    }

    func configure(appState: AppState) {
        self.appState = appState
    }

    private func mapRow(_ row: ChoreRow) -> Chore {
        Chore(
            id: row.id,
            title: row.title,
            dueDate: row.dueDate,
            isComplete: row.isDone,
            assignedTo: row.assignedTo
        )
    }

    // Load chores and members from the service
    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let hid = appState?.household?.id else {
            self.members = []
            self.chores = []
            self.errorMessage = "Join a household first"
            return
        }
        do {
            let loadedMembers = try await HouseholdService.loadMembers(householdId: hid)
            self.members = loadedMembers

            let rows = try await ChoreServiceV2.loadChores(householdId: hid)
            self.chores = rows.map(mapRow)

            // DEBUG: Verify mapping of is_done -> isComplete
            let doneCount = rows.filter { $0.isDone }.count
            let uiDoneCount = self.chores.filter { $0.isComplete }.count
            print("[ChoresVM] rows=\(rows.count) isDone(rows)=\(doneCount) isComplete(UI)=\(uiDoneCount)")
            self.chores.prefix(10).forEach { c in
                let dueStr = c.dueDate.map { String(describing: $0) } ?? "nil"
                print("[ChoresVM] mapped -> title=\(c.title) dueDate=\(dueStr) isComplete=\(c.isComplete)")
            }

            self.errorMessage = nil
        } catch {
            print("[Chores] load error:", error)
            self.errorMessage = "Failed to load chores or members: \(error.localizedDescription)"
        }
    }

    func assign(choreId: UUID, assignedTo: UUID?) async {
        guard isParentUser else { return }
        do {
            try await ChoreServiceV2.assignChore(choreId: choreId, assignedTo: assignedTo)
            await load()
        } catch {
            errorMessage = "Failed to assign chore: \(error.localizedDescription)"
        }
    }
    
    // Set a due date for a chore to be done by
    func setDueDate(choreId: UUID, dueDate: Date?) async {
        do {
            try await ChoreServiceV2.setDueDate(choreId: choreId, dueDate: dueDate)
            await load()
        } catch {
            errorMessage = "Failed to update due date: \(error.localizedDescription)"
        }
    }

    // Add a chore IF APART OF A HOUSEHOLD
    func add() async {
        // Clear previous errors
        errorMessage = nil

        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let hid = appState?.household?.id else {
            errorMessage = "Join a household first"
            return
        }

        // Only parents can assign chores
        let assigneeToSend: UUID? = isParentUser ? selectedAssigneeId : nil

        isLoading = true
        defer { isLoading = false }

        do {
            // Default to today if the user didn't change the picker (prevents NULL due_date and keeps Today/Overdue logic consistent)
            try await ChoreServiceV2.addChore(
                householdId: hid,
                title: trimmed,
                dueDate: (newDueDate ?? Date()),
                assignedTo: assigneeToSend
            )

            // Reset form
            newTitle = ""
            newDueDate = nil
            selectedAssigneeId = nil

            // Reload so the new chore appears and syncs across accounts
            await load()
        } catch {
            print("[Chores] add error:", error)
            errorMessage = "Failed to add chore: \(error.localizedDescription)"
        }
    }

    // Syncing
    func toggle(_ chore: Chore) async {
        do {
            try await ChoreServiceV2.setComplete(choreId: chore.id, isComplete: !chore.isComplete)
            await load()
        } catch {
            errorMessage = "Failed to update chore status: \(error.localizedDescription)"
        }
    }

    // Delete a chore
    func delete(at offsets: IndexSet) async {
        guard !offsets.isEmpty else { return }
        do {
            let idsToDelete = offsets.compactMap { index in
                chores.indices.contains(index) ? chores[index].id : nil
            }
            for id in idsToDelete {
                try await ChoreServiceV2.deleteChore(choreId: id)
            }
            await load()
        } catch {
            errorMessage = "Failed to delete chore(s): \(error.localizedDescription)"
        }
    }
    
    func delete(_ chore: Chore) async {
        do {
            try await ChoreServiceV2.deleteChore(choreId: chore.id)
            await load()
        } catch {
            errorMessage = "Failed to delete chore: \(error.localizedDescription)"
        }
    }
}
