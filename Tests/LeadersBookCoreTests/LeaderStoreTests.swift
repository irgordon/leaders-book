import Foundation
import Testing
@testable import LeadersBookCore

@MainActor
struct LeaderStoreTests {
    @Test func soldierDraftAndHistorySurviveRelaunch() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        var soldier = SoldierDraft(name: "  Taylor Example  ")
        soldier.rank = .sgt; soldier.unit = "1st Platoon"
        soldier.training = [TrainingDraft(title: "Unit training", tracksDueDate: true)]
        try await store.saveSoldier(soldier)
        var draft = maximumDraft(); draft.soldierID = soldier.id; draft.height = "70"; draft.waist = "35"; draft.tool = .ratio
        try await store.saveDraft(draft)
        // The UI draft is independent of persisted records; pass its actual latest values on save.
        store.updateDraft(draft)
        try await store.saveResult()
        let reloaded = try await openStore(url)
        #expect((try reloaded.records).soldiers == (try store.records).soldiers)
        #expect((try reloaded.records).fitnessDraft == (try store.records).fitnessDraft)
        #expect((try reloaded.records).results == (try store.records).results)
        #expect((try reloaded.records).soldiers.first?.name == "Taylor Example")
        #expect((try reloaded.records).results.first?.total == 500)
        #expect((try reloaded.records).fitnessDraft.tool == .history)
        soldier = SoldierDraft(try #require((try reloaded.records).soldiers.first)); soldier.name = "Taylor Updated"
        try await reloaded.saveSoldier(soldier)
        let after = try await openStore(url)
        #expect((try after.records).soldiers.count == 1)
        #expect((try after.records).soldiers.first?.name == "Taylor Updated")
    }
    @Test func deletionRemovesLinkedResultsAndDraftAssignmentOnly() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        let soldier = SoldierDraft(name: "Example")
        try await store.saveSoldier(soldier)
        var draft = maximumDraft()
        store.updateDraft(draft); try await store.saveResult()
        draft.soldierID = soldier.id
        store.updateDraft(draft); try await store.saveResult()
        try await store.deleteSoldier(id: soldier.id)
        let reloaded = try await openStore(url)
        #expect((try reloaded.records).soldiers.isEmpty)
        #expect((try reloaded.records).results.count == 1)
        #expect((try reloaded.records).results.first?.soldierID == nil)
        #expect((try reloaded.records).fitnessDraft.soldierID == nil)
        #expect((try reloaded.records).fitnessDraft.values == draft.values)
        try await reloaded.deleteResults(ids: Set((try reloaded.records).results.map(\.id)))
        let after = try await openStore(url)
        #expect((try after.records).results.isEmpty)
    }
    @Test func corruptOrNewerFileIsNeverOverwritten() async throws {
        var newer = BookDTO(); newer.version = 99
        for data in [Data("not valid JSON".utf8), try JSONEncoder().encode(newer)] {
            let url = fixtureFile(); defer { cleanFixture(url) }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            let store = LeaderStore(fileURL: url, scorer: try AFTScoring(), authenticator: TestAuthenticator())
            await #expect(throws: AppFailure.self) { try await store.unlock() }
            guard case .locked = store.state else { Issue.record("Invalid data unlocked records"); continue }
            await #expect(throws: RecordAccessError.locked) { try await store.saveSoldier(SoldierDraft(name: "Example")) }
            #expect(try Data(contentsOf: url) == data)
        }
    }
    @Test func invalidRecordsAndFailedWritesDoNotChangeMemory() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        await #expect(throws: RecordError.invalidName) { try await store.saveSoldier(SoldierDraft(name: "  ")) }
        await #expect(throws: RecordError.invalidTraining) {
            try await store.saveSoldier(SoldierDraft(name: "Example", training: [TrainingDraft()]))
        }
        try await store.saveSoldier(SoldierDraft(name: "Saved"))
        let before = (try store.records).soldiers
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        await #expect(throws: (any Error).self) { try await store.saveSoldier(SoldierDraft(name: "Unsaved")) }
        #expect((try store.records).soldiers == before)
    }
    @Test func missingSoldierAndIncompleteScoresCannotSave() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        await #expect(throws: FitnessInputError.missing(.mdl)) { try await store.saveResult() }
        var draft = maximumDraft(); draft.soldierID = UUID()
        await #expect(throws: RecordError.missingSoldier) { try await store.saveDraft(draft) }
        #expect((try store.records).results.isEmpty)
    }
    @Test func trainingDueDatesUseCalendarDays() throws {
        let now = Date()
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: now))
        var draft = TrainingDraft(title: "Example", tracksDueDate: true, dueDate: yesterday)
        #expect(try TrainingItem(draft: draft).isOverdue(on: now))
        draft.completed = true
        #expect(try !TrainingItem(draft: draft).isOverdue(on: now))
        draft.completed = false; draft.dueDate = now
        #expect(try !TrainingItem(draft: draft).isOverdue(on: now))
    }
}
