import SwiftUI

struct CalendarView: View {
    var body: some View {
        Text("Calendar")
            .font(.title)
            .padding()
    }
}

#Preview {
    NavigationStack {
        CalendarView()
    }
}
