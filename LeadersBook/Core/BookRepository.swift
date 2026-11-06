import Foundation

struct BookDTO: Codable, Sendable {
    var version = 1
    var soldiers: [SoldierDTO] = []
    var fitnessDraft = FitnessDraft()
    var results: [AFTResultDTO] = []
    var lastTransaction: UUID?
    init() {}
    init(_ snapshot: BookSnapshot, transaction: UUID) {
        soldiers = snapshot.soldiers.map(SoldierDTO.init); fitnessDraft = snapshot.fitnessDraft
        results = snapshot.results.map(AFTResultDTO.init); lastTransaction = transaction
    }
}

struct BookSnapshot: Sendable {
    let soldiers: [Soldier]
    let fitnessDraft: FitnessDraft
    let results: [AFTResult]
    let generation: UInt64
    fileprivate init(soldiers: [Soldier], fitnessDraft: FitnessDraft, results: [AFTResult], generation: UInt64) {
        self.soldiers = soldiers; self.fitnessDraft = fitnessDraft; self.results = results; self.generation = generation
    }
    init(dto: BookDTO, scorer: AFTScoring, generation: UInt64) throws {
        guard dto.version == 1 else { throw RecordError.unsupportedVersion }
        let soldiers = try dto.soldiers.map { try Soldier(draft: SoldierDraft(dto: $0)) }
        let results = try dto.results.map { try AFTResult(dto: $0, scorer: scorer) }
        try dto.fitnessDraft.validateStructure()
        let ids = Set(soldiers.map(\.id))
        guard ids.count == soldiers.count, Set(results.map(\.id)).count == results.count else { throw RecordError.duplicateIdentity }
        guard results.allSatisfy({ $0.soldierID.map(ids.contains) ?? true }), dto.fitnessDraft.soldierID.map(ids.contains) ?? true else {
            throw RecordError.missingSoldier
        }
        _ = try AttachmentSet(soldiers.flatMap(\.attachments))
        self.init(soldiers: soldiers, fitnessDraft: dto.fitnessDraft, results: results, generation: generation)
    }
    var attachments: [RecordAttachment] { soldiers.flatMap(\.attachments) }
}

struct RecoveryIssue: Error, Sendable {
    let transaction: UUID
    let failures: [AppFailure]
}

enum CleanupStatus: Sendable {
    case clean
    case pending(RecoveryIssue)
}

struct LoadedBook: Sendable {
    let snapshot: BookSnapshot
    let cleanup: CleanupStatus
    let warning: AppFailure?
    init(snapshot: BookSnapshot, cleanup: CleanupStatus, warning: AppFailure? = nil) {
        self.snapshot = snapshot; self.cleanup = cleanup; self.warning = warning
    }
}

enum RepositoryStatus: Sendable {
    case unopened
    case ready(LoadedBook)
    case failed(AppFailure)
}

/// Save intents are non-retryable until their outcome is known. A repeated result UUID is a conflict.
/// Deletes permit already-absent identities; load/recovery are explicitly idempotent.
enum BookMutation: Sendable {
    case saveSoldier(Soldier, expectedRevision: UUID?, [ImportedRecordFile])
    case deleteSoldier(UUID)
    case saveDraft(FitnessDraft)
    case saveResult(FitnessDraft, UUID)
    case deleteResults(Set<UUID>)
}

private struct JournalDTO: Codable {
    let id: UUID
    let newFiles: [AttachmentDTO]
    let removedFiles: [AttachmentDTO]
}

/// Single-process filesystem authority. Once a journal is written a commit is non-cancellable.
/// Recovery is idempotent and only deletes files not referenced by the authoritative record file.
actor BookRepository {
    nonisolated let fileURL: URL
    private let scorer: AFTScoring
    private enum State {
        case unopened
        case ready(LoadedBook, Data?)
        case failed(AppFailure)
    }
    private var state: State = .unopened
    private var generation: UInt64 = 0
    private var journalURL: URL { fileURL.deletingLastPathComponent().appending(path: "pending-transaction.json") }
    init(fileURL: URL, scorer: AFTScoring) { self.fileURL = fileURL; self.scorer = scorer }
    nonisolated func attachmentURL(_ attachment: RecordAttachment) -> URL {
        fileURL.deletingLastPathComponent().appending(path: "Attachments/\(attachment.filename)")
    }
    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.deletingLastPathComponent().path)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
    private func readRoot(allowMissing: Bool) throws -> (BookDTO, Data?) {
        do {
            let data = try Data(contentsOf: fileURL)
            return (try JSONDecoder().decode(BookDTO.self, from: data), data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            guard allowMissing else { throw error }
            return (BookDTO(), nil) // First launch is explicitly permitted absence.
        }
    }
    func load() throws -> LoadedBook {
        let previousState = state
        let allowMissing: Bool
        switch state {
        case .unopened: allowMissing = true
        case .ready(_, let data): allowMissing = data == nil
        case .failed: allowMissing = false
        }
        state = .unopened
        do {
            try Task.checkCancellation()
            let (dto, data) = try readRoot(allowMissing: allowMissing)
            generation += 1
            let snapshot = try BookSnapshot(dto: dto, scorer: scorer, generation: generation)
            try Task.checkCancellation()
            let cleanup = try recover(dto: dto, snapshot: snapshot)
            let value = LoadedBook(snapshot: snapshot, cleanup: cleanup)
            state = .ready(value, data)
            return value
        } catch is CancellationError {
            state = previousState
            throw CancellationError()
        } catch {
            let failure = AppFailure("Open Records", underlying: error)
            state = .failed(failure)
            throw failure
        }
    }
    private func delete(_ attachments: [RecordAttachment]) -> [AppFailure] {
        var failures: [AppFailure] = []
        for attachment in attachments {
            do { try FileManager.default.removeItem(at: attachmentURL(attachment)) }
            catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
                continue // Idempotent cleanup: the requested file is already absent.
            } catch { failures.append(AppFailure("Remove Attachment \(attachment.id)", underlying: error)) }
        }
        return failures
    }
    private func recover(dto: BookDTO, snapshot: BookSnapshot) throws -> CleanupStatus {
        let data: Data
        do { data = try Data(contentsOf: journalURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return .clean }
        let journal = try JSONDecoder().decode(JournalDTO.self, from: data)
        let candidates = try (dto.lastTransaction == journal.id ? journal.removedFiles : journal.newFiles).map(RecordAttachment.init(dto:))
        let referenced = Set(snapshot.attachments.map(\.id))
        guard candidates.allSatisfy({ !referenced.contains($0.id) }), Set(candidates.map(\.id)).count == candidates.count else {
            throw RecordError.conflict
        }
        var failures = delete(candidates)
        if failures.isEmpty {
            do { try FileManager.default.removeItem(at: journalURL) }
            catch { failures.append(AppFailure("Finish Attachment Recovery", underlying: error)) }
        }
        return failures.isEmpty ? .clean : .pending(RecoveryIssue(transaction: journal.id, failures: failures))
    }
    /// User-requested retry and startup replay are contracted, idempotent recovery operations.
    func recoverPending() throws -> LoadedBook { try load() }
    func currentStatus() -> RepositoryStatus {
        switch state { case .unopened: .unopened; case .ready(let book, _): .ready(book); case .failed(let error): .failed(error) }
    }
    private func currentBook() throws -> (LoadedBook, Data?) {
        switch state {
        case .ready(let book, let data): (book, data)
        case .failed(let failure): throw failure
        case .unopened: throw RecordError.recoveryRequired
        }
    }
    func readAttachment(_ attachment: RecordAttachment, permit: RecordAccessLease) throws -> ImportedRecordFile {
        try permit.check()
        do {
            let file = try ImportedRecordFile(attachment: attachment, data: Data(contentsOf: attachmentURL(attachment)))
            try permit.check()
            return file
        }
        catch { throw AppFailure("Read Attachment \(attachment.id)", underlying: error) }
    }
    func apply(_ mutation: BookMutation, permit: RecordAccessLease) throws -> LoadedBook {
        try permit.check()
        try Task.checkCancellation()
        let (current, persistedData) = try currentBook()
        guard case .clean = current.cleanup else { throw RecordError.recoveryRequired }
        let (_, disk) = try readRoot(allowMissing: persistedData == nil)
        guard disk == persistedData else { throw RecordError.conflict }
        let previous = current.snapshot
        var soldiers = previous.soldiers, results = previous.results, draft = previous.fitnessDraft
        var uploads: [ImportedRecordFile] = []
        switch mutation {
        case .saveSoldier(let soldier, let expectedRevision, let files):
            if let index = soldiers.firstIndex(where: { $0.id == soldier.id }) {
                guard soldiers[index].revision == expectedRevision else { throw RecordError.conflict }
                soldiers[index] = soldier.committedVersion()
            }
            else {
                guard expectedRevision == nil else { throw RecordError.conflict }
                soldiers.append(soldier.committedVersion())
            }
            uploads = files
        case .deleteSoldier(let id):
            soldiers.removeAll { $0.id == id }; results.removeAll { $0.soldierID == id }
            if draft.soldierID == id { draft.soldierID = nil }
        case .saveDraft(let input):
            try input.validateStructure()
            guard input.soldierID.map({ selected in soldiers.contains { $0.id == selected } }) ?? true else { throw RecordError.missingSoldier }
            draft = input
        case .saveResult(let input, let id):
            guard !results.contains(where: { $0.id == id }) else { throw RecordError.conflict }
            let name: String
            if let selected = input.soldierID {
                guard let soldier = soldiers.first(where: { $0.id == selected }) else { throw RecordError.missingSoldier }
                name = soldier.displayName
            } else { name = "Personal Result" }
            results.insert(try scorer.result(for: input, soldierName: name, id: id), at: 0)
            draft = input; draft.tool = .history
        case .deleteResults(let ids): results.removeAll { ids.contains($0.id) }
        }
        let candidate = BookSnapshot(soldiers: soldiers, fitnessDraft: draft, results: results, generation: generation + 1)
        let refs = try AttachmentSet(candidate.attachments).values
        guard Set(uploads.map(\.attachment.id)).count == uploads.count else { throw RecordError.duplicateIdentity }
        let existing = Set(previous.attachments.map(\.id))
        let referenced = Set(refs.map(\.id))
        guard uploads.allSatisfy({ referenced.contains($0.attachment.id) && !existing.contains($0.attachment.id) }),
              refs.allSatisfy({ ref in existing.contains(ref.id) || uploads.contains(where: { $0.attachment == ref }) }) else {
            throw RecordError.invalidAttachment
        }
        for file in uploads {
            guard !FileManager.default.fileExists(atPath: attachmentURL(file.attachment).path) else { throw RecordError.conflict }
        }
        let id = UUID()
        let journal = JournalDTO(id: id, newFiles: uploads.map { AttachmentDTO($0.attachment) },
                                 removedFiles: try AttachmentSet(previous.attachments).values.filter { !referenced.contains($0.id) }.map(AttachmentDTO.init))
        let nextDTO = BookDTO(candidate, transaction: id)
        let nextData = try JSONEncoder().encode(nextDTO)
        try Task.checkCancellation()
        try permit.check()
        try write(JSONEncoder().encode(journal), to: journalURL)
        do {
            for file in uploads { try write(file.data, to: attachmentURL(file.attachment)) }
            try write(nextData, to: fileURL)
        } catch {
            let primary = AppFailure("Commit Records", underlying: error)
            let authoritativeDTO: BookDTO
            let authoritativeData: Data?
            let authoritative: BookSnapshot
            do {
                (authoritativeDTO, authoritativeData) = try readRoot(allowMissing: persistedData == nil)
                authoritative = try BookSnapshot(dto: authoritativeDTO, scorer: scorer,
                                                  generation: generation + (authoritativeDTO.lastTransaction == id ? 1 : 0))
            } catch {
                let failure = AppFailure("Resolve Transaction Outcome", underlying: primary,
                                         secondary: [AppFailure("Read Authoritative Records", underlying: error)])
                state = .failed(failure)
                throw failure // Never delete imported files when the committed outcome is unknown.
            }
            let cleanup: CleanupStatus
            do { cleanup = try recover(dto: authoritativeDTO, snapshot: authoritative) }
            catch {
                cleanup = .pending(RecoveryIssue(transaction: id, failures: [AppFailure("Recover Transaction", underlying: error)]))
            }
            let committed = authoritativeDTO.lastTransaction == id
            let value = LoadedBook(snapshot: authoritative, cleanup: cleanup, warning: committed ? primary : nil)
            state = .ready(value, authoritativeData)
            if committed {
                generation += 1
                return value // Commit is confirmed; show the storage warning without inviting a duplicate save.
            }
            if case .pending(let issue) = cleanup {
                throw AppFailure("Commit and Rollback", underlying: primary, secondary: issue.failures)
            }
            throw primary
        }
        generation += 1
        let cleanup: CleanupStatus
        do { cleanup = try recover(dto: nextDTO, snapshot: candidate) }
        catch {
            cleanup = .pending(RecoveryIssue(transaction: id, failures: [AppFailure("Recover Committed Attachments", underlying: error)]))
        }
        let value = LoadedBook(snapshot: candidate, cleanup: cleanup)
        state = .ready(value, nextData)
        return value
    }
}
