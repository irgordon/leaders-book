import SwiftUI

@MainActor
private struct AppSession {
    let scorer: AFTScoring
    let store: LeaderStore
    init() throws {
        scorer = try AFTScoring()
        #if AUTHENTICATION_TEST_DOUBLE
        store = LeaderStore(scorer: scorer, authenticator: UITestAuthenticator())
        #else
        store = LeaderStore(scorer: scorer, authenticator: DeviceAuthenticator())
        #endif
    }
}

@main
struct LeadersBookApp: App {
    @State private var session = Result { try AppSession() }
    var body: some Scene {
        WindowGroup {
            Group {
            switch session {
            case .success(let session): ContentView(store: session.store, scorer: session.scorer)
            case .failure(let cause):
                ContentUnavailableView("Scoring Tables Unavailable", systemImage: "exclamationmark.triangle",
                                       description: Text("The bundled scoring tables could not be opened. Update or reinstall the app to restore them."))
                    .accessibilityHint(AppFailure("Load Scoring Tables", underlying: cause).localizedDescription)
                    
            }
            }.leadersBookTheme()
            #if DEBUG
            .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--preview-dark") ? .dark :
                                  ProcessInfo.processInfo.arguments.contains("--preview-light") ? .light : nil)
            #endif
        }
    }
}
