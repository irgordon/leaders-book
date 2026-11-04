import SwiftUI
import QuickLook

struct SoldiersView: View {
    let store: LeaderStore
    let records: BookSnapshot
    let scorer: AFTScoring
    @Environment(\.horizontalSizeClass) private var sizeClass
    @SceneStorage("selectedSoldier") private var selectedSoldier = ""
    @State private var query = ""
    @State private var editor: SoldierDraft?
    @State private var deleting: Soldier?
    @State private var trainingSoldier: Soldier?
    @State private var measuringSoldier: Soldier?
    @State private var previewURL: URL?
    @State private var previewOperation = OwnedOperation()

    @ScaledMetric private var rankWidth = 28
    @ScaledMetric private var rankHeight = 36

    private var selection: Binding<UUID?> {
        Binding(get: { UUID(uuidString: selectedSoldier) }, set: { selectedSoldier = $0?.uuidString ?? "" })
    }
    private var soldiers: [Soldier] {
        records.soldiers.filter {
            query.isEmpty || "\($0.displayName) \($0.unit) \($0.team)".localizedStandardContains(query)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(soldiers) { soldier in
                    NavigationLink(value: soldier.id) {
                        HStack {
                            SoldierPortrait(attachment: soldier.photo, store: store, size: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(soldier.displayName).font(.headline)
                                if !soldier.unit.isEmpty {
                                    Text(soldier.unit).foregroundStyle(Color.theme(sizeClass == .regular && selection.wrappedValue == soldier.id ? .textOnSelected : .textSecondary))
                                }
                                if soldier.overdueCount > 0 {
                                    LBStatusLabel(text: "\(soldier.overdueCount) Overdue Training Items", status: .failure)
                                        .font(.caption)
                                }
                            }
                            Spacer(minLength: 4)
                            RankInsignia(rank: soldier.rank).frame(width: rankWidth, height: rankHeight)
                        }
                    }.leadersBookRow(selected: sizeClass == .regular && selection.wrappedValue == soldier.id)
                }
            }.leadersBookList()
            .overlay {
                if records.soldiers.isEmpty {
                    ContentUnavailableView {
                        Label("Your Team Starts Here", systemImage: "person.2")
                    } description: {
                        Text("Add a soldier to keep unit details, training, and fitness results together.")
                    } actions: {
                        Button("Add Soldier", systemImage: "plus") { editor = SoldierDraft() }.buttonStyle(LBActionButtonStyle())
                            .buttonStyle(LBPrimaryButtonStyle())
                    }
                } else if soldiers.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Name, rank, unit, or team")
            .navigationTitle("Soldiers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Soldier", systemImage: "plus") { editor = SoldierDraft() }
                }
            }
        } detail: {
            NavigationStack {
                if let id = selection.wrappedValue,
                   let soldier = records.soldiers.first(where: { $0.id == id }) {
                    SoldierDetailView(soldier: soldier, store: store, records: records, scorer: scorer,
                                      onEdit: { editor = SoldierDraft(soldier) }, onDelete: { deleting = soldier },
                                      addTraining: { trainingSoldier = soldier }, addMeasurements: { measuringSoldier = soldier },
                                      preview: { attachment in
                                          previewOperation.start("Open Certificate") {
                                              _ = try await store.readAttachment(attachment)
                                              try Task.checkCancellation()
                                              previewURL = try store.attachmentURL(attachment)
                                          }
                                      })
                } else {
                    ContentUnavailableView("Select a Soldier", systemImage: "person.crop.rectangle",
                                           description: Text("Choose a soldier to see their record."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.lbBackground)
                }
            }
        }
        .sheet(item: $editor) { soldier in
            SoldierEditor(soldier: soldier, isNew: !records.soldiers.contains(where: { $0.id == soldier.id }), store: store) { updated, files in
                try await store.saveSoldier(updated, importing: files)
                selectedSoldier = updated.id.uuidString
            }
        }
        .sheet(item: $trainingSoldier) { soldier in
            TrainingRecordEditor(soldier: SoldierDraft(soldier)) { try await store.saveSoldier($0, importing: $1) }
        }
        .sheet(item: $measuringSoldier) { soldier in
            HeightWeightEditor(soldier: SoldierDraft(soldier)) { try await store.saveSoldier($0) }
        }
        .quickLookPreview($previewURL)
        .onDisappear { previewOperation.cancel() }
        .onChange(of: selectedSoldier) { previewOperation.cancel() }
        .alert(item: Binding(get: { previewOperation.phase.failure }, set: { if $0 == nil { previewOperation.dismissFailure() } })) { failure in
            Alert(title: Text("Certificate Unavailable"), message: Text(failure.localizedDescription), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog("Delete \(deleting?.displayName ?? "soldier")?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible, presenting: deleting) { soldier in
            Button("Delete Soldier and Results", role: .destructive) {
                store.submit("Delete Soldier") {
                    try await store.deleteSoldier(id: soldier.id)
                    selectedSoldier = ""
                }
                deleting = nil
            }.foregroundStyle(Color.lbDanger)
        } message: { _ in
            Text("This permanently removes this soldier’s record and linked fitness results from this device.")
        }
    }
}

struct SoldierDetailView: View {
    let soldier: Soldier
    let store: LeaderStore
    let records: BookSnapshot
    let scorer: AFTScoring
    let onEdit: () -> Void
    let onDelete: () -> Void
    let addTraining: () -> Void
    let addMeasurements: () -> Void
    let preview: (RecordAttachment) -> Void
    @ScaledMetric(relativeTo: .headline) private var insigniaWidth = 42
    @ScaledMetric(relativeTo: .headline) private var insigniaHeight = 52
    @ScaledMetric(relativeTo: .body) private var identitySpacing = 12

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    SoldierPortrait(attachment: soldier.photo, store: store, size: 88)
                    VStack(alignment: .leading, spacing: identitySpacing) {
                        Text(soldier.name).font(.title3.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("soldierHeaderName")
                        HStack(alignment: .center, spacing: 10) {
                            if soldier.rank != .pvt {
                                RankInsignia(rank: soldier.rank)
                                    .frame(width: insigniaWidth, height: insigniaHeight)
                            }
                            Text(soldier.rank.rawValue).font(.headline)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Rank, \(soldier.rank.rawValue)")
                        .accessibilityIdentifier("soldierHeaderRank")
                    }
                }.padding(.vertical, 4)
            }.leadersBookRow()
            Section("Assignment") {
                LabeledContent("Unit / Platoon", value: soldier.unit.isEmpty ? "Not Entered" : soldier.unit)
                LabeledContent("Team", value: soldier.team.isEmpty ? "Not Entered" : soldier.team)
            }.leadersBookRow()
            TrainingRecordSection(soldier: soldier, store: store, records: records, scorer: scorer,
                                  addTraining: addTraining, addMeasurements: addMeasurements, preview: preview)
            if !soldier.notes.isEmpty {
                Section("Leadership Notes") { Text(soldier.notes).textSelection(.enabled) }.leadersBookRow()
            }
            Section {
                Button("Delete Soldier", systemImage: "trash", role: .destructive, action: onDelete).foregroundStyle(Color.lbDanger)
            } footer: {
                Text("Updated \(soldier.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            }.leadersBookRow()
        }.leadersBookList()
        .navigationTitle(soldier.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit Soldier", systemImage: "pencil", action: onEdit)
            }
        }
    }
}

private struct RankInsignia: View {
    let rank: Rank
    var body: some View {
        if rank != .pvt {
            Image("Rank-\(rank.rawValue)").resizable().scaledToFit().accessibilityHidden(true)
        }
    }
}
