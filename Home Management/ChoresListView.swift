import SwiftUI

fileprivate struct ErrorBox: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

public struct ChoresListView: View {
    @StateObject private var viewModel = ChoresViewModel()
    @State private var errorBox: ErrorBox? = nil

    public var body: some View {
        List {
            Section {
                TextField("New chore", text: Binding(
                    get: { viewModel.newTitle },
                    set: { viewModel.newTitle = $0 }
                ))
                if let _ = viewModel.newDueDate {
                    DatePicker(
                        "Due date",
                        selection: Binding(
                            get: { viewModel.newDueDate ?? Date() },
                            set: { viewModel.newDueDate = $0 }
                        ),
                        displayedComponents: [.date]
                    )
                }
                Button("Add") {
                    Task { await viewModel.add() }
                }
                .disabled(viewModel.newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section {
                ForEach(viewModel.chores) { chore in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(chore.title)
                            if let dueDate = chore.dueDate {
                                Text(dueDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            Task { await viewModel.toggle(chore) }
                        } label: {
                            Image(systemName: chore.isComplete ? "checkmark.square" : "square")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .onDelete { indexSet in
                    Task { await viewModel.delete(at: indexSet) }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            if let msg = newValue {
                errorBox = ErrorBox(message: msg)
                viewModel.errorMessage = nil
            }
        }
        .alert(item: $errorBox) { box in
            Alert(
                title: Text("Error"),
                message: Text(box.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationTitle("Chores")
    }
}

#Preview {
    NavigationStack {
        ChoresListView()
    }
}
