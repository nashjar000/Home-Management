import SwiftUI
import EventKit
import UIKit

struct DashboardView: View {
    @EnvironmentObject var choresVM: ChoresViewModel
    @EnvironmentObject var groceryVM: GroceryViewModel
    @EnvironmentObject var appState: AppState
    @StateObject private var eventStore = CalendarEventStore()
    @StateObject private var dashboardEventStore = CalendarEventStore()

    @State private var showAddEvent = false
    @State private var prefilledEventStart = Date()
    @State private var prefilledEventEnd = Date().addingTimeInterval(3600)
    @State private var copyToast: String? = nil
    @State private var inviteCodeInput: String = ""
    @State private var joinStatus: String? = nil
    @State private var isJoiningHousehold: Bool = false

    // Removed local ringColors and memberColor(for:) in favor of global memberColor(for:) from MemberColor.swift

    private var allDueTodayOrOverdue: [Chore] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        return choresVM.chores.filter { chore in
            guard let d = chore.dueDate else { return false }
            let start = cal.startOfDay(for: d)
            return start <= startOfToday
        }
    }

    private var dueTodayOrOverdue: [Chore] {
        guard let uid = appState.userId else { return allDueTodayOrOverdue }
        return allDueTodayOrOverdue.filter { $0.assignedTo == uid }
    }
    
    private var totalDue: Int { dueTodayOrOverdue.count }

    private var completedDue: Int {
        dueTodayOrOverdue.filter { $0.isComplete }.count
    }

    private var ringRatio: Double {
        // closed ring if none due
        guard totalDue > 0 else { return 1.0 }
        return Double(completedDue) / Double(totalDue)
    }

    private var dueTodayOrOverdueTotal: Int { dueTodayOrOverdue.count }

    private var dueTodayOrOverdueCompleted: Int {
        dueTodayOrOverdue.filter { $0.isComplete }.count
    }

    private var dueTodayOrOverdueRatio: Double {
        // Closed ring when nothing is due OR everything due is complete
        guard dueTodayOrOverdueTotal > 0 else { return 1.0 }
        return Double(dueTodayOrOverdueCompleted) / Double(dueTodayOrOverdueTotal)
    }
    
    private var isParent: Bool { appState.profile?.role == .parent }
    private var isChild: Bool { appState.profile?.role == .child }

    private var upcomingWindowEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }
    
    private func relativeLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
    
    private func assigneeLabel(for chore: Chore) -> String? {
        if let id = chore.assignedTo {
            if let m = choresVM.members.first(where: { $0.id == id }) {
                let name = m.display_name?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let name, !name.isEmpty { return name }
            }
            return String(id.uuidString.prefix(8))
        } else {
            return "Unassigned"
        }
    }

    private var upcomingChoresForDashboard: [Chore] {
        // Role-based: child sees their chores; parent sees household chores
        let base: [Chore]
        if isChild {
            base = choresVM.chores.filter { $0.assignedTo == appState.userId || $0.assignedTo == nil }
        } else {
            base = choresVM.chores
        }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let end = upcomingWindowEnd

        // Split into dated within 7 days and undated
        let dated = base.filter { chore in
            guard let d = chore.dueDate else { return false }
            let sd = Calendar.current.startOfDay(for: d)
            return sd >= startOfToday && sd <= end && !chore.isComplete
        }
        .sorted { (a, b) in
            switch (a.dueDate, b.dueDate) {
            case let (da?, db?): return da < db
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }

        let undated = base.filter { $0.dueDate == nil && !$0.isComplete }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        // Prioritize dated, then undated
        return Array((dated + undated).prefix(3))
    }
    
    // MARK: Member ring helpers and completion ratios
    private var currentMember: HouseholdService.HouseholdMember? {
        guard let uid = appState.userId else { return nil }
        return choresVM.members.first(where: { $0.id == uid })
    }

    private var memberRings: [HouseholdService.HouseholdMember] {
        if isChild {
            return []
        }
        guard let uid = appState.userId else { return choresVM.members }
        return choresVM.members.filter { member in
            member.id != uid
        }
    }

    private func choresAssigned(to member: HouseholdService.HouseholdMember) -> [Chore] {
        allDueTodayOrOverdue.filter { $0.assignedTo == member.id }
    }

    private var unassignedChores: [Chore] {
        allDueTodayOrOverdue.filter { $0.assignedTo == nil }
    }

    private var unassignedCompletionRatio: Double {
        guard !unassignedChores.isEmpty else { return 0.0 }
        let completed = unassignedChores.filter { $0.isComplete }.count
        return Double(completed) / Double(unassignedChores.count)
    }

    private func memberCompletionRatio(_ member: HouseholdService.HouseholdMember) -> Double {
        let assigned = choresAssigned(to: member)
        guard !assigned.isEmpty else { return 0.0 }
        let completed = assigned.filter { $0.isComplete }.count
        return Double(completed) / Double(assigned.count)
    }

    private var overallCompletionRatio: Double {
        ringRatio
    }

    private func showsRingOverlap(_ ratio: Double) -> Bool {
        ratio >= 0.999
    }
    
    private func joinHouseholdDashboard() async {
        let cleaned = inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        await MainActor.run {
            isJoiningHousehold = true
            joinStatus = nil
        }
        defer { Task { @MainActor in isJoiningHousehold = false } }

        do {
            _ = try await HouseholdService.joinHousehold(inviteCode: cleaned)
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

    private var currentRingColor: Color {
        if let currentMember {
            return memberColor(for: Optional(currentMember.id), among: choresVM.members.map(\.id).sorted { $0.uuidString < $1.uuidString })
        }
        return Color.accentColor
    }

    var body: some View {
        ScrollView {
            // MARK: Chore Progress Ring
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    // Title for the Chore Ring
                    Text("Chore Ring")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    // Rings Stack
                    ZStack {
                        // Subtle track for main household ring
                        Circle()
                            .stroke(lineWidth: 14)
                            .foregroundStyle(currentRingColor.opacity(0.12))

                        // Main household ring progress (primary focus)
                        Circle()
                            .trim(from: 0, to: overallCompletionRatio)
                            .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .foregroundStyle(currentRingColor)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: overallCompletionRatio)

                        if showsRingOverlap(overallCompletionRatio) {
                            Circle()
                                .trim(from: 0.0, to: 0.02)
                                .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                .foregroundStyle(currentRingColor)
                                .rotationEffect(.degrees(-90))
                        }

                        // Member rings (secondary, thinner and smaller with gaps)
                        ForEach(Array(memberRings.enumerated()), id: \.element.id) { index, member in
                            let strokeWidth: CGFloat = 6
                            // Base radius for inside rings starts smaller than main ring (132)
                            // Decrease radius per ring by 12 points for spacing
                            let baseRadius: CGFloat = 132
                            let insetPerRing: CGFloat = 12
                            let radius = baseRadius - (CGFloat(index + 1) * insetPerRing)

                            // Background track ring (faint full circle)
                            Circle()
                                .stroke(
                                    memberColor(for: Optional(member.id), among: choresVM.members.map(\.id).sorted { $0.uuidString < $1.uuidString }).opacity(0.12),
                                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                                )
                                .frame(width: radius, height: radius)
                                .rotationEffect(.degrees(-90))

                            // Foreground progress arc, minimum trim 0.02 for visible stub
                            let progress = max(memberCompletionRatio(member), 0.02)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    memberColor(for: Optional(member.id), among: choresVM.members.map(\.id).sorted { $0.uuidString < $1.uuidString }),
                                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                                )
                                .frame(width: radius, height: radius)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: memberCompletionRatio(member))

                            if showsRingOverlap(memberCompletionRatio(member)) {
                                Circle()
                                    .trim(from: 0.0, to: 0.02)
                                    .stroke(
                                        memberColor(for: Optional(member.id), among: choresVM.members.map(\.id).sorted { $0.uuidString < $1.uuidString }),
                                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                                    )
                                    .frame(width: radius, height: radius)
                                    .rotationEffect(.degrees(-90))
                            }
                        }

                        if isParent, !unassignedChores.isEmpty {
                            let strokeWidth: CGFloat = 6
                            let baseRadius: CGFloat = 132
                            let insetPerRing: CGFloat = 12
                            let radius = baseRadius - (CGFloat(memberRings.count + 1) * insetPerRing)
                            let unassignedColor = Color.gray

                            Circle()
                                .stroke(
                                    unassignedColor.opacity(0.12),
                                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                                )
                                .frame(width: radius, height: radius)
                                .rotationEffect(.degrees(-90))

                            let progress = max(unassignedCompletionRatio, 0.02)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    unassignedColor,
                                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                                )
                                .frame(width: radius, height: radius)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: unassignedCompletionRatio)

                            if showsRingOverlap(unassignedCompletionRatio) {
                                Circle()
                                    .trim(from: 0.0, to: 0.02)
                                    .stroke(
                                        unassignedColor,
                                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                                    )
                                    .frame(width: radius, height: radius)
                                    .rotationEffect(.degrees(-90))
                            }
                        }

                        // Center text - unified logic for both parents and children
                        VStack(spacing: 2) {
                            if dueTodayOrOverdueTotal == 0 {
                                Text("All set")
                                    .font(.title3).bold()
                                Text("My chores")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                let incomplete = max(totalDue - completedDue, 0)
                                Text("\(completedDue)/\(totalDue)")
                                    .font(.title2).bold()
                                Text("\(incomplete) left")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 132, height: 132)
                    .padding(.vertical, 0)

                    // Legend directly under the ring, visually connected
                    if let currentMember {
                        let currentName = currentMember.display_name?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let currentDisplay = (currentName?.isEmpty == false ? currentName! : String(currentMember.id.uuidString.prefix(8)))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(currentRingColor)
                                .frame(width: 7, height: 7)
                            let ratioText = dueTodayOrOverdue.isEmpty ? "—" : "\(dueTodayOrOverdue.filter { $0.isComplete }.count)/\(dueTodayOrOverdue.count)"
                            Text("\(isChild ? "My chores" : currentDisplay) \(ratioText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 1)
                        .padding(.horizontal, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.secondary.opacity(0.06))
                        )
                        .padding(.bottom, memberRings.isEmpty ? 4 : 2)
                    }

                    if !isChild {
                        let columns = [GridItem(.adaptive(minimum: 110), spacing: 6)]
                        LazyVGrid(columns: columns, alignment: .center, spacing: 6) {
                            ForEach(memberRings) { member in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(memberColor(for: Optional(member.id), among: choresVM.members.map(\.id).sorted { $0.uuidString < $1.uuidString }))
                                        .frame(width: 7, height: 7)
                                    let name = member.display_name?.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let display = (name?.isEmpty == false ? name! : String(member.id.uuidString.prefix(8)))
                                    let assigned = choresAssigned(to: member)
                                    let ratioText = assigned.isEmpty ? "—" : "\(assigned.filter { $0.isComplete }.count)/\(assigned.count)"
                                    Text("\(display) \(ratioText)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 1)
                                .padding(.horizontal, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.secondary.opacity(0.06))
                                )
                            }

                            if !unassignedChores.isEmpty {
                                let ratioText = "\(unassignedChores.filter { $0.isComplete }.count)/\(unassignedChores.count)"
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 7, height: 7)
                                    Text("Unassigned \(ratioText)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 1)
                                .padding(.horizontal, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.secondary.opacity(0.06))
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.thinMaterial)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            }
            
            // If the user is a child, they will see a "Household" option on the front page
            if isChild, appState.household == nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Join Household", systemImage: "person.badge.plus")
                            .font(.headline)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        TextField("House code", text: $inviteCodeInput)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: inviteCodeInput) { _, newValue in
                                let upper = newValue.uppercased()
                                if upper != newValue {
                                    inviteCodeInput = upper
                                }
                            }
                            .autocorrectionDisabled(true)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button {
                            Task { await joinHouseholdDashboard() }
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
                .padding()
                .background(.thinMaterial)
                .cornerRadius(20)
            }

            VStack(spacing: 24) {
                
                // MARK: Upcoming Chores (next 7 days)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(isChild ? "My Upcoming Chores" : "Upcoming Chores")
                            .font(.headline)
                        Spacer()
                        NavigationLink {
                            ChoresListView()
                        } label: {
                            Text("View all")
                        }
                    }

                    if upcomingChoresForDashboard.isEmpty {
                        Text("Nothing due in the next 7 days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(upcomingChoresForDashboard) { chore in
                            HStack(spacing: 8) {
                                Text(chore.title)
                                    .lineLimit(1)
                                if let name = assigneeLabel(for: chore) {
                                    Label(name, systemImage: "person.fill")
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .minimumScaleFactor(0.85)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 6)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .layoutPriority(1)
                                }
                                Spacer()
                                if let d = chore.dueDate {
                                    Text(relativeLabel(for: d))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("No date")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(20)
                
                // MARK: Quick Actions
                HStack(spacing: 12) {
                    NavigationLink {
                        ChoresListView(focusAddField: true)
                    } label: {
                        Label("Add Chore", systemImage: "plus.circle")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })

                    Button {
                        // Prefill event for today 9-10 AM
                        let base = Calendar.current.startOfDay(for: Date())
                        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
                        prefilledEventStart = start
                        prefilledEventEnd = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
                        if !dashboardEventStore.isAuthorized {
                            dashboardEventStore.requestAccess()
                        }
                        showAddEvent = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("Add Event", systemImage: "calendar.badge.plus")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }

                    NavigationLink {
                        GroceriesView()
                    } label: {
                        Label("Add Grocery", systemImage: "cart.badge.plus")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })
                }
                .contextMenu {
                    let percent = Int((ringRatio * 100).rounded())
                    Text("\(percent)% complete of chores due today or overdue")
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(20)

                // MARK: Upcoming Events (next 7 days)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Upcoming Events")
                            .font(.headline)
                        Spacer()
                        NavigationLink {
                            CalendarView()
                        } label: {
                            Text("View all")
                        }
                    }

                    if !eventStore.isAuthorized {
                        Button {
                            eventStore.requestAccess()
                        } label: {
                            Label("Connect Calendar", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    } else if eventStore.upcomingEvents.isEmpty {
                        Text("No upcoming events in the next 7 days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(eventStore.upcomingEvents.prefix(3), id: \.eventIdentifier) { event in
                            HStack(spacing: 8) {
                                Text(event.title)
                                    .lineLimit(1)
                                Spacer()
                                if event.isAllDay {
                                    Text("All-day")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(20)
                
                // MARK: Invite Family
                if isParent, let code = appState.household?.invite_code {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Invite Family")
                                .font(.headline)
                            Spacer()
                            Text(code)
                                .monospaced()
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = code
                                copyToast = "Copied ✅"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if copyToast == "Copied ✅" { copyToast = nil } }
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
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(20)
                }

                // MARK: Join or Create Household (if none)
                if appState.household?.id == nil, isParent {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Household Setup")
                            .font(.headline)

                        Text("Create a new household or join an existing one as a parent.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            HouseholdSetupView()
                                .environmentObject(appState)
                        } label: {
                            Label("Create Household", systemImage: "house.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Join Existing Household", systemImage: "person.badge.plus")
                                .font(.subheadline)

                            HStack(spacing: 8) {
                                TextField("House code", text: $inviteCodeInput)
                                    .textInputAutocapitalization(.characters)
                                    .onChange(of: inviteCodeInput) { _, newValue in
                                        let upper = newValue.uppercased()
                                        if upper != newValue {
                                            inviteCodeInput = upper
                                        }
                                    }
                                    .autocorrectionDisabled(true)
                                    .padding(10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    Task { await joinHouseholdDashboard() }
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
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(20)
                }

                // MARK: Grocery Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Groceries Remaining")
                        .font(.headline)

                    Text("\(groceryVM.items.filter { !$0.is_purchased }.count) items left")
                        .font(.title3)
                        .bold()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .cornerRadius(20)

            }
            .padding()
        }
        .navigationTitle(appState.household?.name ?? "Dashboard") // This is the default name, otherwise, we will just use the name set for the user's household
        .task(id: appState.household?.id) {
            await choresVM.load()
            if eventStore.isAuthorized {
                eventStore.loadUpcomingEvents(daysAhead: 7, primaryOnly: true)
            }
        }
        .refreshable {
            await choresVM.load()
        }
        .sheet(isPresented: $showAddEvent) {
            NavigationStack {
                AddEventInlineView(
                    startDate: prefilledEventStart,
                    endDate: prefilledEventEnd,
                    onCancel: { showAddEvent = false },
                    onSave: { title, notes, isAllDay in
                        dashboardEventStore.addEvent(
                            title: title,
                            startDate: prefilledEventStart,
                            endDate: prefilledEventEnd,
                            notes: notes.isEmpty ? nil : notes,
                            isAllDay: isAllDay
                        )
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showAddEvent = false
                        copyToast = "Event added ✅"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if copyToast == "Event added ✅" { copyToast = nil }
                        }
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let copyToast {
                Text(copyToast)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
    }
}

// Add an event to the calendar from the Dashboard
private struct AddEventInlineView: View {
    let startDate: Date
    let endDate: Date
    let onCancel: () -> Void
    let onSave: (String, String, Bool) -> Void
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var allDay: Bool = false

    var body: some View {
        Form {
            Section("Title") {
                TextField("Event title", text: $title)
            }
            Section("When") {
                Text(startDate.formatted(date: .abbreviated, time: .shortened) + " – " + endDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("All-day", isOn: $allDay)
            }
            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("New Event")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed, notes, allDay)
                }
            }
        }
    }
}
