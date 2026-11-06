import SwiftUI

struct LockedRecordsView: View {
    let store: LeaderStore
    let summary: LockedSummary?
    @State private var unlock = OwnedOperation()
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield").font(.largeTitle).accessibilityHidden(true)
                Text("Records Locked").font(.title.bold())
                if let summary {
                    Text("Last Unlocked Summary").font(.caption).foregroundStyle(Color.lbTextSecondary)
                    Text("\(summary.soldiers) Soldiers · \(summary.results) Saved AFT Results")
                        .accessibilityIdentifier("lockedSummary")
                } else { Text("Unlock to load the summary.").foregroundStyle(Color.lbTextSecondary) }
                Text("Authenticate with device biometrics or your device passcode to view soldier details.")
                    .multilineTextAlignment(.center)
                Button("Unlock Records", systemImage: "lock.open") {
                    unlock.start("Unlock Records") { try await store.unlock() }
                }.buttonStyle(LBPrimaryButtonStyle())
                    .disabled(store.isAuthenticating).accessibilityIdentifier("unlockRecords")
                if store.isAuthenticating { ProgressView("Authenticating…") }
                NavigationLink("Privacy and Data Controls") { DataPolicyView() }
            }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.lbBackground)
                .navigationTitle("The Leaders Book")
        }
        .onDisappear { unlock.cancel() }
    }
}
