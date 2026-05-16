import SwiftUI

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.title)
            .padding()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
