import SwiftUI

struct SoldierEditor: View {
    @State var soldier: SoldierDraft
    let isNew: Bool
    let store: LeaderStore
    let save: (SoldierDraft, [ImportedRecordFile]) async throws -> Void
    @State private var files: [ImportedRecordFile] = []
    @State private var photoOperation = OwnedOperation()
    @State private var saveOperation = OwnedOperation()
    @Environment(\.dismiss) private var dismiss
        @State private var confirmingCancel = false
    @State private var original: SoldierDraft?

    var body: some View {
        NavigationStack {
            Form {
                SoldierPhotoPicker(attachment: $soldier.photo, files: $files, store: store, operation: photoOperation)
                Section("Soldier") {
                    TextField("Name", text: $soldier.name)
                        .textContentType(.name)
                        .accessibilityIdentifier("soldierName")
                    Picker("Rank", selection: $soldier.rank) {
                        ForEach(Rank.allCases, id: \.self) { rank in Text(rank.rawValue).tag(rank) }
                    }
                    .accessibilityIdentifier("soldierRank")
                    TextField("Unit / Platoon", text: $soldier.unit)
                    TextField("Team", text: $soldier.team)
                }.leadersBookRow()
                Section {
                    ForEach($soldier.training) { $item in
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Training title", text: $item.title)
                            if item.completionDates == nil && item.certificate == nil {
                                Toggle("Complete", isOn: $item.completed)
                            } else { Text("Completed Training Record") }
                            Toggle("Track due date", isOn: $item.tracksDueDate)
                            if item.tracksDueDate {
                                DatePicker("Due date", selection: $item.dueDate, displayedComponents: .date)
                            }
                            Button("Remove Training Item", systemImage: "minus.circle", role: .destructive) {
                                soldier.training.removeAll { $0.id == item.id }
                            }.foregroundStyle(Color.lbDanger)
                            .font(.footnote)
                        }
                        .padding(.vertical, 4)
                    }
                    Button("Add Training Item", systemImage: "plus.circle") { soldier.training.append(TrainingDraft()) }.buttonStyle(LBActionButtonStyle())
                } header: {
                    Text("Training Checklist")
                } footer: {
                    Text("Use your unit’s requirements and due dates. This is a personal checklist, not an official training system.")
                }.leadersBookRow()
                Section {
                    TextField("Leadership notes", text: $soldier.notes, axis: .vertical)
                        .lineLimit(4...12)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Records stay on this device. Keep notes limited to information your organization permits you to store here.")
                }.leadersBookRow()
            }.leadersBookList()
            .disabled(saveOperation.phase.isRunning)
            .navigationTitle(isNew ? "Add Soldier" : "Edit Soldier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        if original == soldier { dismiss() } else { confirmingCancel = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        saveOperation.start("Save Soldier") {
                            try await save(soldier, files)
                            dismiss()
                        }
                    }
                    .disabled(photoOperation.phase.isRunning || saveOperation.phase.isRunning || soldier.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveSoldier")
                }
            }
            .onAppear { if original == nil { original = soldier } }
            .interactiveDismissDisabled(original != nil && original != soldier)
            .confirmationDialog("Discard Unsaved Changes?", isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }.foregroundStyle(Color.lbDanger)
            }
            .onDisappear { photoOperation.cancel(); saveOperation.cancel() }
            .alert(item: Binding(get: { saveOperation.phase.failure }, set: { if $0 == nil { saveOperation.dismissFailure() } })) { failure in
                Alert(title: Text("Couldn’t Save Soldier"), message: Text(failure.localizedDescription), dismissButton: .default(Text("OK")))
            }
        }
    }
}
