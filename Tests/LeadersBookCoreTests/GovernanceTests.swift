import Foundation
import Testing
@testable import LeadersBookCore

@MainActor
struct GovernanceTests {
    @Test func maliciousPersistenceIsRejectedAndPreserved() async throws {
        let scorer = try AFTScoring()
        let result = try scorer.result(for: maximumDraft(), soldierName: "Personal Result")
        var base = BookDTO(); base.results = [AFTResultDTO(result)]
        var invalidName = BookDTO(); invalidName.soldiers = [SoldierDTO()]
        var invalidAge = BookDTO(); invalidAge.fitnessDraft.ageBand = 999
        base.results[0].scores = [500]
        for (dto, expected) in [(invalidName, RecordError.invalidName), (invalidAge, .invalidAgeBand), (base, .invalidResult)] {
            let url = fixtureFile(); defer { cleanFixture(url) }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let bytes = try JSONEncoder().encode(dto); try bytes.write(to: url)
            let repository = BookRepository(fileURL: url, scorer: scorer)
            do { _ = try await repository.load(); Issue.record("Invalid persisted domain accepted") }
            catch let failure as AppFailure { #expect(failure.underlying as? RecordError == expected) }
            #expect(try Data(contentsOf: url) == bytes)
        }
    }
    @Test func incompleteAndMalformedInputHaveDistinctTypedErrors() {
        #expect(throws: FitnessInputError.missing(.run)) { try EventPerformance(event: .run, input: "") }
        #expect(throws: FitnessInputError.time(.run)) { try EventPerformance(event: .run, input: "bad") }
    }
    @Test func pendingTrainingCannotCarryCompletionData() throws {
        let draft = TrainingDraft(title: "Test", completed: false, completionDates: [.distantPast])
        #expect(throws: RecordError.inconsistentTraining) { try TrainingItem(draft: draft) }
        let legacy = try TrainingItem(draft: TrainingDraft(title: "Legacy", completed: true))
        #expect(legacy.completed && legacy.completionDates == nil)
    }
    @Test func staleEditorCannotOverwriteNewerRecord() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        try await store.saveSoldier(SoldierDraft(name: "Example"))
        var first = SoldierDraft(try #require((try store.records).soldiers.first)); var stale = first
        first.notes = "New notes"; try await store.saveSoldier(first)
        stale.notes = "Old window"
        await #expect(throws: RecordError.conflict) { try await store.saveSoldier(stale) }
        #expect((try store.records).soldiers.first?.notes == "New notes")
    }
    @Test func filesystemCausesRemainAvailableBehindPresentation() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let store = LeaderStore(fileURL: url, scorer: try AFTScoring(), authenticator: TestAuthenticator())
        let failure: AppFailure
        do { try await store.unlock(); Issue.record("Expected load failure"); return }
        catch let cause as AppFailure { failure = cause }
        guard case .locked = store.state else { Issue.record("Failed load exposed records"); return }
        #expect((failure.rootCause as NSError).domain == NSCocoaErrorDomain)
        #expect(!failure.localizedDescription.contains(url.path))
        let secondary = AppFailure("Cleanup", underlying: CocoaError(.fileWriteNoPermission))
        let compound = AppFailure("Compensate", underlying: failure, secondary: [secondary])
        #expect(compound.underlying is AppFailure)
        #expect(compound.secondary.count == 1)
    }
    @Test func cancelledAndReplacedOperationsCannotPublishStaleResults() async throws {
        let owner = OwnedOperation()
        var accepted = 0
        owner.start("Old Import") {
            try await Task.sleep(for: .seconds(1))
            try Task.checkCancellation()
            accepted = 1
        }
        owner.start("New Import") { accepted = 2 }
        try await Task.sleep(for: .milliseconds(30))
        #expect(accepted == 2)
        owner.start("Dismissed Import") {
            try await Task.sleep(for: .seconds(1))
            try Task.checkCancellation()
            accepted = 3
        }
        owner.cancel()
        try await Task.sleep(for: .milliseconds(30))
        #expect(accepted == 2)
        #expect(!owner.phase.isRunning)
        #expect(owner.phase.failure == nil)
    }
    @Test func cancelledProviderErrorRemainsDistinctFromFailure() async throws {
        let owner = OwnedOperation()
        owner.start("Cancelled File Selection") { throw CocoaError(.userCancelled) }
        try await Task.sleep(for: .milliseconds(30))
        guard case .cancelled(let context) = owner.phase else { Issue.record("Cancellation was misclassified"); return }
        let failure = try #require(context)
        #expect((failure.rootCause as NSError).code == CocoaError.Code.userCancelled.rawValue)
        #expect(owner.phase.failure == nil)
    }
    @Test func repeatedResultIntentCannotCreateDuplicateIdentity() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let repository = BookRepository(fileURL: url, scorer: try AFTScoring())
        _ = try await repository.load()
        let id = UUID(), input = maximumDraft()
        _ = try await repository.apply(.saveResult(input, id), permit: RecordAccessLease())
        await #expect(throws: RecordError.conflict) { try await repository.apply(.saveResult(input, id), permit: RecordAccessLease()) }
        let loaded = try await repository.load()
        #expect(loaded.snapshot.results.count == 1)
        #expect(loaded.snapshot.results.first?.id == id)
    }

    @Test func disappearingKnownDatasetCannotBeReplacedWithDefaults() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        try await store.saveSoldier(SoldierDraft(name: "Preserved in Memory"))
        try FileManager.default.removeItem(at: url)
        await #expect(throws: (any Error).self) { try await store.saveDraft(FitnessDraft()) }
        #expect((try store.records).soldiers.first?.name == "Preserved in Memory")
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func cancelledRecoveryRetainsThePreviousReadyState() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let repository = BookRepository(fileURL: url, scorer: try AFTScoring())
        let before = try await repository.load()
        let task = Task { try await repository.recoverPending() }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        guard case .ready(let after) = await repository.currentStatus() else { Issue.record("Cancellation discarded the ready state"); return }
        #expect(after.snapshot.generation == before.snapshot.generation)
    }

}
