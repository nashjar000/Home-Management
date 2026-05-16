//
//  CalendarView.swift
//  Home Management
//
//  Created by Jared Nash on 1/27/26.
//
import SwiftUI

struct CalendarView: View {
    @State private var displayedMonth: Date = Date()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 12) {
            header

            weekdayHeader

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(daysForMonthGrid(displayedMonth), id: \.self) { day in
                    dayCell(day)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Calendar")
    }

    private var header: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthYearString(displayedMonth))
                .font(.title2)
                .bold()

            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortStandaloneWeekdaySymbols // ["Sun","Mon",...]
        return HStack {
            ForEach(symbols, id: \.self) { s in
                Text(s)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ date: Date?) -> some View {
        let isToday = date.map { calendar.isDateInToday($0) } ?? false

        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))

            if let date {
                Text("\(calendar.component(.day, from: date))")
                    .font(.headline)
                    .foregroundStyle(isToday ? .primary : .primary)
            }
        }
        .frame(height: 44)
        .opacity(date == nil ? 0 : 1)
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    /// Returns an array of 42 items (6 weeks x 7 days) where nil = empty slot
    private func daysForMonthGrid(_ month: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return Array(repeating: nil, count: 42) }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) // 1=Sun
        let leadingEmpty = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)

        var current = firstOfMonth
        while current < monthInterval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        // pad to 42 cells for a consistent grid
        while days.count < 42 {
            days.append(nil)
        }
        return days
    }
}

#Preview {
    NavigationStack { CalendarView() }
}
