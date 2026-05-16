// Main view for the list of chores:
import SwiftUI
import UIKit

public struct ChoresListView: View {
    // Allow dashboard to request focusing the add field on appear
    private let focusAddField: Bool

    public init(focusAddField: Bool = false) {
        self.focusAddField = focusAddField
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ChoresViewModel

    // MARK: - UI State
    private enum Filter: String, CaseIterable, Identifiable {
        case upcoming = "All" // All chores view option
        case mine = "Mine" // User's view
        case completed = "Completed" // Completed chores
        var id: String { rawValue }
    }

    @State private var filter: Filter = .upcoming
    @State private var showAddedToast = false
    @State private var editingDueDateChore: Chore? = nil
    @State private var editingDueDate: Date = Date()
    @FocusState private var isNewChoreTitleFocused: Bool
    
    private var hasHousehold: Bool { appState.household?.id != nil }
    private var isChild: Bool { appState.profile?.role == .child }
    private var allowedFilters: [Filter] { isChild ? [.mine, .completed] : Filter.allCases }

    // MARK: - Bindings for optional fields stored in the view model
    private var assigneeSelection: Binding<UUID?> {
        Binding<UUID?>(
            get: { viewModel.selectedAssigneeId },
            set: { viewModel.selectedAssigneeId = $0 }
        )
    }

    private var dueDateSelection: Binding<Date> {
        Binding<Date>(
            get: { viewModel.newDueDate ?? Date() },
            set: { viewModel.newDueDate = $0 }
        )
    }

    // MARK: - Helpers
    private func assigneeLabel(for chore: Chore) -> String? {
        guard let assigneeId = chore.assignedTo else { return nil }
        if let m = viewModel.members.first(where: { $0.id == assigneeId }) {
            let name = m.display_name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if let name, !name.isEmpty { return name }
        }
        return String(assigneeId.uuidString.prefix(8))
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }

    private func isOverdue(_ date: Date) -> Bool {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfDate = Calendar.current.startOfDay(for: date)
        return startOfDate < startOfToday
    }

    
    private var todayChores: [Chore] {
        upcomingChores.filter { chore in
            guard let d = chore.dueDate else { return false }
            return isToday(d)
        }
    }


    private var upcomingChores: [Chore] {
        viewModel.chores
            .filter { !$0.isComplete }
            .sorted { (a, b) in
                switch (a.dueDate, b.dueDate) {
                case let (da?, db?): return da < db
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
            }
    }

    private var completedChores: [Chore] {
        viewModel.chores
            .filter { $0.isComplete }
            .sorted { (a, b) in
                switch (a.dueDate, b.dueDate) {
                case let (da?, db?): return da > db
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
            }
    }

    private var overdueChores: [Chore] {
        upcomingChores.filter { if let d = $0.dueDate { return isOverdue(d) } else { return false } }
    }


    // MARK: - "Mine" subsets (assigned to current user)
    private var myUpcomingChores: [Chore] {
        let uid = appState.userId
        if isChild {
            return upcomingChores.filter { $0.assignedTo == uid || $0.assignedTo == nil }
        } else {
            return upcomingChores.filter { $0.assignedTo == uid }
        }
    }

    private var myCompletedChores: [Chore] {
        let uid = appState.userId
        return completedChores.filter { $0.assignedTo == uid }
    }

    private var myOverdueChores: [Chore] {
        myUpcomingChores.filter { if let d = $0.dueDate { return isOverdue(d) } else { return false } }
    }

    private var summaryText: String {
        let overdue = (filter == .mine) ? myOverdueChores.count : overdueChores.count

        let upcomingList = (filter == .mine) ? myUpcomingChores : upcomingChores
        let upcomingOnly = upcomingList.filter { chore in
            guard let d = chore.dueDate else { return true }
            return !isToday(d) && !isOverdue(d)
        }.count

        if overdue == 0 && upcomingOnly == 0 { return "No upcoming chores" }

        var parts: [String] = []
        if overdue > 0 { parts.append("\(overdue) overdue") }
        if upcomingOnly > 0 { parts.append("\(upcomingOnly) upcoming") }

        return parts.joined(separator: " • ")
    }

    @ViewBuilder
    private func chip(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    private func relativeLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func beginEditingDueDate(for chore: Chore) {
        editingDueDateChore = chore
        editingDueDate = chore.dueDate ?? Date()
    }

    private func saveEditedDueDate() {
        guard let chore = editingDueDateChore else { return }
        let selected = Calendar.current.startOfDay(for: editingDueDate)
        Task {
            await viewModel.setDueDate(choreId: chore.id, dueDate: selected)
            await MainActor.run {
                editingDueDateChore = nil
            }
            Haptics.success()
        }
    }

    private func clearEditedDueDate() {
        guard let chore = editingDueDateChore else { return }
        Task {
            await viewModel.setDueDate(choreId: chore.id, dueDate: nil)
            await MainActor.run {
                editingDueDateChore = nil
            }
            Haptics.success()
        }
    }

    // MARK: - Sections
    @ViewBuilder
    private func addChoreSection() -> some View {
        if viewModel.isParentUser {
            Section("Add Chore") {
                if !hasHousehold {
                    Label("Join or create a household in Settings to add chores.", systemImage: "house")
                        .foregroundStyle(.secondary)
                }
                TextField("New chore title", text: $viewModel.newTitle)
                    .submitLabel(.done)
                    .focused($isNewChoreTitleFocused)

                if viewModel.isParentUser {
                    Picker("Assign to", selection: assigneeSelection) {
                        Text("Unassigned").tag(UUID?.none)
                        ForEach(viewModel.members, id: \.id) { member in
                            let name = member.display_name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            let label = (name?.isEmpty == false) ? name! : String(member.id.uuidString.prefix(8))
                            Text(label).tag(UUID?.some(member.id))
                        }
                    }
                }

                DatePicker("Due date", selection: dueDateSelection, displayedComponents: [.date])

                Button {
                    Task {
                        await viewModel.add()
                        if viewModel.errorMessage == nil {
                            Haptics.success()
                            withAnimation { showAddedToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation { showAddedToast = false }
                            }
                        }
                    }
                } label: {
                    Label("Add Chore", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasHousehold || viewModel.newTitle.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private func choresListSection() -> some View {
        let list: [Chore] = {
            switch filter {
            case .upcoming: return upcomingChores
            case .completed: return isChild ? myCompletedChores : completedChores
            case .mine: return myUpcomingChores
            }
        }()

        if filter == .upcoming {
            Section("Overdue") {
                if overdueChores.isEmpty {
                    Text("Nothing overdue")
                        .foregroundStyle(.secondary)
                } else {
                    choresRows(overdueChores)
                }
            }

            Section("Today") {
                if todayChores.isEmpty {
                    Text("Nothing due today")
                        .foregroundStyle(.secondary)
                } else {
                    choresRows(todayChores)
                }
            }

            Section("Upcoming") {
                let upcomingOnly = upcomingChores.filter { chore in
                    guard let d = chore.dueDate else { return true }
                    return !isToday(d) && !isOverdue(d)
                }

                if upcomingOnly.isEmpty {
                    Text("No upcoming chores")
                        .foregroundStyle(.secondary)
                } else {
                    choresRows(upcomingOnly)
                }
            }
        } else {
            Section("Chores") {
                choresRows(list)
            }
        }
    }

    @ViewBuilder
    private func choresRows(_ chores: [Chore]) -> some View {
        if chores.isEmpty {
            Text("No chores have been added yet")
                .foregroundStyle(.secondary)
        } else {
            ForEach(chores) { chore in
                if let assignedTo = chore.assignedTo {
                    let color = memberColor(for: assignedTo, among: viewModel.members.map(\.id).sorted { $0.uuidString < $1.uuidString })
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color.opacity(0.07))
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.85), lineWidth: 2)
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                Task {
                                    await viewModel.toggle(chore)
                                    Haptics.success()
                                }
                            } label: {
                                Image(systemName: chore.isComplete ? "checkmark.circle.fill" : "circle")
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(chore.title)
                                    .font(.headline)
                                    .strikethrough(chore.isComplete)
                                    .foregroundStyle(chore.isComplete ? .secondary : .primary)

                                HStack(alignment: .top, spacing: 8) {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            if let dueDate = chore.dueDate {
                                                let isLate = isOverdue(dueDate) && !chore.isComplete
                                                Button {
                                                    beginEditingDueDate(for: chore)
                                                } label: {
                                                    Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                                        .font(.caption)
                                                        .lineLimit(1)
                                                        .foregroundStyle(isLate ? .red : .secondary)
                                                        .padding(.vertical, 4)
                                                        .padding(.horizontal, 8)
                                                        .background(.ultraThinMaterial)
                                                        .clipShape(Capsule())
                                                        .fixedSize(horizontal: true, vertical: false)
                                                }
                                                .buttonStyle(.plain)

                                                if isToday(dueDate) {
                                                    chip(text: "Today", systemImage: "sun.max.fill")
                                                        .fixedSize(horizontal: true, vertical: false)
                                                } else if isLate {
                                                    chip(text: "Overdue", systemImage: "exclamationmark.triangle.fill")
                                                        .foregroundStyle(.red)
                                                        .fixedSize(horizontal: true, vertical: false)
                                                } else {
                                                    chip(text: relativeLabel(for: dueDate), systemImage: "clock")
                                                        .fixedSize(horizontal: true, vertical: false)
                                                }
                                            }

                                            if let name = assigneeLabel(for: chore) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "person.fill")
                                                    Text(name)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                }
                                                .font(.caption)
                                                .foregroundStyle(color)
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                                .background(color.opacity(0.12))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(color.opacity(0.45), lineWidth: 1)
                                                )
                                                .clipShape(Capsule())
                                                .fixedSize(horizontal: true, vertical: false)
                                            }
                                        }
                                        .padding(.vertical, 1)
                                    }

                                    if viewModel.isParentUser {
                                        Menu {
                                            Button("Unassigned") {
                                                Task {
                                                    await viewModel.assign(choreId: chore.id, assignedTo: nil)
                                                    Haptics.success()
                                                }
                                            }
                                            ForEach(viewModel.members, id: \.id) { member in
                                                let mName = member.display_name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                                                let label = (mName?.isEmpty == false) ? mName! : String(member.id.uuidString.prefix(8))
                                                Button(label) {
                                                    Task {
                                                        await viewModel.assign(choreId: chore.id, assignedTo: member.id)
                                                        Haptics.success()
                                                    }
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "person.crop.circle.badge.plus")
                                                .imageScale(.large)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.top, 2)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if viewModel.isParentUser {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.delete(chore)
                                        Haptics.success()
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task {
                                    await viewModel.toggle(chore)
                                    Haptics.success()
                                }
                            } label: {
                                Label(chore.isComplete ? "Undo" : "Complete", systemImage: chore.isComplete ? "arrow.uturn.left" : "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            Task {
                                await viewModel.toggle(chore)
                                Haptics.success()
                            }
                        } label: {
                            Image(systemName: chore.isComplete ? "checkmark.circle.fill" : "circle")
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(chore.title)
                                .font(.headline)
                                .strikethrough(chore.isComplete)
                                .foregroundStyle(chore.isComplete ? .secondary : .primary)

                            HStack(alignment: .top, spacing: 8) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        if let dueDate = chore.dueDate {
                                            let isLate = isOverdue(dueDate) && !chore.isComplete
                                            Button {
                                                beginEditingDueDate(for: chore)
                                            } label: {
                                                Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                    .foregroundStyle(isLate ? .red : .secondary)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .clipShape(Capsule())
                                                    .fixedSize(horizontal: true, vertical: false)
                                            }
                                            .buttonStyle(.plain)

                                            if isToday(dueDate) {
                                                chip(text: "Today", systemImage: "sun.max.fill")
                                                    .fixedSize(horizontal: true, vertical: false)
                                            } else if isLate {
                                                chip(text: "Overdue", systemImage: "exclamationmark.triangle.fill")
                                                    .foregroundStyle(.red)
                                                    .fixedSize(horizontal: true, vertical: false)
                                            } else {
                                                chip(text: relativeLabel(for: dueDate), systemImage: "clock")
                                                    .fixedSize(horizontal: true, vertical: false)
                                            }
                                        }

                                        if let name = assigneeLabel(for: chore) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "person.fill")
                                                Text(name)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Capsule())
                                            .fixedSize(horizontal: true, vertical: false)
                                        }
                                    }
                                    .padding(.vertical, 1)
                                }

                                if viewModel.isParentUser {
                                    Menu {
                                        Button("Unassigned") {
                                            Task {
                                                await viewModel.assign(choreId: chore.id, assignedTo: nil)
                                                Haptics.success()
                                            }
                                        }
                                        ForEach(viewModel.members, id: \.id) { member in
                                            let mName = member.display_name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                                            let label = (mName?.isEmpty == false) ? mName! : String(member.id.uuidString.prefix(8))
                                            Button(label) {
                                                Task {
                                                    await viewModel.assign(choreId: chore.id, assignedTo: member.id)
                                                    Haptics.success()
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .imageScale(.large)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 2)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if viewModel.isParentUser {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.delete(chore)
                                    Haptics.success()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task {
                                await viewModel.toggle(chore)
                                Haptics.success()
                            }
                        } label: {
                            Label(chore.isComplete ? "Undo" : "Complete", systemImage: chore.isComplete ? "arrow.uturn.left" : "checkmark")
                        }
                        .tint(.green)
                    }
                }
            }
            .onDelete { indexSet in
                if viewModel.isParentUser {
                    Task {
                        await viewModel.delete(at: indexSet)
                        Haptics.success()
                    }
                }
            }
        }
    }

    // MARK: - Body
    public var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(allowedFilters) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Label(summaryText, systemImage: "checklist")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task {
                            await viewModel.load()
                            Haptics.light()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Refresh")
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            addChoreSection()
            choresListSection()
        }
        .refreshable {
            await viewModel.load()
        }
        .task(id: appState.household?.id) {
            viewModel.configure(appState: appState)
            await viewModel.load()
        }
        .onAppear {
            if appState.profile?.role == .child && filter == .upcoming {
                filter = .mine
            }
            if focusAddField {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isNewChoreTitleFocused = true
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .overlay(alignment: .top) {
            if showAddedToast {
                Text("Added!")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Chores")
        .sheet(item: $editingDueDateChore) { chore in
            NavigationStack {
                Form {
                    Section("Edit Due Date") {
                        DatePicker("Due date", selection: $editingDueDate, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                    }
                }
                .navigationTitle(chore.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingDueDateChore = nil
                        }
                    }
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear") {
                            clearEditedDueDate()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveEditedDueDate()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChoresListView()
            .environmentObject(AppState())
    }
}

