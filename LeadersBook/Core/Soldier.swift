import Foundation

enum Rank: String, CaseIterable, Codable, Sendable {
    case pvt = "PVT", pv2 = "PV2", pfc = "PFC", spc = "SPC", cpl = "CPL"
    case sgt = "SGT", ssg = "SSG", sfc = "SFC", msg = "MSG", firstSergeant = "1SG"
    case sgm = "SGM", csm = "CSM", wo1 = "WO1", cw2 = "CW2", cw3 = "CW3", cw4 = "CW4", cw5 = "CW5"
    case secondLieutenant = "2LT", firstLieutenant = "1LT", cpt = "CPT", maj = "MAJ", ltc = "LTC", col = "COL"
}

// Persistence DTOs are decoded only at the repository boundary.
struct TrainingDTO: Codable, Equatable, Sendable {
    var id = UUID()
    var title = ""
    var completed = false
    var tracksDueDate = false
    var dueDate = Date()
    var completionDates: [Date]?
    var certificate: AttachmentDTO?
}

struct SoldierDTO: Codable, Equatable, Sendable {
    var id = UUID()
    var name = ""
    var rank: Rank = .pvt
    var unit = ""
    var team = ""
    var notes = ""
    var training: [TrainingDTO] = []
    var updatedAt = Date()
    var revision: UUID?
    var photo: AttachmentDTO?
    var heightWeight: [HeightWeightDTO]?
    init() {}
    init(_ soldier: Soldier) {
        id = soldier.id; name = soldier.name; rank = soldier.rank; unit = soldier.unit; team = soldier.team
        notes = soldier.notes; training = soldier.training.map(\.dto); updatedAt = soldier.updatedAt; revision = soldier.revision
        photo = soldier.photo.map(AttachmentDTO.init); heightWeight = soldier.heightWeight.map { $0.map(\.dto) }
    }
}

// UI drafts can be incomplete; they cannot be passed to business logic as committed records.
struct TrainingDraft: Identifiable, Equatable, Sendable {
    var id = UUID()
    var title = ""
    var completed = false
    var tracksDueDate = false
    var dueDate = Date()
    var completionDates: [Date]?
    var certificate: RecordAttachment?
}

struct SoldierDraft: Identifiable, Equatable, Sendable {
    var id = UUID()
    var name = ""
    var rank: Rank = .pvt
    var unit = ""
    var team = ""
    var notes = ""
    var training: [TrainingDraft] = []
    var updatedAt = Date()
    var revision: UUID?
    var photo: RecordAttachment?
    var heightWeight: [HeightWeightDTO]?
    init() {}
    init(name: String, training: [TrainingDraft] = []) { self.name = name; self.training = training }
    init(_ soldier: Soldier) {
        id = soldier.id; name = soldier.name; rank = soldier.rank; unit = soldier.unit
        team = soldier.team; notes = soldier.notes; updatedAt = soldier.updatedAt; revision = soldier.revision; photo = soldier.photo
        training = soldier.training.map { item in
            TrainingDraft(id: item.id, title: item.title, completed: item.completed, tracksDueDate: item.dueDate != nil,
                          dueDate: item.persistedDueDate, completionDates: item.completionDates, certificate: item.certificate)
        }
        heightWeight = soldier.heightWeight.map { $0.map(\.dto) }
    }
    init(dto: SoldierDTO) throws {
        id = dto.id; name = dto.name; rank = dto.rank; unit = dto.unit; team = dto.team; notes = dto.notes
        updatedAt = dto.updatedAt; revision = dto.revision; heightWeight = dto.heightWeight
        photo = try dto.photo.map(RecordAttachment.init(dto:))
        training = try dto.training.map { item in
            TrainingDraft(id: item.id, title: item.title, completed: item.completed, tracksDueDate: item.tracksDueDate,
                          dueDate: item.dueDate, completionDates: item.completionDates,
                          certificate: try item.certificate.map(RecordAttachment.init(dto:)))
        }
    }
}

private enum TrainingDeadline: Equatable, Sendable { case tracked(Date), untracked(Date) }

private enum TrainingCompletion: Equatable, Sendable {
    case pending
    case legacyCompleted(RecordAttachment?)
    case completed([RecordedDate], RecordAttachment?)
}

struct TrainingItem: Identifiable, Equatable, Sendable {
    let id: UUID
    private let validatedTitle: NonemptyText
    private let completion: TrainingCompletion
    private let deadline: TrainingDeadline
    var dueDate: Date? { if case .tracked(let date) = deadline { date } else { nil } }
    var persistedDueDate: Date { switch deadline { case .tracked(let date), .untracked(let date): date } }
    var title: String { validatedTitle.value }
    var completed: Bool { if case .pending = completion { false } else { true } }
    var completionDates: [Date]? {
        if case .completed(let dates, _) = completion { dates.map(\.value) } else { nil }
    }
    var certificate: RecordAttachment? {
        switch completion {
        case .pending: nil
        case .legacyCompleted(let certificate), .completed(_, let certificate): certificate
        }
    }
    init(draft dto: TrainingDraft) throws {
        id = dto.id
        validatedTitle = try NonemptyText(dto.title, error: .invalidTraining)
        guard dto.dueDate.timeIntervalSinceReferenceDate.isFinite else { throw RecordError.invalidCompletionDates }
        deadline = dto.tracksDueDate ? .tracked(dto.dueDate) : .untracked(dto.dueDate)
        let certificate = dto.certificate
        if dto.completed {
            if let dates = dto.completionDates {
                guard !dates.isEmpty else { throw RecordError.invalidCompletionDates }
                completion = .completed(try dates.map(RecordedDate.init), certificate)
            } else { completion = .legacyCompleted(certificate) }
        } else {
            guard dto.completionDates == nil, certificate == nil else { throw RecordError.inconsistentTraining }
            completion = .pending
        }
    }
    func isOverdue(on date: Date = .now) -> Bool {
        guard case .pending = completion, let dueDate else { return false }
        return Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: date)
    }
    var dto: TrainingDTO {
        TrainingDTO(id: id, title: title, completed: completed, tracksDueDate: dueDate != nil,
                      dueDate: persistedDueDate, completionDates: completionDates,
                      certificate: certificate.map(AttachmentDTO.init))
    }
}

struct Soldier: Identifiable, Equatable, Sendable {
    let id: UUID
    private let validatedName: NonemptyText
    let rank: Rank
    let unit: String
    let team: String
    let notes: String
    let training: [TrainingItem]
    let updatedAt: Date
    let revision: UUID
    let photo: RecordAttachment?
    let heightWeight: [HeightWeightRecord]?
    var name: String { validatedName.value }
    var displayName: String { "\(rank.rawValue) \(name)" }
    var overdueCount: Int { training.filter { $0.isOverdue() }.count }
    init(draft: SoldierDraft) throws {
        id = draft.id
        validatedName = try NonemptyText(draft.name, error: .invalidName)
        rank = draft.rank; unit = draft.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        team = draft.team.trimmingCharacters(in: .whitespacesAndNewlines); notes = draft.notes
        guard draft.updatedAt.timeIntervalSinceReferenceDate.isFinite else { throw RecordError.invalidCompletionDates }
        updatedAt = draft.updatedAt
        revision = draft.revision ?? UUID()
        training = try draft.training.map(TrainingItem.init(draft:))
        guard Set(training.map(\.id)).count == training.count else { throw RecordError.duplicateIdentity }
        photo = draft.photo
        guard photo?.kind != .pdf else { throw RecordError.invalidAttachment }
        heightWeight = try draft.heightWeight.map { try $0.map(HeightWeightRecord.init(dto:)) }
        let measurementIDs = (heightWeight ?? []).map(\.id)
        guard Set(measurementIDs).count == measurementIDs.count else { throw RecordError.duplicateIdentity }
    }
    private init(committing source: Soldier) {
        id = source.id; validatedName = source.validatedName; rank = source.rank; unit = source.unit
        team = source.team; notes = source.notes; training = source.training; photo = source.photo
        heightWeight = source.heightWeight; updatedAt = .now; revision = UUID()
    }
    func committedVersion() -> Soldier { Soldier(committing: self) }

}
