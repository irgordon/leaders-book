import Foundation

struct AttachmentDTO: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var name: String
    var kind: RecordAttachment.Kind
    init(id: UUID = UUID(), name: String, kind: RecordAttachment.Kind) { self.id = id; self.name = name; self.kind = kind }
    init(_ attachment: RecordAttachment) { id = attachment.id; name = attachment.name; kind = attachment.kind }
}

struct RecordAttachment: Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case jpeg = "jpg", png, pdf }
    let id: UUID
    private let validatedName: NonemptyText
    let kind: Kind
    var name: String { validatedName.value }
    var filename: String { "\(id.uuidString).\(kind.rawValue)" }
    init(dto: AttachmentDTO) throws {
        id = dto.id; kind = dto.kind
        validatedName = try NonemptyText(dto.name, error: .invalidAttachment)
    }
    init(name: String, kind: Kind) throws { try self.init(dto: AttachmentDTO(name: name, kind: kind)) }
}

/// Opaque file bytes, with a validated envelope. Platform decoders own full image rendering validation.
struct ImportedRecordFile: Sendable {
    let attachment: RecordAttachment
    let data: Data
    init(attachment: RecordAttachment, data: Data) throws {
        guard !data.isEmpty, data.count <= 10 * 1024 * 1024 else { throw RecordError.invalidAttachment }
        let headerMatches: Bool
        switch attachment.kind {
        case .jpeg: headerMatches = data.starts(with: [255, 216, 255])
        case .png: headerMatches = data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10])
        case .pdf: headerMatches = data.starts(with: Data("%PDF-".utf8))
        }
        guard headerMatches else { throw RecordError.invalidAttachment }
        self.attachment = attachment; self.data = data
    }
}

struct HeightWeightDTO: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var date = Date()
    var heightInches: Double
    var weightPounds: Double
}

struct HeightWeightRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    private let recorded: RecordedDate
    let heightInches: Double
    let weightPounds: Double
    var date: Date { recorded.value }
    init(dto: HeightWeightDTO) throws {
        guard dto.heightInches.isFinite, dto.weightPounds.isFinite,
              dto.heightInches > 0, dto.weightPounds > 0 else { throw RecordError.invalidMeasurements }
        id = dto.id; recorded = try RecordedDate(dto.date)
        heightInches = dto.heightInches; weightPounds = dto.weightPounds
    }
    var dto: HeightWeightDTO { HeightWeightDTO(id: id, date: date, heightInches: heightInches, weightPounds: weightPounds) }
}

extension Soldier {
    var attachments: [RecordAttachment] { [photo].compactMap { $0 } + training.compactMap(\.certificate) }
}

/// Equivalent shared references are valid; conflicting metadata for one physical file is not.
struct AttachmentSet: Sendable {
    private let indexed: [UUID: RecordAttachment]
    init(_ references: [RecordAttachment]) throws {
        var indexed: [UUID: RecordAttachment] = [:]
        for reference in references {
            if let previous = indexed[reference.id], previous != reference { throw RecordError.duplicateIdentity }
            indexed[reference.id] = reference
        }
        self.indexed = indexed
    }
    var values: [RecordAttachment] { indexed.values.sorted { $0.id.uuidString < $1.id.uuidString } }
}
