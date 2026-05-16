import SwiftUI
import EventKit

final class CalendarEventStore: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?

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
                if granted {
                    // No-op here; the view will trigger loadEvents via onChange
                }
            }
        }
    }

    func loadEvents(for date: Date) {
        guard isAuthorized else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let fetched = store.events(matching: predicate).sorted { lhs, rhs in
            lhs.startDate < rhs.startDate
        }
        DispatchQueue.main.async {
            self.events = fetched
        }
    }

    func addTestEvent(on date: Date) {
        guard isAuthorized else { return }
        let event = EKEvent(eventStore: store)
        event.title = "Test Event"

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .hour, value: 9, to: startOfDay) ?? date
        let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)

        event.startDate = start
        event.endDate = end
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)
            // Reload events for that day
            loadEvents(for: date)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to save event: \(error.localizedDescription)"
            }
        }
    }

    private func updateAuthorizationStatus() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            isAuthorized = true
        case .notDetermined, .denied, .restricted, .writeOnly:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
}
