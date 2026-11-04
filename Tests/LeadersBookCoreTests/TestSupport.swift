import Foundation
import Testing
@testable import LeadersBookCore

func fixtureFile() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "LeadersBookTests-\(UUID())/records.json")
}
func cleanFixture(_ url: URL) {
    do { try FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile { return }
    catch { Issue.record(error) }
}
@MainActor func openStore(_ url: URL) async throws -> LeaderStore {
    let store = LeaderStore(fileURL: url, scorer: try AFTScoring(), authenticator: TestAuthenticator())
    try await store.unlock()
    if case .failed(let failure) = store.state { throw failure }
    return store
}
func maximumDraft() -> FitnessDraft {
    var value = FitnessDraft()
    value.values = ["mdl": "340", "hrp": "58", "sdc": "1:00", "plk": "5:00", "run": "10:00"]
    return value
}
let jpegFixture = Data([255, 216, 255, 224, 0, 16])
let pdfFixture = Data("%PDF-1.4 fixture for opaque storage testing".utf8)

@MainActor struct TestAuthenticator: RecordAuthenticating {
    func authenticate() async throws {}
    func cancel() {}
}
