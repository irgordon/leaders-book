import Foundation
import os

struct LockedSummary: Equatable, Sendable {
    let soldiers: Int
    let results: Int
}

enum RecordAccessError: UserPresentableError {
    case locked, unavailable, cancelled, superseded
    var userMessage: String {
        switch self {
        case .locked: "Unlock records to continue."
        case .unavailable: "Device authentication is unavailable. Set a device passcode in Settings."
        case .cancelled: "Authentication was cancelled."
        case .superseded: "The unlock request expired. Try again."
        }
    }
}

@MainActor
protocol RecordAuthenticating {
    func authenticate() async throws
    func authenticateForExport() async throws
    func cancel()
}

@MainActor
struct UnavailableRecordAuthenticator: RecordAuthenticating {
    func authenticate() async throws { throw RecordAccessError.unavailable }
    func cancel() {}
}

/// Revocation is synchronous; actor-queued work checks the same protected lease.
final class RecordAccessLease: Sendable {
    private let valid = OSAllocatedUnfairLock(initialState: true)
    func revoke() { valid.withLock { $0 = false } }
    func check() throws { try valid.withLock { guard $0 else { throw RecordAccessError.locked } } }
}

@MainActor extension RecordAuthenticating {
    func authenticateForExport() async throws { try await authenticate() }
}

struct AuthorizedRecordExport: Identifiable, Sendable {
    let id = UUID()
    enum Content: Sendable { case notes(String), certificate(ImportedRecordFile) }
    let content: Content
    var data: Data {
        switch content { case .notes(let text): Data(text.utf8); case .certificate(let file): file.data }
    }
}
