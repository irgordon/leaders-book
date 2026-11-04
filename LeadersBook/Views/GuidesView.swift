import SwiftUI

struct GuidesView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var query = ""
    @State private var selection: String?

    private var matches: [ArmyGuide] {
        ReferenceContent.guides.filter {
            query.isEmpty || "\($0.id) \($0.title) \($0.paragraphs.joined(separator: " "))".localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Army Guides") {
                    ForEach(matches) { guide in
                        NavigationLink(value: guide.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(guide.title)
                                Text(guide.id).font(.caption).foregroundStyle(Color.theme(sizeClass == .regular && selection == guide.id ? .textOnSelected : .textSecondary))
                            }
                        }.leadersBookRow(selected: sizeClass == .regular && selection == guide.id)
                    }
                }.leadersBookRow()
                if query.isEmpty {
                    Section("In the Field") {
                        NavigationLink(value: "troop-leading") { Label("Troop Leading", systemImage: "flag") }
                            .leadersBookRow(selected: sizeClass == .regular && selection == "troop-leading")
                        NavigationLink(value: "resources") { Label("Army Resources", systemImage: "link") }
                            .leadersBookRow(selected: sizeClass == .regular && selection == "resources")
                    }.leadersBookRow()
                }
            }.leadersBookList()
            .overlay {
                if !query.isEmpty && matches.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, prompt: "Search guide text")
            .navigationTitle("Guides")
        } detail: {
            NavigationStack {
                if selection == "troop-leading" {
                    TroopLeadingView()
                } else if selection == "resources" {
                    ResourcesView()
                } else if let guide = ReferenceContent.guides.first(where: { $0.id == selection }) {
                    GuideDetailView(guide: guide)
                } else {
                    ContentUnavailableView("Your Field Reference", systemImage: "books.vertical",
                                           description: Text("Choose a guide, troop leading procedures, or Army resources."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.lbBackground)
                }
            }
        }
    }
}

private struct GuideDetailView: View {
    let guide: ArmyGuide

    var body: some View {
        List {
            Section(guide.id) {
                ForEach(guide.paragraphs, id: \.self) { Text($0).textSelection(.enabled) }
            }.leadersBookRow()
            Section("Put It Into Practice") { Text(guide.practice) }.leadersBookRow()
            Section {
                Link("Find \(guide.id) at Army Publishing", destination: ReferenceContent.publishingURL).buttonStyle(LBActionButtonStyle())
            } footer: {
                Text("Study summary, not a quotation or substitute for current doctrine. Verify the latest edition at Army Publishing.")
            }.leadersBookRow()
        }.leadersBookList()
        .navigationTitle(guide.title)
    }
}

struct TroopLeadingView: View {
    var body: some View {
        List {
            Section {
                Text("A continuous process: steps may overlap or repeat as information changes.")
                    .foregroundStyle(Color.lbTextSecondary)
            }.leadersBookRow()
            Section("Eight Steps") {
                ForEach(ReferenceContent.troopSteps) { step in
                    NavigationLink {
                        List {
                            Section("Step \(step.id)") { Text(step.summary) }.leadersBookRow()
                            Section("Leader Action") { Text(step.action) }.leadersBookRow()
                        }.leadersBookList()
                        .navigationTitle(step.title)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label { Text(step.title) } icon: { Text(step.id.formatted()).monospacedDigit() }
                    }
                }
            }.leadersBookRow()
            Section {
                Link("Find FM 5-0 at Army Publishing", destination: ReferenceContent.publishingURL).buttonStyle(LBActionButtonStyle())
            } footer: {
                Text("Study summary. Consult current FM 5-0 and unit procedures for planning requirements.")
            }.leadersBookRow()
        }.leadersBookList()
        .navigationTitle("Troop Leading")
    }
}

struct ResourcesView: View {
    var body: some View {
        List {
            Section {
                ForEach(ReferenceContent.resources) { resource in
                    Link(destination: resource.url) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(resource.id)
                                Text(resource.subtitle).font(.caption).foregroundStyle(Color.lbTextSecondary)
                            }
                        } icon: { Image(systemName: resource.symbol) }
                    }.buttonStyle(LBActionButtonStyle())
                    .accessibilityHint("Opens the official website in your browser")
                }
            } footer: {
                Text("External services require internet access and may require a CAC or an approved device. This app does not sign in to Army systems.")
            }.leadersBookRow()
        }.leadersBookList()
        .navigationTitle("Army Resources")
    }
}
