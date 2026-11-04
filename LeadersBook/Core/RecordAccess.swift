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
        case .cancelled: "Authentication was cancelled. Records remain locked."
        case .superseded: "The unlock request expired. Try again."
        }
    }
}

@MainActor
protocol RecordAuthenticating {
    func authenticate() async throws
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
