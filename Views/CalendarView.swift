// The calendar view--connect with the user's current Apple Calendar just becuase...might update later.

import SwiftUI
import EventKit

struct CalendarView: View {
    // MARK: - State
    @State private var selectedDate = Date()
    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @StateObject private var eventStore = CalendarEventStore()

    @State private var showingAddEvent = false
    @State private var editingEvent: EKEvent? = nil

    // Fields for the form
    @State private var newTitle = ""
    @State private var newStart = Date()
    @State private var newEnd = Date().addingTimeInterval(3600)
    @State private var newAllDay = false
    @State private var newNotes = ""

    private enum CalendarMode: String, CaseIterable { case month, day }
    @State private var mode: CalendarMode = .month

    // MARK: - Derived
    private var monthTitle: String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "LLLL yyyy" // e.g., March 2026
        return df.string(from: displayedMonth)
    }

    private var monthDates: [Date] {
        Self.generateMonthGrid(for: displayedMonth)
    }

    private var eventDotsByDay: [Date: [Color]] {
        var map: [Date: [Color]] = [:]
        let cal = Calendar.current
        for e in eventStore.events {
            let key = cal.startOfDay(for: e.startDate)
            var arr = map[key] ?? []
            let col = eventColor(e)
            arr.append(col)
            if arr.count > 3 { arr = Array(arr.prefix(3)) }
            map[key] = arr
        }
        return map
    }

    private var eventsForSelectedDay: [EKEvent] {
        let cal = Calendar.current
        return eventStore.events
            .filter { cal.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header
            if mode == .day {
                VStack(spacing: 8) {
                    MonthHeaderView(
                        title: selectedDate.formatted(date: .complete, time: .omitted),
                        onPrev: { changeDay(by: -1) },
                        onToday: { goToToday() },
                        onNext: { changeDay(by: 1) },
                        onAdd: { presentAdd() }
                    )

                    Picker("Mode", selection: $mode) {
                        Text("Month").tag(CalendarMode.month) // Month view
                        Text("Day").tag(CalendarMode.day) // Day view
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                Divider()
            } else {
                VStack(spacing: 8) {
                    MonthHeaderView(
                        title: monthTitle,
                        onPrev: { changeMonth(by: -1) },
                        onToday: { goToToday() },
                        onNext: { changeMonth(by: 1) },
                        onAdd: { presentAdd() }
                    )

                    Picker("Mode", selection: $mode) {
                        Text("Month").tag(CalendarMode.month) // Month view
                        Text("Day").tag(CalendarMode.day) // Day view
                    }
                    .pickerStyle(.segmented)

                    WeekdayRow()

                    MonthGrid(
                        dates: monthDates,
                        month: displayedMonth,
                        selectedDate: selectedDate,
                        dotColorsByDay: eventDotsByDay,
                        onSelect: { date in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedDate = date
                                mode = .day
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if !Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
                                displayedMonth = Calendar.current.startOfMonth(for: date)
                                loadMonthEvents()
                            }
                        }
                    )
                    .animation(.easeInOut, value: displayedMonth)
                }
                .padding(.vertical, 4)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .compositingGroup()
                .gesture(
                    DragGesture(minimumDistance: 20).onEnded { value in
                        let dx = value.translation.width
                        if abs(dx) > 30 {
                            if dx < 0 {
                                changeMonth(by: 1)
                            } else {
                                changeMonth(by: -1)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                )
                .padding(.horizontal, 8)
                .padding(.top, -6)
            }

            if !eventStore.isAuthorized {
                ContentUnavailableView(
                    "Calendar Access Needed",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Allow access to show your events.")
                )
                Button("Allow Calendar Access") { eventStore.requestAccess() }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
            } else {
                if mode == .day {
                    DayTimelineView(
                        date: selectedDate,
                        events: eventsForSelectedDay,
                        colorProvider: eventColor(_:),
                        onEventTap: { event in
                            editingEvent = event
                            newTitle = event.title
                            newAllDay = event.isAllDay
                            newStart = event.startDate
                            newEnd = event.endDate
                            newNotes = event.notes ?? ""
                            showingAddEvent = true
                        },
                        onEventMove: { event, newStart, newEnd in
                            // Persist a drag/drop move.
                            eventStore.update(
                                event: event,
                                title: event.title,
                                startDate: newStart,
                                endDate: newEnd,
                                notes: event.notes,
                                isAllDay: event.isAllDay
                            )
                            loadMonthEvents()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        },
                        onEventDelete: { event in
                            eventStore.delete(event: event)
                            loadMonthEvents()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    )
                    .refreshable { loadMonthEvents() }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Agenda List
                    List {
                        if eventsForSelectedDay.isEmpty {
                            Section {
                                EmptyStateView(
                                    title: "No events scheduled",
                                    subtitle: selectedDate.formatted(date: .abbreviated, time: .omitted)
                                )
                                .listRowInsets(EdgeInsets())
                            }
                        } else {
                            Section(header: Text(selectedDate.formatted(date: .complete, time: .omitted))) {
                                ForEach(eventsForSelectedDay, id: \.eventIdentifier) { event in
                                    EventRowView(event: event, color: eventColor(event))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // Prefill editor with selected event
                                            editingEvent = event
                                            newTitle = event.title
                                            newAllDay = event.isAllDay
                                            newStart = event.startDate
                                            newEnd = event.endDate
                                            newNotes = event.notes ?? ""
                                            showingAddEvent = true
                                        }
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        let event = eventsForSelectedDay[index]
                                        eventStore.delete(event: event)
                                    }
                                    loadMonthEvents()
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { loadMonthEvents() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Calendar")
        .onAppear {
            // Ensure month view and events are in sync on appear
            displayedMonth = Calendar.current.startOfMonth(for: selectedDate)
            loadMonthEvents()
        }
        .onChange(of: displayedMonth) { _ in
            loadMonthEvents()
        }
        .onChange(of: selectedDate) { newDate in
            // If user scrolls/selects into a different month via the grid
            if !Calendar.current.isDate(newDate, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = Calendar.current.startOfMonth(for: newDate)
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            NavigationStack {
                Form {
                    Section("Title") {
                        TextField("Event title", text: $newTitle)
                    }

                    Section("When") {
                        Toggle("All-day", isOn: $newAllDay)

                        DatePicker("Start", selection: $newStart, displayedComponents: newAllDay ? [.date] : [.date, .hourAndMinute])
                            .onChange(of: newStart) { newValue in
                                if newEnd <= newValue { newEnd = newValue.addingTimeInterval(60) }
                            }
                        DatePicker("End", selection: $newEnd, displayedComponents: newAllDay ? [.date] : [.date, .hourAndMinute])
                    }

                    Section("Notes") {
                        TextField("Optional notes", text: $newNotes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .navigationTitle(editingEvent == nil ? "New Event" : "Edit Event")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) {
                            showingAddEvent = false
                            editingEvent = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: {
                            // Basic validation
                            let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !title.isEmpty else { return }

                            // Ensure end is after start
                            let safeEnd = max(newEnd, newStart.addingTimeInterval(60))

                            if let editing = editingEvent {
                                eventStore.update(event: editing,
                                                  title: title,
                                                  startDate: newStart,
                                                  endDate: safeEnd,
                                                  notes: newNotes.isEmpty ? nil : newNotes,
                                                  isAllDay: newAllDay)
                            } else {
                                eventStore.addEvent(
                                    title: title,
                                    startDate: newStart,
                                    endDate: safeEnd,
                                    notes: newNotes.isEmpty ? nil : newNotes,
                                    isAllDay: newAllDay
                                )
                            }

                            // Reload and dismiss
                            loadMonthEvents()
                            showingAddEvent = false
                            editingEvent = nil
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        })
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CalendarQuickAdd"))) { output in
            guard let date = output.object as? Date else { return }
            newStart = date
            newEnd = Calendar.current.date(byAdding: .minute, value: 60, to: date) ?? date.addingTimeInterval(3600)
            newTitle = ""
            newNotes = ""
            newAllDay = false
            editingEvent = nil
            showingAddEvent = true
        }
    }

    // MARK: - Actions
    private func presentAdd() {
        // Pre-fill start/end to selected day at 9am-10am
        let base = Calendar.current.startOfDay(for: selectedDate)
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
        newStart = start
        newEnd = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)

        newTitle = ""
        newNotes = ""
        newAllDay = false
        editingEvent = nil

        showingAddEvent = true
    }

    private func goToToday() {
        let today = Date()
        selectedDate = today
        displayedMonth = Calendar.current.startOfMonth(for: today)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        loadMonthEvents()
    }

    private func changeMonth(by delta: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = Calendar.current.startOfMonth(for: newMonth)
        }
    }
    
    private func changeDay(by delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            selectedDate = newDate
            if !Calendar.current.isDate(newDate, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = Calendar.current.startOfMonth(for: newDate)
                loadMonthEvents()
            }
        }
    }

    private func loadMonthEvents() {
        guard eventStore.isAuthorized else { return }
        let cal = Calendar.current
        let start = cal.startOfMonth(for: displayedMonth)
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
        eventStore.loadEvents(in: start, end: end, primaryOnly: true)
    }

    private func eventColor(_ event: EKEvent) -> Color {
        if let cg = event.calendar.cgColor { return Color(cgColor: cg) }
        return .accentColor
    }

    // MARK: - Helpers
    private static func generateMonthGrid(for month: Date) -> [Date] {
        let cal = Calendar.current
        let first = cal.startOfMonth(for: month)
        let weekday = cal.component(.weekday, from: first)
        let offset = (weekday - cal.firstWeekday + 7) % 7
        guard let gridStart = cal.date(byAdding: .day, value: -offset, to: first) else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }
}

// MARK: - Subviews
private struct MonthHeaderView: View {
    let title: String
    let onPrev: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Today", action: onToday)
                .buttonStyle(.bordered)
                .font(.caption)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .imageScale(.medium)
                    .padding(6)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.primary)
    }
}

private struct WeekdayRow: View {
    private var symbols: [String] {
        var syms = Calendar.current.shortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1 // convert to 0-based index
        if first > 0 { syms = Array(syms[first...]) + Array(syms[..<first]) }
        return syms
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(symbols, id: \.self) { s in
                Text(s)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct MonthGrid: View {
    let dates: [Date]
    let month: Date
    let selectedDate: Date
    let dotColorsByDay: [Date: [Color]]
    let onSelect: (Date) -> Void

    var body: some View {
        let cal = Calendar.current
        let columns = Array(repeating: GridItem(.flexible(minimum: 24), spacing: 4), count: 7)

        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(dates, id: \.self) { day in
                let isCurrentMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
                let isToday = cal.isDateInToday(day)
                let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                let key = cal.startOfDay(for: day)
                let dotColors = dotColorsByDay[key] ?? []

                DayCellView(date: day,
                            isCurrentMonth: isCurrentMonth,
                            isToday: isToday,
                            isSelected: isSelected,
                            dotColors: dotColors,
                            onTap: { onSelect(day) })
            }
        }
    }
}

private struct DayCellView: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let dotColors: [Color]
    let onTap: () -> Void

    var body: some View {
        let day = Calendar.current.component(.day, from: date)
        VStack(spacing: 4) {
            Text("\(day)")
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(width: 30, height: 24)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.accentColor, lineWidth: 1)
                                )
                        } else if isToday {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.08))
                        }
                    }
                )
                .foregroundStyle(isCurrentMonth ? .primary : .secondary)

            // Dots for events
            HStack(spacing: 2) {
                ForEach(Array(dotColors.prefix(3)).indices, id: \.self) { i in
                    Circle().fill(dotColors[i]).frame(width: 4, height: 4)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(Calendar.current.isDateInWeekend(date) ? Color.secondary.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .opacity(isCurrentMonth ? 1.0 : 0.45)
    }
}

private struct EventRowView: View {
    let event: EKEvent
    let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if event.isAllDay {
                        Text("All-day")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let loc = event.location, !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(loc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
    }
}

private struct DayTimelineView: View {
    let date: Date
    let events: [EKEvent]
    let colorProvider: (EKEvent) -> Color
    let onEventTap: (EKEvent) -> Void
    let onEventMove: (EKEvent, Date, Date) -> Void
    let onEventDelete: (EKEvent) -> Void

    private let hourHeight: CGFloat = 52
    private let leftGutter: CGFloat = 46
    private let rightPadding: CGFloat = 12
    private let eventSpacing: CGFloat = 3
    private let minEventHeight: CGFloat = 28

    @State private var didAutoScroll = false
    @State private var draggingEventId: String? = nil
    @State private var dragTranslationY: CGFloat = 0
    @State private var dragOriginStart: Date? = nil
    @State private var dragOriginEnd: Date? = nil

    private func minutesDelta(from translationY: CGFloat) -> Int {
        // hourHeight represents 60 minutes
        Int((translationY / hourHeight) * 60)
    }

    private func snapTo15(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let snapped = (minute / 15) * 15
        return cal.date(bySettingHour: hour, minute: snapped, second: 0, of: date) ?? date
    }
    
    var body: some View {
        GeometryReader { outerGeo in
            let totalWidth = outerGeo.size.width
            let contentHeight = hourHeight * 24

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        // Hour grid built with real layout (no .offset), so ScrollViewReader anchors work.
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                HStack(spacing: 0) {
                                    Text(hourLabel(hour))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: leftGutter - 6, alignment: .trailing)

                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(height: 0.5)
                                        .frame(maxWidth: .infinity)
                                }
                                .frame(height: hourHeight)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Tap an hour row to quick-add an event at that hour.
                                    let cal = Calendar.current
                                    let base = cal.startOfDay(for: date)
                                    let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    NotificationCenter.default.post(name: Notification.Name("CalendarQuickAdd"), object: start)
                                }
                                .id("hour-\(hour)")
                            }

                            // Bottom boundary line (24:00)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 0.5)
                                .padding(.leading, leftGutter)
                                .id("hour-24")
                        }
                        .frame(height: contentHeight)

                        // Now indicator (overlay)
                        if Calendar.current.isDateInToday(date) {
                            let nowY = nowYOffset()
                            Rectangle()
                                .fill(Color.red)
                                .frame(height: 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, leftGutter)
                                .offset(y: nowY)
                                .id("nowLine")

                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .offset(x: leftGutter - 3, y: nowY - 2)
                        }

                        // Events overlay
                        let boxes = layoutBoxes(totalWidth: totalWidth)
                        ForEach(boxes) { box in
                            let eid = box.event.eventIdentifier
                            let isDragging = (draggingEventId == eid)

                            Button {
                                onEventTap(box.event)
                            } label: {
                                DayEventBlock(
                                    box: box,
                                    isDragging: isDragging,
                                    dragYOffset: isDragging ? dragTranslationY : 0
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onEventDelete(box.event)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 10)
                                    .onChanged { value in
                                        if draggingEventId != eid {
                                            draggingEventId = eid
                                            dragOriginStart = box.event.startDate
                                            dragOriginEnd = box.event.endDate
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                        dragTranslationY = value.translation.height
                                    }
                                    .onEnded { value in
                                        guard draggingEventId == eid,
                                              let originStart = dragOriginStart,
                                              let originEnd = dragOriginEnd
                                        else {
                                            draggingEventId = nil
                                            dragTranslationY = 0
                                            dragOriginStart = nil
                                            dragOriginEnd = nil
                                            return
                                        }

                                        let deltaMin = minutesDelta(from: value.translation.height)

                                        let cal = Calendar.current
                                        let base = cal.startOfDay(for: date)
                                        let dayEnd = cal.date(byAdding: .day, value: 1, to: base) ?? base.addingTimeInterval(86400)

                                        var movedStart = snapTo15(cal.date(byAdding: .minute, value: deltaMin, to: originStart) ?? originStart)
                                        let duration = originEnd.timeIntervalSince(originStart)
                                        var movedEnd = movedStart.addingTimeInterval(duration)

                                        // Clamp within the selected day
                                        if movedStart < base {
                                            movedStart = base
                                            movedEnd = base.addingTimeInterval(duration)
                                        }
                                        if movedEnd > dayEnd {
                                            movedEnd = dayEnd
                                            movedStart = dayEnd.addingTimeInterval(-duration)
                                        }

                                        draggingEventId = nil
                                        dragTranslationY = 0
                                        dragOriginStart = nil
                                        dragOriginEnd = nil

                                        onEventMove(box.event, movedStart, movedEnd)
                                    }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: contentHeight)
                    .contentShape(Rectangle())
                    .padding(.bottom, 24)
                }
                // Give the scroll view the remaining height so it doesn't collapse.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Add enough bottom space so content isn't hidden behind the tab bar.
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 90) }
                .onChange(of: date) { _ in
                    didAutoScroll = false
                    if Calendar.current.isDateInToday(date) {
                        withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("nowLine", anchor: .top) }
                        didAutoScroll = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("hour-\(defaultScrollHour)", anchor: .top) }
                        didAutoScroll = true
                    }
                }
                .onAppear {
                    if !didAutoScroll {
                        if Calendar.current.isDateInToday(date) {
                            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("nowLine", anchor: .top) }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("hour-\(defaultScrollHour)", anchor: .top) }
                        }
                        didAutoScroll = true
                    }
                }
                .onChange(of: events) { _ in
                    if !Calendar.current.isDateInToday(date) {
                        withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo("hour-\(defaultScrollHour)", anchor: .top) }
                    }
                }
            }
        }
    }

    private var allDayEvents: [EKEvent] { events.filter { $0.isAllDay } }
    private var timedEvents: [EKEvent] { events.filter { !$0.isAllDay } }

    private var firstEventHour: Int? {
        let cal = Calendar.current
        return timedEvents.map { cal.component(.hour, from: $0.startDate) }.min()
    }

    private var defaultScrollHour: Int {
        return firstEventHour ?? 8
    }

    private func hourLabel(_ hour: Int) -> String {
        var h = hour
        if h == 0 { return "12 AM" }
        if h < 12 { return "\(h) AM" }
        if h == 12 { return "12 PM" }
        return "\(h - 12) PM"
    }

    private func nowYOffset() -> CGFloat {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let minutes = max(0, min(24*60, Int(Date().timeIntervalSince(start) / 60)))
        return CGFloat(minutes) / 60 * hourHeight
    }

    private struct EventBox: Identifiable {
        let id = UUID()
        let event: EKEvent
        let y: CGFloat
        let height: CGFloat
        let x: CGFloat
        let width: CGFloat
        let color: Color
    }

    private func layoutBoxes(totalWidth: CGFloat) -> [EventBox] {
        let availableWidth = totalWidth - leftGutter - rightPadding
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)

        // Build clusters of overlapping events
        let evs = timedEvents.sorted { $0.startDate < $1.startDate }
        var clusters: [[EKEvent]] = []
        var current: [EKEvent] = []
        var currentEnd = Date.distantPast
        for e in evs {
            if current.isEmpty {
                current = [e]
                currentEnd = e.endDate
            } else if e.startDate < currentEnd {
                current.append(e)
                if e.endDate > currentEnd { currentEnd = e.endDate }
            } else {
                clusters.append(current)
                current = [e]
                currentEnd = e.endDate
            }
        }
        if !current.isEmpty { clusters.append(current) }

        var boxes: [EventBox] = []
        for cluster in clusters {
            // Assign columns greedily
            var columnEnds: [Date] = []
            var columnForEvent: [String: Int] = [:]
            for e in cluster {
                var placed = false
                for col in 0..<columnEnds.count {
                    if columnEnds[col] <= e.startDate {
                        columnEnds[col] = e.endDate
                        columnForEvent[e.eventIdentifier] = col
                        placed = true
                        break
                    }
                }
                if !placed {
                    columnEnds.append(e.endDate)
                    columnForEvent[e.eventIdentifier] = columnEnds.count - 1
                }
            }
            let columnCount = max(1, columnEnds.count)
            let slotWidth = (availableWidth - CGFloat(columnCount - 1) * eventSpacing) / CGFloat(columnCount)

            for e in cluster {
                let col = columnForEvent[e.eventIdentifier] ?? 0
                let s = max(start, e.startDate)
                let en = min(end, e.endDate)
                let minutesFromStart = max(0, Int(s.timeIntervalSince(start) / 60))
                let durationMinutes = max(1, Int(en.timeIntervalSince(s) / 60))
                let y = CGFloat(minutesFromStart) / 60 * hourHeight
                let h = max(minEventHeight, CGFloat(durationMinutes) / 60 * hourHeight)
                let x = leftGutter + CGFloat(col) * (slotWidth + eventSpacing)
                let color = colorProvider(e)
                boxes.append(EventBox(event: e, y: y, height: h, x: x, width: slotWidth, color: color))
            }
        }
        return boxes
    }

    private struct DayEventBlock: View {
        let box: EventBox
        let isDragging: Bool
        let dragYOffset: CGFloat

        var body: some View {
            HStack(spacing: 0) {
                // Left color stripe (matches Apple Calendar feel)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(box.color)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(box.event.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    if !box.event.isAllDay {
                        Text("\(box.event.startDate.formatted(date: .omitted, time: .shortened)) – \(box.event.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: box.width, height: box.height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(box.color.opacity(isDragging ? 0.9 : 0.35), lineWidth: isDragging ? 2 : 1)
            )
            .shadow(color: .black.opacity(isDragging ? 0.18 : 0), radius: 10, x: 0, y: 6)
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .offset(x: box.x, y: box.y + (isDragging ? dragYOffset : 0))
            .zIndex(isDragging ? 10 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - Calendar helper
fileprivate extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

