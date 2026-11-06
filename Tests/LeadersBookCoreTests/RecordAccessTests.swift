import Foundation
import Testing
@testable import LeadersBookCore

@MainActor
private final class DeferredAuthenticator: RecordAuthenticating {
    var continuation: CheckedContinuation<Void, Error>?
    var cancelled = false
    func authenticate() async throws {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func cancel() { cancelled = true }
}

@MainActor private final class ExportAuthenticator: RecordAuthenticating {
    var exports = 0
    var denied = false
    var hold = false
    var continuation: CheckedContinuation<Void, Error>?
    func authenticate() async throws {}
    func authenticateForExport() async throws {
        exports += 1
        if denied { throw RecordAccessError.cancelled }
        if hold { try await withCheckedThrowingContinuation { continuation = $0 } }
    }
    func cancel() {}
}

@MainActor
struct RecordAccessTests {
    @Test func exportsRequireFreshAuthenticationAndRejectLateCompletion() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let auth = ExportAuthenticator()
        let store = LeaderStore(fileURL: url, scorer: try AFTScoring(), authenticator: auth)
        try await store.unlock()
        let file = try RecordAttachment(name: "Certificate.pdf", kind: .pdf)
        var soldier = SoldierDraft(name: "Export Test")
        soldier.notes = "Private notes"
        soldier.training = [TrainingDraft(title: "Course", completed: true, completionDates: [.now], certificate: file)]
        try await store.saveSoldier(soldier, importing: [try ImportedRecordFile(attachment: file, data: pdfFixture)])
        #expect(try await store.exportNotes(soldierID: soldier.id).data == Data("Private notes".utf8))
        #expect(auth.exports == 1)
        #expect(try await store.exportCertificate(file).data == pdfFixture)
        #expect(auth.exports == 2)
        auth.denied = true
        await #expect(throws: RecordAccessError.cancelled) { try await store.exportCertificate(file) }
        auth.denied = false; auth.hold = true
        let task = Task { try await store.exportNotes(soldierID: soldier.id) }
        defer { task.cancel(); auth.continuation?.resume(throwing: CancellationError()); auth.continuation = nil }
        for _ in 0..<100 where auth.continuation == nil { await Task.yield() }
        let continuation = try #require(auth.continuation); auth.continuation = nil
        store.lock(); continuation.resume()
        await #expect(throws: RecordAccessError.locked) { try await task.value }
        #expect(!store.isUnlocked)
    }

    @Test func retentionUsesOneCalendarYearWithoutDeleting() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var draft = SoldierDraft(name: "Retention Test")
        draft.updatedAt = try #require(calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)))
        let soldier = try Soldier(draft: draft)
        let before = try #require(calendar.date(from: DateComponents(year: 2024, month: 12, day: 31)))
        let anniversary = try #require(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        #expect(!soldier.requiresRetentionReview(on: before, calendar: calendar))
        #expect(soldier.requiresRetentionReview(on: anniversary, calendar: calendar))
        #expect(soldier.name == "Retention Test")
        #expect(!soldier.committedVersion().requiresRetentionReview())
        draft.updatedAt = Date(timeIntervalSinceReferenceDate: Double.greatestFiniteMagnitude)
        #expect(try Soldier(draft: draft).retentionReview(on: anniversary, calendar: calendar) == .dateUnavailable)
    }

    @Test func unavailableAuthenticationFailsClosed() async throws {
        let store = LeaderStore(fileURL: fixtureFile(), scorer: try AFTScoring())
        await #expect(throws: RecordAccessError.unavailable) { try await store.unlock() }
        #expect(!store.isUnlocked)
        let failure = try #require(store.operationFailure)
        #expect(failure.operation == "Unlock Records")
        #expect(failure.underlying as? RecordAccessError == .unavailable)
        guard case .locked = store.state else { Issue.record("Denied authentication changed lock state"); return }
        #expect(throws: RecordAccessError.locked) { try store.records }
    }

    @Test func lockedReloadDoesNotReadOrRecoverPrivateFiles() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let root = Data("Private malformed records".utf8), journal = Data("Pending private journal".utf8)
        let journalURL = url.deletingLastPathComponent().appending(path: "pending-transaction.json")
        try root.write(to: url); try journal.write(to: journalURL)
        let store = LeaderStore(fileURL: url, scorer: try AFTScoring())
        await store.reload()
        #expect(store.operationFailure?.rootCause as? RecordAccessError == .locked)
        guard case .locked(nil) = store.state else { Issue.record("Cold locked state exposed a summary"); return }
        #expect(try Data(contentsOf: url) == root)
        #expect(try Data(contentsOf: journalURL) == journal)
        await #expect(throws: RecordAccessError.unavailable) { try await store.unlock() }
        #expect(try Data(contentsOf: journalURL) == journal)
    }

    @Test func archiveConfigurationExcludesTestAuthentication() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let scheme = try String(contentsOf: root.appending(path: "LeadersBook.xcodeproj/xcshareddata/xcschemes/LeadersBook.xcscheme"), encoding: .utf8)
        #expect(scheme.contains("<ArchiveAction buildConfiguration=\"Release\""))
    }

    @Test func lockedRoutesRejectAccessAndPreserveRecords() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        let attachment = try RecordAttachment(name: "Private.jpg", kind: .jpeg)
        var soldier = SoldierDraft(name: "Private Identity")
        soldier.photo = attachment
        try await store.saveSoldier(soldier, importing: [try ImportedRecordFile(attachment: attachment, data: jpegFixture)])
        let before = try Data(contentsOf: url)
        store.lock()
        guard case .locked(let summary) = store.state else { Issue.record("Expected locked summary"); return }
        #expect(summary == LockedSummary(soldiers: 1, results: 0))
        #expect(throws: RecordAccessError.locked) { try store.records }
        #expect(throws: RecordAccessError.locked) { try store.attachmentURL(attachment) }
        await #expect(throws: RecordAccessError.locked) { try await store.readAttachment(attachment) }
        await #expect(throws: RecordAccessError.locked) { try await store.saveSoldier(soldier) }
        await #expect(throws: RecordAccessError.locked) { try await store.deleteSoldier(id: soldier.id) }
        await #expect(throws: RecordAccessError.locked) { try await store.saveDraft(maximumDraft()) }
        await #expect(throws: RecordAccessError.locked) { try await store.saveResult() }
        await #expect(throws: RecordAccessError.locked) { try await store.deleteResults(ids: []) }
        await #expect(throws: RecordAccessError.locked) { try await store.recoverAttachments() }
        store.updateDraft(maximumDraft())
        #expect(store.draft.values.isEmpty)
        await store.reload()
        guard case .locked = store.state else { Issue.record("Reload bypassed authentication"); return }
        #expect(try Data(contentsOf: url) == before)
        try await store.unlock()
        #expect((try store.records).soldiers.first?.name == "Private Identity")
        #expect(try Data(contentsOf: url) == before)
    }

    @Test func staleAuthenticationCannotUnlockAfterLock() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let authenticator = DeferredAuthenticator()
        let store = LeaderStore(fileURL: url, scorer: try AFTScoring(), authenticator: authenticator)
        let task = Task { try await store.unlock() }
        defer {
            task.cancel()
            if let pending = authenticator.continuation {
                authenticator.continuation = nil
                pending.resume(throwing: CancellationError())
            }
        }
        for _ in 0..<100 where authenticator.continuation == nil { await Task.yield() }
        let completion = try #require(authenticator.continuation)
        store.lock()
        authenticator.continuation = nil
        completion.resume()
        await #expect(throws: RecordAccessError.superseded) { try await task.value }
        #expect(authenticator.cancelled)
        #expect(!store.isUnlocked)
    }

    @Test func revokedLeasePreventsQueuedStorageAccess() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let repository = BookRepository(fileURL: url, scorer: try AFTScoring())
        _ = try await repository.load()
        let lease = RecordAccessLease()
        lease.revoke()
        let soldier = try Soldier(draft: SoldierDraft(name: "Blocked"))
        await #expect(throws: RecordAccessError.locked) {
            try await repository.apply(.saveSoldier(soldier, expectedRevision: nil, []), permit: lease)
        }
        let attachment = try RecordAttachment(name: "Blocked.jpg", kind: .jpeg)
        await #expect(throws: RecordAccessError.locked) { try await repository.readAttachment(attachment, permit: lease) }
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
