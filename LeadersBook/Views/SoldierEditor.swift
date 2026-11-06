import SwiftUI

struct SoldierEditor: View {
    @State var edit: SoldierEditSession
    let store: LeaderStore
    let save: (SoldierEditSession) async throws -> Void
    private var soldier: SoldierDraft {
        get { edit.soldier }
        nonmutating set { update(soldier: newValue, files: edit.files) }
    }
    private var soldierBinding: Binding<SoldierDraft> { Binding(get: { soldier }, set: { soldier = $0 }) }
    private var filesBinding: Binding<[ImportedRecordFile]> {
        Binding(get: { edit.files }, set: { update(soldier: soldier, files: $0) })
    }
    private func update(soldier: SoldierDraft, files: [ImportedRecordFile]) {
        var updated = edit
        updated.soldier = soldier; updated.files = files
        do { try store.updateSoldierEdit(updated); edit = updated }
        catch { if store.isUnlocked { store.operationFailure = AppFailure("Preserve Soldier Edits", underlying: error) } }
    }
    @State private var photoOperation = OwnedOperation()
    @State private var saveOperation = OwnedOperation()
    @Environment(\.dismiss) private var dismiss
        @State private var confirmingCancel = false

    private func discardAndDismiss() {
        do { try store.discardSoldierEdit(edit); dismiss() }
        catch { store.operationFailure = AppFailure("Discard Soldier Edits", underlying: error) }
    }
    var body: some View {
        NavigationStack {
            Form {
                SoldierPhotoPicker(attachment: soldierBinding.photo, files: filesBinding, store: store, operation: photoOperation)
                Section("Soldier") {
                    TextField("Name", text: soldierBinding.name)
                        .textContentType(.name)
                        .accessibilityIdentifier("soldierName")
                    Picker("Rank", selection: soldierBinding.rank) {
                        ForEach(Rank.allCases, id: \.self) { rank in Text(rank.rawValue).tag(rank) }
                    }
                    .accessibilityIdentifier("soldierRank")
                    TextField("Unit / Platoon", text: soldierBinding.unit)
                    TextField("Team", text: soldierBinding.team)
                }.leadersBookRow()
                Section {
                    ForEach(soldierBinding.training) { $item in
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
                    ProtectedNotesEditor(text: soldierBinding.notes).frame(minHeight: 150)
                    Text("To copy or share notes, save them, then use Authenticate to Export Notes in the soldier record.").font(.caption)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Saved records remain eligible for system backups. Keep notes limited to information your organization permits you to store here.")
                }.leadersBookRow()
            }.leadersBookList()
            .disabled(saveOperation.phase.isRunning)
            .navigationTitle(edit.isNew ? "Add Soldier" : "Edit Soldier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        if !edit.hasChanges { discardAndDismiss() } else { confirmingCancel = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        saveOperation.start("Save Soldier") {
                            try await save(edit)
                            dismiss()
                        }
                    }
                    .disabled(photoOperation.phase.isRunning || saveOperation.phase.isRunning || soldier.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveSoldier")
                }
            }
            .interactiveDismissDisabled(edit.hasChanges)
            .confirmationDialog("Discard Unsaved Changes?", isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { discardAndDismiss() }.foregroundStyle(Color.lbDanger)
            }
            .onDisappear { photoOperation.cancel(); saveOperation.cancel() }
            .alert(item: Binding(get: { saveOperation.phase.failure }, set: { if $0 == nil { saveOperation.dismissFailure() } })) { failure in
                Alert(title: Text("Couldn’t Save Soldier"), message: Text(failure.localizedDescription), dismissButton: .default(Text("OK")))
            }
        }
    }
}
