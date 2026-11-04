import SwiftUI
import UniformTypeIdentifiers

struct TrainingRecordEditor: View {
    let soldier: SoldierDraft
    let save: (SoldierDraft, [ImportedRecordFile]) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var dates = [Calendar.current.startOfDay(for: Date.now)]
    @State private var certificate: ImportedRecordFile?
    @State private var importing = false
    @State private var importOperation = OwnedOperation()
    @State private var saveOperation = OwnedOperation()
    @State private var discarding = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Training") {
                    TextField("Training Title", text: $title).accessibilityIdentifier("trainingTitle")
                }.leadersBookRow()
                Section("Dates Completed") {
                    ForEach(dates.indices, id: \.self) { index in
                        DatePicker("Completion \(index + 1)", selection: $dates[index], in: ...Date.now, displayedComponents: .date)
                    }
                    Button("Add Completion Date", systemImage: "plus") { dates.append(Calendar.current.startOfDay(for: .now)) }.buttonStyle(LBActionButtonStyle())
                    if dates.count > 1 {
                        Button("Remove Last Date", systemImage: "minus.circle", role: .destructive) { dates.removeLast() }.foregroundStyle(Color.lbDanger)
                    }
                }.leadersBookRow()
                Section {
                    if let certificate {
                        Label(certificate.attachment.name, systemImage: "doc.badge.checkmark")
                        Button("Remove Certificate", role: .destructive) { self.certificate = nil }.foregroundStyle(Color.lbDanger)
                    }
                    Button(certificate == nil ? "Upload Certificate" : "Replace Certificate", systemImage: "doc.badge.plus") { importing = true }.buttonStyle(LBActionButtonStyle())
                        .disabled(importOperation.phase.isRunning)
                    if importOperation.phase.isRunning { ProgressView("Preparing Certificate…") }
                } header: { Text("Certificate of Completion") } footer: {
                    Text("Import a PDF or image from Files, up to 10 MB. The certificate is saved locally with this record.")
                }.leadersBookRow()
            }.leadersBookList()
            .disabled(saveOperation.phase.isRunning)
            .navigationTitle("Add Training Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        if title.isEmpty && certificate == nil { dismiss() } else { discarding = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        var updated = soldier
                        let completed = Array(Set(dates.map { Calendar.current.startOfDay(for: $0) })).sorted()
                        updated.training.append(TrainingDraft(title: title.trimmingCharacters(in: .whitespacesAndNewlines), completed: true,
                                                            completionDates: completed, certificate: certificate?.attachment))
                        saveOperation.start("Save Training Record") {
                            try await save(updated, certificate.map { [$0] } ?? [])
                            dismiss()
                        }
                    }
                    .disabled(importOperation.phase.isRunning || saveOperation.phase.isRunning || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveTraining")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image]) { result in
                importOperation.start("Import Certificate") {
                    let file = try await RecordFileImport.read(result.get(), certificate: true)
                    try Task.checkCancellation()
                    certificate = file
                }
            }
            .interactiveDismissDisabled(!title.isEmpty || certificate != nil || importOperation.phase.isRunning)
            .confirmationDialog("Discard Training Record?", isPresented: $discarding, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }.foregroundStyle(Color.lbDanger)
            }
            .onDisappear { importOperation.cancel(); saveOperation.cancel() }
            .alert(item: Binding(get: { saveOperation.phase.failure ?? importOperation.phase.failure }, set: { if $0 == nil { saveOperation.dismissFailure(); importOperation.dismissFailure() } })) { failure in
                Alert(title: Text("Training Record Couldn’t Finish"), message: Text(failure.localizedDescription), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct HeightWeightEditor: View {
    let soldier: SoldierDraft
    let save: (SoldierDraft) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var height = ""
    @State private var weight = ""
    @State private var metric = false
    @State private var date = Calendar.current.startOfDay(for: Date.now)
    @State private var saveOperation = OwnedOperation()

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurements") {
                    Picker("Units", selection: $metric) {
                        Text("Inches / Pounds").tag(false)
                        Text("Centimeters / Kilograms").tag(true)
                    }.onChange(of: metric) { height = ""; weight = "" }
                    LabeledContent("Height (\(metric ? "cm" : "in"))") {
                        TextField("Height", text: $height).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("recordHeight")
                    }
                    LabeledContent("Weight (\(metric ? "kg" : "lb"))") {
                        TextField("Weight", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("recordWeight")
                    }
                    DatePicker("Recorded Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                }.leadersBookRow()
                Section {
                    Text("Records measured height and weight. This does not calculate body-fat percentage or certify compliance with Army body-composition policy.")
                        .font(.footnote).foregroundStyle(Color.lbTextSecondary)
                }.leadersBookRow()
            }.leadersBookList()
            .disabled(saveOperation.phase.isRunning)
            .navigationTitle("Add HT/WT Record").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        saveOperation.start("Save HT/WT Record") {
                            guard let h = Double(height.replacingOccurrences(of: ",", with: ".")),
                                  let w = Double(weight.replacingOccurrences(of: ",", with: ".")) else { throw RecordError.invalidMeasurements }
                            var updated = soldier
                            var history = updated.heightWeight ?? []
                            history.append(HeightWeightDTO(date: date, heightInches: metric ? h / 2.54 : h,
                                                          weightPounds: metric ? w * 2.2046226218 : w))
                            updated.heightWeight = history
                            try await save(updated)
                            dismiss()
                        }
                    }.accessibilityIdentifier("saveHeightWeight")
                }
            }
            .interactiveDismissDisabled(!height.isEmpty || !weight.isEmpty)
            .onDisappear { saveOperation.cancel() }
            .alert(item: Binding(get: { saveOperation.phase.failure }, set: { if $0 == nil { saveOperation.dismissFailure() } })) { failure in
                Alert(title: Text("Couldn’t Save HT/WT Record"), message: Text(failure.localizedDescription), dismissButton: .default(Text("OK")))
            }
        }
    }
}
