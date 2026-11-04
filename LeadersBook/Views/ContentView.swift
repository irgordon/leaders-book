import SwiftUI

struct ContentView: View {
    @Bindable var store: LeaderStore
    let scorer: AFTScoring
    @SceneStorage("selectedTab") private var selectedTab = 0
    @State private var recoveryOperation = OwnedOperation()
    @Environment(\.scenePhase) private var scenePhase

    enum PresentedFailure: Identifiable {
        case operation(AppFailure), draft(AppFailure)
        var id: UUID { failure.id }
        var failure: AppFailure { switch self { case .operation(let value), .draft(let value): value } }
        var title: String {
            switch self {
            case .draft: "Draft Not Saved"
            case .operation(let failure): failure.operation == "Unlock Records" ? "Records Remain Locked" : failure.operation + " Couldn’t Finish"
            }
        }
    }
    var presentedFailure: Binding<PresentedFailure?> {
        Binding(get: {
            if let failure = store.operationFailure { return .operation(failure) }
            return store.draftSave.phase.failure.map(PresentedFailure.draft)
        }, set: { value in
            guard value == nil else { return }
            if store.operationFailure != nil { store.operationFailure = nil }
            else { store.draftSave.dismissFailure() }
        })
    }

    var body: some View {
        Group {
            switch store.state {
            case .locked(let summary): LockedRecordsView(store: store, summary: summary)
            case .loading:
                ProgressView("Opening Records…")
            case .failed(let error):
                ContentUnavailableView {
                    Label("Records Couldn’t Be Opened", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your stored file has been preserved. \(error.localizedDescription)")
                } actions: {
                    Button("Try Again") { store.submit("Reload Records") { await store.reload() } }.buttonStyle(LBActionButtonStyle())
                        .buttonStyle(LBPrimaryButtonStyle())
                }
            case .ready(let book):
                TabView(selection: $selectedTab) {
                    Tab("Today", systemImage: "sun.max", value: 0) {
                        TodayView(store: store, records: book.snapshot, scorer: scorer, selectedTab: $selectedTab)
                    }
                    Tab("Soldiers", systemImage: "person.2", value: 1) {
                        SoldiersView(store: store, records: book.snapshot, scorer: scorer)
                    }
                    Tab("Guides", systemImage: "books.vertical", value: 2) {
                        GuidesView()
                    }
                    Tab("Fitness", systemImage: "figure.strengthtraining.traditional", value: 3) {
                        FitnessView(store: store, records: book.snapshot, scorer: scorer)
                    }
                }
            }
        }
         .task {
            await store.prepareForPresentation()
            #if AUTHENTICATION_TEST_DOUBLE
            if ProcessInfo.processInfo.arguments.contains("--authentication-test-simultaneous-errors") {
                store.draftSave.start("Test Draft") { throw CocoaError(.fileWriteNoPermission) }
                store.operationFailure = AppFailure("Unlock Records", underlying: RecordAccessError.cancelled)
            }
            #endif
        }
        .background(PrivacyShield(locked: !store.isUnlocked, active: scenePhase == .active))
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in store.lock() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in store.lock() }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
            if case .ready = store.state {
                Button("Lock Records", systemImage: "lock") { store.lock() }
                    .buttonStyle(LBActionButtonStyle()).padding(8).accessibilityIdentifier("lockRecords")
            }
            if let warning = store.storageWarning {
                Button("Changes Saved With a Storage Warning") { store.operationFailure = warning }.buttonStyle(LBActionButtonStyle())
                    .padding().frame(maxWidth: .infinity).background(Color.lbSurfaceRaised)
            }
            if let issue = store.cleanupIssue {
                VStack {
                    Label("Attachment Cleanup Pending", systemImage: "exclamationmark.triangle")
                    Text("Records are saved. Resolve cleanup before making more changes.").font(.caption)
                    Button("Retry Cleanup") {
                        recoveryOperation.start("Recover Attachments") { try await store.recoverAttachments() }
                    }.disabled(recoveryOperation.phase.isRunning).buttonStyle(LBActionButtonStyle())
                }.padding().frame(maxWidth: .infinity).background(Color.lbSurfaceRaised)
                .accessibilityIdentifier(issue.transaction.uuidString)
            }
        }
        }
        .onDisappear { recoveryOperation.cancel() }
        .privacySensitive(store.isUnlocked)
        .overlay {
            if scenePhase != .active {
                ZStack {
                    Color.theme(.privacyCover).ignoresSafeArea()
                    Label("The Leaders Book", systemImage: "book.closed")
                        .font(.title2.bold())
                        .foregroundStyle(Color.theme(.textOnPrivacyCover))
                }
                .accessibilityHidden(true)
            }
        }
        .alert(item: presentedFailure) { presented in
            Alert(title: Text(presented.title), message: Text(presented.failure.localizedDescription), dismissButton: .default(Text("OK")))
        }
    }
}
