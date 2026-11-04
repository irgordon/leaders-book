import SwiftUI

struct TrainingRecordSection: View {
    let soldier: Soldier
    let store: LeaderStore
    let records: BookSnapshot
    let scorer: AFTScoring
    let addTraining: () -> Void
    let addMeasurements: () -> Void
    let preview: (RecordAttachment) -> Void

    private var latestAFT: AFTResult? {
        records.results.filter { $0.soldierID == soldier.id }.max { $0.date < $1.date }
    }
    private var measurements: [HeightWeightRecord] { (soldier.heightWeight ?? []).sorted { $0.date > $1.date } }
    private var completed: [TrainingItem] {
        soldier.training.filter(\.completed).sorted {
            ($0.completionDates?.max() ?? .distantPast) > ($1.completionDates?.max() ?? .distantPast)
        }
    }

    var body: some View {
        Section("Training Record") {
            if let result = latestAFT {
                NavigationLink { AFTResultView(result: result, ageBands: scorer.tables.ageBands) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Current AFT Score", value: "\(result.total) / 500")
                            .accessibilityIdentifier("currentSoldierAFT")
                        LBStatusLabel(text: result.meetsStandard ? "Meets Standard" : "Does Not Meet Standard", status: result.meetsStandard ? .success : .failure).font(.caption)
                        Text(result.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(Color.lbTextSecondary)
                    }
                }
            } else { LabeledContent("Current AFT Score", value: "Not Recorded") }
            if let current = measurements.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current HT/WT Record").font(.headline)
                    Text("\(current.heightInches.formatted(.number.precision(.fractionLength(1)))) in · \(current.weightPounds.formatted(.number.precision(.fractionLength(1)))) lb")
                    Text(current.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(Color.lbTextSecondary)
                }
                NavigationLink("HT/WT History") {
                    List(measurements) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                            Text("\(record.heightInches.formatted()) in · \(record.weightPounds.formatted()) lb")
                        }.leadersBookRow()
                    }.leadersBookList().navigationTitle("HT/WT History")
                }
            } else { LabeledContent("Current HT/WT Record", value: "Not Recorded") }
            Button("Add HT/WT Record", systemImage: "ruler", action: addMeasurements).buttonStyle(LBActionButtonStyle())
        }.leadersBookRow()
        Section {
            if completed.isEmpty { Text("No Completed Training Recorded").foregroundStyle(Color.lbTextSecondary) }
            ForEach(Array(completed.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 6) {
                    LBStatusLabel(text: item.title, status: .success).font(.headline)
                    if let dates = item.completionDates, !dates.isEmpty {
                        ForEach(dates.sorted(), id: \.self) { date in
                            Text(date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
                        }
                    } else {
                        Text("Completion Date Not Recorded").font(.caption).foregroundStyle(Color.lbTextSecondary)
                    }
                    if let attachment = item.certificate {
                        Button { preview(attachment) } label: { Label("View Certificate", systemImage: "doc.badge.checkmark") }.buttonStyle(LBActionButtonStyle())
                            .buttonStyle(.borderless)
                            .accessibilityHint("Preview Certificate of Completion")
                        Text(attachment.name).font(.caption).foregroundStyle(Color.lbTextSecondary)
                    } else { Text("No Certificate Attached").font(.caption).foregroundStyle(Color.lbTextSecondary) }
                }
                .padding(.vertical, 4)
                .leadersBookRow(alternating: !index.isMultiple(of: 2))
            }
            Button("Add Training Record", systemImage: "plus", action: addTraining).buttonStyle(LBActionButtonStyle())
                .accessibilityIdentifier("addTrainingRecord")
        } header: { Text("Completed Training") } footer: {
            Text("Personal training record organized around AR 350-1. Verify unit requirements and maintain official records in your approved Army training system.")
        }.leadersBookRow()
        if soldier.training.contains(where: { !$0.completed }) {
            Section("Pending Training") {
                ForEach(soldier.training.filter { !$0.completed }) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                        if let dueDate = item.dueDate {
                            LBStatusLabel(text: (item.isOverdue() ? "Overdue — Due " : "Pending — Due ") + dueDate.formatted(date: .abbreviated, time: .omitted),
                                          status: item.isOverdue() ? .failure : .warning).font(.caption)
                        } else { LBStatusLabel(text: "Pending — No Due Date", status: .warning).font(.caption) }
                    }
                }
            }.leadersBookRow()
        }
    }
}
