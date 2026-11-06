import Foundation

/// Process-only editing state. The lease is revoked immediately when records lock.
struct SoldierEditSession: Identifiable, Sendable {
    let id: UUID
    let window: UUID
    let original: SoldierDraft
    var soldier: SoldierDraft
    var files: [ImportedRecordFile]
    let permit: RecordAccessLease
    var isNew: Bool { original.revision == nil }
    var hasChanges: Bool { soldier != original || !files.isEmpty }
}
