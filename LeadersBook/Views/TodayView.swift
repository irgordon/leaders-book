import SwiftUI

struct TodayView: View {
    let store: LeaderStore
    let records: BookSnapshot
    let scorer: AFTScoring
    @Binding var selectedTab: Int
    @State private var confirmingReload = false

    private var retentionDue: Int { records.soldiers.filter { $0.requiresRetentionReview() }.count }
    private var overdue: Int { records.soldiers.reduce(0) { $0 + $1.overdueCount } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Prepared to Lead", systemImage: "book.closed.fill")
                            .font(.title2.bold())
                            .foregroundStyle(.tint)
                        Text("Your people. Your mission. Your standards.")
                            .foregroundStyle(Color.lbTextSecondary)
                    }
                    .padding(.vertical, 8)
                }.leadersBookRow()
                Section("Your Team") {
                    Button { selectedTab = 1 } label: {
                        LabeledContent("Soldiers", value: records.soldiers.count.formatted())
                    }.buttonStyle(LBActionButtonStyle())
                    Button { selectedTab = 1 } label: {
                        LBStatusLabel(text: overdue == 0 ? "No Overdue Training" : "\(overdue) Overdue Training Items", status: overdue == 0 ? .success : .failure)
                    }.buttonStyle(LBActionButtonStyle())
                }.leadersBookRow()
                if retentionDue > 0 {
                    Section("Retention Review") {
                        Button { selectedTab = 1 } label: {
                            LBStatusLabel(text: "\(retentionDue) Records Need Retention Review", status: .warning)
                        }
                        Text("Review records past one year since their last saved update, or with an unavailable retention date. Deletion always requires confirmation.").font(.caption)
                    }.leadersBookRow()
                }
                Section("Today’s Tools") {
                    Button { openFitness(.aft) } label: { Label("Score an AFT", systemImage: "figure.strengthtraining.traditional") }.buttonStyle(LBActionButtonStyle())
                    Button { openFitness(.ratio) } label: { Label("HT/WT Calculator", systemImage: "ruler") }.buttonStyle(LBActionButtonStyle())
                    NavigationLink { TroopLeadingView() } label: { Label("Troop Leading Procedures", systemImage: "flag") }
                    Button { selectedTab = 2 } label: { Label("Army Guides", systemImage: "books.vertical") }.buttonStyle(LBActionButtonStyle())
                    NavigationLink { ResourcesView() } label: { Label("Army Resources", systemImage: "link") }
                }.leadersBookRow()
                if let latest = records.results.first {
                    Section("Last Saved AFT") {
                        NavigationLink {
                            AFTResultView(result: latest, ageBands: scorer.tables.ageBands)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(latest.displayName).font(.headline)
                                Text("\(latest.total) / 500 · \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                                    .foregroundStyle(Color.lbTextSecondary)
                            }
                        }
                    }.leadersBookRow()
                }
                Section {
                    Text("Saved in this app’s storage. System backups may include these records. No account or network is needed for records, guides, or calculators.")
                        .font(.footnote)
                        .foregroundStyle(Color.lbTextSecondary)
                    NavigationLink("Privacy and Data Controls") { DataPolicyView() }
                }.leadersBookRow()
            }.leadersBookList()
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reload Records", systemImage: "arrow.clockwise") { confirmingReload = true }
                }
            }
            .confirmationDialog("Reload Records?", isPresented: $confirmingReload, titleVisibility: .visible) {
                Button("Reload Records") { store.submit("Reload Records") { await store.reload() } }.buttonStyle(LBActionButtonStyle())
            } message: { Text("Reloading discards unsaved edits and loads the saved records file.") }
        }
    }

    private func openFitness(_ tool: FitnessTool) {
        var draft = store.draft
        draft.tool = tool
        store.updateDraft(draft)
        selectedTab = 3
    }
}
