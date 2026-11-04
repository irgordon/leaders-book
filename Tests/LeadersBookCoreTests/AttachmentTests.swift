import Foundation
import Testing
@testable import LeadersBookCore

@MainActor
struct AttachmentTests {
    @Test func previousSchemaLoadsWithoutLosingRecords() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let original = try Soldier(draft: SoldierDraft(name: "Existing Soldier", training: [TrainingDraft(title: "Legacy Training", completed: true)]))
        var book = BookDTO(); book.soldiers = [SoldierDTO(original)]
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(book)) as? [String: Any])
        var soldiers = try #require(json["soldiers"] as? [[String: Any]])
        soldiers[0].removeValue(forKey: "photo"); soldiers[0].removeValue(forKey: "heightWeight")
        soldiers[0].removeValue(forKey: "revision")
        var training = try #require(soldiers[0]["training"] as? [[String: Any]])
        training[0].removeValue(forKey: "completionDates"); training[0].removeValue(forKey: "certificate")
        soldiers[0]["training"] = training; json["soldiers"] = soldiers
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let store = try await openStore(url)
        let migrated = try #require((try store.records).soldiers.first)
        var expected = SoldierDTO(original); expected.revision = migrated.revision
        #expect(SoldierDTO(migrated) == expected)
        var edited = SoldierDraft(try #require((try store.records).soldiers.first)); edited.notes = "Preserved"
        try await store.saveSoldier(edited)
        let reopened = try await openStore(url)
        let loaded = try #require((try reopened.records).soldiers.first)
        #expect(loaded.training == original.training)
        #expect(loaded.training[0].completed)
        #expect(loaded.training[0].completionDates == nil)
        #expect(loaded.id == original.id)
    }
    @Test func photosCertificatesDatesAndMeasurementsSurviveRelaunchAndDeletion() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        let photo = try RecordAttachment(name: "Photo.jpg", kind: .jpeg)
        let certificate = try RecordAttachment(name: "Certificate.pdf", kind: .pdf)
        var soldier = SoldierDraft(name: "Example"); soldier.photo = photo
        soldier.training = [TrainingDraft(title: "Training", completed: true, completionDates: [.distantPast], certificate: certificate)]
        soldier.heightWeight = [HeightWeightDTO(heightInches: 70, weightPounds: 170)]
        try await store.saveSoldier(soldier, importing: [try ImportedRecordFile(attachment: photo, data: jpegFixture), try ImportedRecordFile(attachment: certificate, data: pdfFixture)])
        let loaded = try await openStore(url)
        let saved = try #require((try loaded.records).soldiers.first)
        #expect(saved.photo == photo)
        #expect(saved.training.first?.title == "Training")
        #expect(saved.training.first?.completionDates == [.distantPast])
        #expect(saved.training.first?.certificate == certificate)
        #expect(saved.heightWeight?.map(\.dto) == soldier.heightWeight)
        #expect(try Data(contentsOf: (try loaded.attachmentURL(photo))) == jpegFixture)
        #expect(try Data(contentsOf: (try loaded.attachmentURL(certificate))) == pdfFixture)
        soldier = SoldierDraft(saved); soldier.photo = nil
        try await loaded.saveSoldier(soldier)
        #expect(!FileManager.default.fileExists(atPath: (try loaded.attachmentURL(photo)).path))
        #expect(FileManager.default.fileExists(atPath: (try loaded.attachmentURL(certificate)).path))
        try await loaded.deleteSoldier(id: soldier.id)
        #expect(!FileManager.default.fileExists(atPath: (try loaded.attachmentURL(certificate)).path))
    }
    @Test func failedCommitRollsBackNewFilesAndPreservesOldPhoto() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        let old = try RecordAttachment(name: "Old.jpg", kind: .jpeg)
        var soldier = SoldierDraft(name: "Example"); soldier.photo = old
        try await store.saveSoldier(soldier, importing: [try ImportedRecordFile(attachment: old, data: jpegFixture)])
        soldier = SoldierDraft(try #require((try store.records).soldiers.first))
        let replacement = try RecordAttachment(name: "Replacement.jpg", kind: .jpeg); soldier.photo = replacement
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        await #expect(throws: (any Error).self) { try await store.saveSoldier(soldier, importing: [try ImportedRecordFile(attachment: replacement, data: jpegFixture)]) }
        #expect((try store.records).soldiers.first?.photo == old)
        #expect(FileManager.default.fileExists(atPath: (try store.attachmentURL(old)).path))
        #expect(!FileManager.default.fileExists(atPath: (try store.attachmentURL(replacement)).path))
    }
    @Test func invalidDatesMeasurementsAndMissingAttachmentsAreRejected() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        var soldier = SoldierDraft(name: "Example")
        soldier.training = [TrainingDraft(title: "Test", completed: true, completionDates: [])]
        await #expect(throws: RecordError.invalidCompletionDates) { try await store.saveSoldier(soldier) }
        soldier.training = []; soldier.heightWeight = [HeightWeightDTO(heightInches: 0, weightPounds: 170)]
        await #expect(throws: RecordError.invalidMeasurements) { try await store.saveSoldier(soldier) }
        soldier.heightWeight = nil; soldier.photo = try RecordAttachment(name: "Missing.jpg", kind: .jpeg)
        await #expect(throws: RecordError.invalidAttachment) { try await store.saveSoldier(soldier) }
        #expect((try store.records).soldiers.isEmpty)
    }
    @Test func sharedReferencesSurviveUntilTheirLastOwnerIsDeleted() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        let photo = try RecordAttachment(name: "Shared.jpg", kind: .jpeg)
        var first = SoldierDraft(name: "First"); first.photo = photo
        var second = SoldierDraft(name: "Second"); second.photo = photo
        try await store.saveSoldier(first, importing: [try ImportedRecordFile(attachment: photo, data: jpegFixture)])
        try await store.saveSoldier(second)
        let loaded = try await openStore(url)
        #expect((try loaded.records).soldiers.count == 2)
        try await loaded.deleteSoldier(id: first.id)
        #expect(FileManager.default.fileExists(atPath: (try loaded.attachmentURL(photo)).path))
        try await loaded.deleteSoldier(id: second.id)
        #expect(!FileManager.default.fileExists(atPath: (try loaded.attachmentURL(photo)).path))
    }

    @Test func unavailablePhotoDoesNotBlockUnrelatedCalculatorWork() async throws {
        let url = fixtureFile(); defer { cleanFixture(url) }
        let store = try await openStore(url)
        let photo = try RecordAttachment(name: "Unavailable.jpg", kind: .jpeg)
        var soldier = SoldierDraft(name: "Example"); soldier.photo = photo
        try await store.saveSoldier(soldier, importing: [try ImportedRecordFile(attachment: photo, data: jpegFixture)])
        try FileManager.default.removeItem(at: (try store.attachmentURL(photo)))
        await #expect(throws: AppFailure.self) { try await store.readAttachment(photo) }
        let draft = maximumDraft()
        try await store.saveDraft(draft)
        #expect((try store.records).fitnessDraft.values == draft.values)
        #expect((try store.records).soldiers.first?.photo == photo)
    }

}
