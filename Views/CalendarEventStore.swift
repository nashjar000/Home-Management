// Saving events in calendar logic

import Foundation
import EventKit
import Combine

final class CalendarEventStore: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?
    @Published var upcomingEvents: [EKEvent] = []

    private let store = EKEventStore()

    init() {
        updateAuthorizationStatus()
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Calendar access error: \(error.localizedDescription)"
                }
                self?.isAuthorized = granted
            }
        }
    }

    func loadEvents(for date: Date) {
        guard isAuthorized else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let found = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        DispatchQueue.main.async {
            self.events = found
        }
    }
    
    func loadEvents(in start: Date, end: Date, primaryOnly: Bool = true) {
        guard isAuthorized else { return }
        let calendars: [EKCalendar]?
        if primaryOnly, let defaultCal = store.defaultCalendarForNewEvents {
            calendars = [defaultCal]
        } else {
            calendars = nil
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let found = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        DispatchQueue.main.async {
            self.events = found
        }
    }
    
    func loadUpcomingEvents(daysAhead: Int = 7, primaryOnly: Bool = true) {
        guard isAuthorized else { return }
        let cal = Calendar.current
        let now = Date()
        let start = now
        let end = cal.date(byAdding: .day, value: daysAhead, to: start) ?? now

        let calendars: [EKCalendar]?
        if primaryOnly, let defaultCal = store.defaultCalendarForNewEvents {
            calendars = [defaultCal]
        } else {
            calendars = nil
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let found = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        DispatchQueue.main.async {
            self.upcomingEvents = found
        }
    }

    func addEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil,
        isAllDay: Bool = false
    ) {
        guard isAuthorized else { return }

        let event = EKEvent(eventStore: store)
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to save event: \(error.localizedDescription)"
            }
        }
    }
    
    func update(
        event: EKEvent,
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil,
        isAllDay: Bool = false
    ) {
        guard isAuthorized else { return }
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.notes = notes
        do {
            try store.save(event, span: .thisEvent)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to update event: \(error.localizedDescription)"
            }
        }
    }

    func delete(event: EKEvent) {
        guard isAuthorized else { return }
        do {
            try store.remove(event, span: .thisEvent)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to delete event: \(error.localizedDescription)"
            }
        }
    }

    private func updateAuthorizationStatus() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }
}

