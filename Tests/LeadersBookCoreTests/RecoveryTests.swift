import Foundation
import Testing
@testable import LeadersBookCore

struct RecoveryTests {
    /// A persisted journal is a real interrupted transaction fixture, not a mocked storage boundary.
    private func journal(at url: URL, id: UUID, new: [RecordAttachment], removed: [RecordAttachment]) throws {
        struct JournalFixture: Encodable { let id: UUID; let newFiles: [AttachmentDTO]; let removedFiles: [AttachmentDTO] }
        let fixture = JournalFixture(id: id, newFiles: new.map(AttachmentDTO.init), removedFiles: removed.map(AttachmentDTO.init))
        try JSONEncoder().encode(fixture).write(to: url.deletingLastPathComponent().appending(path: "pending-transaction.json"))
    }
    @Test func restartRollsBackUncommittedImportsIdempotently() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let scorer = try AFTScoring(), photo = try RecordAttachment(name: "Interrupted.jpg", kind: .jpeg)
        let repository = BookRepository(fileURL: url, scorer: scorer)
        let destination = repository.attachmentURL(photo)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try jpegFixture.write(to: destination)
        try journal(at: url, id: UUID(), new: [photo], removed: [])
        let loaded = try await repository.load()
        #expect(loaded.snapshot.soldiers.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        _ = try await repository.recoverPending()
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appending(path: "pending-transaction.json").path))
    }
    @Test func failedCleanupRetainsCauseAndCanBeRecoveredAfterRestart() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let photo = try RecordAttachment(name: "Removed.jpg", kind: .jpeg)
        let scorer = try AFTScoring(), transaction = UUID()
        let repository = BookRepository(fileURL: url, scorer: scorer)
        let destination = repository.attachmentURL(photo), directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jpegFixture.write(to: destination)
        var dto = BookDTO(); dto.lastTransaction = transaction
        let original = try JSONEncoder().encode(dto); try original.write(to: url)
        try journal(at: url, id: transaction, new: [], removed: [photo])
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer {
            do { try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
            catch { Issue.record(error) }
        }
        let loaded = try await repository.load()
        guard case .pending(let issue) = loaded.cleanup else { Issue.record("Cleanup failure was suppressed"); return }
        #expect(!issue.failures.isEmpty)
        #expect((try #require(issue.failures.first).underlying as NSError).domain == NSCocoaErrorDomain)
        #expect(FileManager.default.fileExists(atPath: destination.path))
        #expect(try Data(contentsOf: url) == original)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let restarted = BookRepository(fileURL: url, scorer: scorer)
        let recovered = try await restarted.load()
        guard case .clean = recovered.cleanup else { Issue.record("Recovery did not finish"); return }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try Data(contentsOf: url) == original)
        _ = try await restarted.recoverPending()
    }
    @Test func journalCannotRemoveAnAttachmentReferencedByCommittedRecords() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let scorer = try AFTScoring(), repository = BookRepository(fileURL: url, scorer: try AFTScoring())
        _ = try await repository.load()
        let photo = try RecordAttachment(name: "Referenced.jpg", kind: .jpeg)
        var draft = SoldierDraft(name: "Example"); draft.photo = photo
        _ = try await repository.apply(.saveSoldier(try Soldier(draft: draft), expectedRevision: draft.revision, [try ImportedRecordFile(attachment: photo, data: jpegFixture)]), permit: RecordAccessLease())
        try journal(at: url, id: UUID(), new: [photo], removed: [])
        let fresh = BookRepository(fileURL: url, scorer: scorer)
        await #expect(throws: AppFailure.self) { try await fresh.load() }
        #expect(FileManager.default.fileExists(atPath: repository.attachmentURL(photo).path))
    }
}
