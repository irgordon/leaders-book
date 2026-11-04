import SwiftUI

private enum FitnessField: Hashable {
    case aft(AFTEvent), height, waist
}

struct FitnessView: View {
    let store: LeaderStore
    let records: BookSnapshot
    let scorer: AFTScoring
    @State private var deletingResult: UUID?
    @State private var saveResultOperation = OwnedOperation()
    @FocusState private var focusedField: FitnessField?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tool", selection: draftBinding(\.tool)) {
                        ForEach(FitnessTool.allCases, id: \.self) { tool in Text(tool.title).tag(tool) }
                    }
                    .accessibilityIdentifier("fitnessToolPicker")
                }.leadersBookRow()
                switch store.draft.tool {
                case .aft:
                    AFTInputs(store: store, records: records, scorer: scorer, saveOperation: saveResultOperation, focus: $focusedField)
                case .ratio:
                    RatioInputs(store: store, focus: $focusedField)
                case .history:
                    FitnessHistory(store: store, records: records, scorer: scorer) { deletingResult = $0 }
                }
            }.leadersBookList()
            .navigationTitle("Fitness")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", systemImage: "keyboard.chevron.compact.down") { focusedField = nil }
                        .accessibilityIdentifier("dismissFitnessKeyboard")
                }
            }
        }
        .confirmationDialog("Delete this saved AFT result?", isPresented: Binding(
            get: { deletingResult != nil }, set: { if !$0 { deletingResult = nil } }
        ), titleVisibility: .visible, presenting: deletingResult) { id in
            Button("Delete Result", role: .destructive) {
                store.submit("Delete Result") { try await store.deleteResults(ids: [id]) }
                deletingResult = nil
            }.foregroundStyle(Color.lbDanger)
        } message: { _ in Text("This permanently removes the result from this device.") }
        .onDisappear { saveResultOperation.cancel() }
        .onChange(of: store.draft.tool) { _, tool in if tool != .aft { saveResultOperation.cancel() } }
        .alert(item: Binding(get: { saveResultOperation.phase.failure }, set: { if $0 == nil { saveResultOperation.dismissFailure() } })) { failure in
            Alert(title: Text("Couldn’t Save AFT Result"), message: Text(failure.localizedDescription), dismissButton: .default(Text("OK")))
        }
    }

    private func draftBinding<T>(_ keyPath: WritableKeyPath<FitnessDraft, T>) -> Binding<T> {
        Binding(get: { store.draft[keyPath: keyPath] }, set: { value in
            var draft = store.draft
            draft[keyPath: keyPath] = value
            store.updateDraft(draft)
        })
    }
}

private struct AFTInputs: View {
    let store: LeaderStore
    let records: BookSnapshot
    let scorer: AFTScoring
    let saveOperation: OwnedOperation
    let focus: FocusState<FitnessField?>.Binding

    private var draft: FitnessDraft { store.draft }
    private var evaluation: Result<AFTDraftEvaluation, AppFailure> {
        Result { try scorer.evaluate(draft) }.mapError { AppFailure("Evaluate AFT", underlying: $0) }
    }
    private var result: AFTResult? {
        if case .success(let value) = evaluation { value.result } else { nil }
    }
    private var total: Int? { result?.total }

    var body: some View {
        Section("Scoring Profile") {
            Picker("Standard", selection: binding(\.standard)) {
                ForEach(AFTStandard.allCases) { Text($0.title).tag($0) }
            }
            Picker("Age band", selection: binding(\.ageBand)) {
                ForEach(scorer.tables.ageBands.indices, id: \.self) { index in
                    Text(scorer.tables.ageBands[index]).tag(index)
                }
            }
        }.leadersBookRow()
        Section {
            ForEach(Array(AFTEvent.allCases.enumerated()), id: \.element) { index, event in
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title).font(.headline)
                    Text(event.unit).font(.caption).foregroundStyle(Color.lbTextSecondary)
                    TextField(event.placeholder, text: Binding(
                        get: { draft.value(for: event) },
                        set: { value in
                            var updated = draft
                            updated.values[event.rawValue] = value
                            store.updateDraft(updated)
                        }
                    ))
                    .keyboardType(event.isTimed ? .numbersAndPunctuation : .numberPad)
                    .focused(focus, equals: .aft(event))
                    .accessibilityLabel("\(event.title), \(event.unit)")
                    .accessibilityIdentifier("aft-\(event.rawValue)")
                    if case .success(let value) = evaluation {
                        switch value.fields[event] {
                        case .scored(let points):
                            LBStatusLabel(text: "\(points.value)/100 — " + (points.meetsMinimum ? "Go" : "No Go"),
                                          status: points.meetsMinimum ? .success : .failure).font(.subheadline.monospacedDigit())
                        case .invalid(let error):
                            Label(error.localizedDescription, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Color.lbDanger)
                        case .empty: EmptyView()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Five event results")
        } footer: {
            Text("Inputs save automatically on this device, including incomplete results.")
        }.leadersBookRow()
        Section("Score") {
            if case .failure(let error) = evaluation {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
            }
            Text(total.map { "\($0) / 500" } ?? "— / 500")
                .font(.largeTitle.bold().monospacedDigit())
                .accessibilityIdentifier("aftTotal")
                .contentTransition(.numericText())
            if let result {
                AFTStatusSummary(result: result)
            } else {
                Text("Complete all five events to calculate the total.").foregroundStyle(Color.lbTextSecondary)
            }
        }.leadersBookRow()
        Section {
            Picker("Assign result to", selection: binding(\.soldierID)) {
                Text("Personal Result").tag(UUID?.none)
                ForEach(records.soldiers.sorted { $0.name < $1.name }) { soldier in
                    Text(soldier.displayName).tag(Optional(soldier.id))
                }
            }
            .accessibilityIdentifier("aftSoldierPicker")
            DatePicker("Test Date", selection: binding(\.testDate), in: ...Date.now, displayedComponents: .date)
            Button("Save AFT Result", systemImage: "square.and.arrow.down") {
                focus.wrappedValue = nil
                saveOperation.start("Save AFT Result") { try await store.saveResult() }
            }.buttonStyle(LBActionButtonStyle())
            .disabled(total == nil || saveOperation.phase.isRunning)
            .buttonStyle(LBPrimaryButtonStyle())
            .accessibilityIdentifier("saveAFTResult")
        } footer: {
            Text("Reference minimum: \(draft.standard.minimum) total and 60 in every event. Combat uses the age-normed M|C column. Alternate events and profiles are not scored.")
        }.leadersBookRow()
        Section("Scoring Source") {
            Link(destination: scorer.tables.source) { Label("Official AFT Score Tables · June 2025", systemImage: "arrow.up.right.square") }.buttonStyle(LBActionButtonStyle())
            Text("Bundled tables work offline. Confirm current policy and event procedures before using a result as an official record.")
                .font(.footnote)
                .foregroundStyle(Color.lbTextSecondary)
        }.leadersBookRow()

    }

    private func binding<T>(_ keyPath: WritableKeyPath<FitnessDraft, T>) -> Binding<T> {
        Binding(get: { draft[keyPath: keyPath] }, set: { value in
            var updated = draft
            updated[keyPath: keyPath] = value
            store.updateDraft(updated)
        })
    }
}

private struct RatioInputs: View {
    let store: LeaderStore
    let focus: FocusState<FitnessField?>.Binding
    private var draft: FitnessDraft { store.draft }
    private var evaluation: RatioEvaluation { RatioEvaluation(height: draft.height, waist: draft.waist) }

    var body: some View {
        Section("Measurements") {
            Picker("Units", selection: Binding(get: { draft.metric }, set: { metric in
                var updated = draft
                updated.metric = metric
                // Clear both values to avoid silently reinterpreting measurements in different units.
                updated.height = ""
                updated.waist = ""
                store.updateDraft(updated)
            })) {
                Text("Inches").tag(false)
                Text("Centimeters").tag(true)
            }
            .accessibilityIdentifier("ratioUnits")
            LabeledContent("Height (\(draft.metric ? "cm" : "in"))") {
                TextField("Height", text: measurementBinding(\.height))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad).focused(focus, equals: .height)
                    .accessibilityLabel("Height in \(draft.metric ? "centimeters" : "inches")")
                    .accessibilityIdentifier("ratioHeight")
            }
            LabeledContent("Waist (\(draft.metric ? "cm" : "in"))") {
                TextField("Waist", text: measurementBinding(\.waist))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad).focused(focus, equals: .waist)
                    .accessibilityLabel("Waist in \(draft.metric ? "centimeters" : "inches")")
                    .accessibilityIdentifier("ratioWaist")
            }
        }.leadersBookRow()
        Section("HT/WT Calculator") {
            switch evaluation {
            case .value(let ratio):
                Text(ratio.formatted(.number.precision(.fractionLength(3))))
                    .font(.largeTitle.bold().monospacedDigit()).accessibilityIdentifier("ratioResult")
                Text("Waist ÷ height. Weight is not used in this calculation.")
            case .empty:
                Text("—").font(.largeTitle.bold()).accessibilityIdentifier("ratioResult")
                Text("Enter positive height and waist measurements in the same units.")
            case .invalid(let error):
                Label(error.localizedDescription, systemImage: "exclamationmark.circle").foregroundStyle(Color.lbDanger)
            }
        }.leadersBookRow()
        Section {
            Text("This calculates a ratio, not body-fat percentage or Army height/weight compliance. Use your unit’s current approved measurement procedure.")
                .font(.footnote)
                .foregroundStyle(Color.lbTextSecondary)
            Link("Army Body Composition Program", destination: ReferenceContent.bodyCompositionURL).buttonStyle(LBActionButtonStyle())
        }.leadersBookRow()
    }

    private func measurementBinding(_ keyPath: WritableKeyPath<FitnessDraft, String>) -> Binding<String> {
        Binding(get: { draft[keyPath: keyPath] }, set: { value in
            var updated = draft
            updated[keyPath: keyPath] = value
            store.updateDraft(updated)
        })
    }
}

private struct FitnessHistory: View {
    let store: LeaderStore
    let records: BookSnapshot
    let scorer: AFTScoring
    let onDelete: (UUID) -> Void

    var body: some View {
        Section("Saved AFT Results") {
            if records.results.isEmpty {
                ContentUnavailableView("No Saved Results", systemImage: "chart.bar.doc.horizontal",
                                       description: Text("Complete an AFT and choose Save AFT Result."))
            }
            ForEach(records.results) { result in
                NavigationLink {
                    AFTResultView(result: result, ageBands: scorer.tables.ageBands)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.displayName).font(.headline)
                        Text("\(result.total) / 500 · \(result.date.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundStyle(Color.lbTextSecondary)
                        Text(result.standard.title).font(.caption).foregroundStyle(Color.lbTextSecondary)
                    }
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(result.id) }
                }
            }
        }.leadersBookRow()
    }
}
