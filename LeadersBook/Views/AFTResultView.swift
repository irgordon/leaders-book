import SwiftUI

struct AFTResultView: View {
    let result: AFTResult
    let ageBands: [String]

    var body: some View {
        List {
            Section {
                Text("\(result.total) / 500").font(.largeTitle.bold().monospacedDigit())
                    .accessibilityIdentifier("savedAFTTotal")
                AFTStatusSummary(result: result)
            }.leadersBookRow()
            Section("Test Profile") {
                LabeledContent("Soldier", value: result.displayName)
                LabeledContent("Date", value: result.date.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Standard", value: result.standard.title)
                LabeledContent("Age band", value: ageBands[result.ageBand])
            }.leadersBookRow()
            Section("Event Results") {
                ForEach(Array(AFTEvent.allCases.enumerated()), id: \.element) { index, event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title).font(.headline)
                        Text("\(result.values[event.rawValue, default: "—"]) · \(event.unit)")
                            .foregroundStyle(Color.lbTextSecondary)
                        LBStatusLabel(text: "\(result.scores[index])/100 — " + (result.points(for: event).meetsMinimum ? "Go" : "No Go"),
                                      status: result.points(for: event).meetsMinimum ? .success : .failure).monospacedDigit()
                    }
                }
            }.leadersBookRow()
            Section {
                Text("Scoring table effective \(result.tableDate). This saved calculation does not replace an official Army scorecard.")
                    .font(.footnote).foregroundStyle(Color.lbTextSecondary)
            }.leadersBookRow()
        }.leadersBookList()
        .navigationTitle("AFT Result")
        .navigationBarTitleDisplayMode(.inline)
    }
}
