import SwiftUI

struct ChoresView: View {
    var body: some View {
        Text("Chores")
            .font(.title)
            .padding()
    }
}

#Preview {
    NavigationStack {
        ChoresView()
    }
}
