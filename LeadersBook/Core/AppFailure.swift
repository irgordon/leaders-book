import Foundation
import Observation

protocol UserPresentableError: LocalizedError {
    var userMessage: String { get }
}
extension UserPresentableError { var errorDescription: String? { userMessage } }

enum RecordError: String, UserPresentableError, Sendable {
    case invalidName, invalidTraining, unsupportedVersion, incompleteFitness, missingSoldier
    case invalidCompletionDates, invalidMeasurements, invalidAttachment, invalidAgeBand
    case invalidResult, duplicateIdentity, invalidDraft, inconsistentTraining, conflict, recoveryRequired
    var userMessage: String {
        switch self {
        case .invalidName: "Enter the soldier’s name."
        case .invalidTraining: "Every training item needs a title."
        case .unsupportedVersion: "These records need a newer app version. The file has been preserved."
        case .incompleteFitness: "Complete all five AFT events before saving."
        case .missingSoldier: "Choose a soldier that still exists, or choose Personal Result."
        case .invalidCompletionDates: "Completion dates must be nonempty and cannot be in the future."
        case .invalidMeasurements: "Use positive, finite measurements and a recorded date that is not in the future."
        case .invalidAttachment: "Choose a supported, nonempty attachment of at most 10 MB."
        case .invalidAgeBand: "Choose a published age band."
        case .invalidResult: "The saved AFT result is inconsistent with its five events and scoring table."
        case .duplicateIdentity: "The saved records contain conflicting identities."
        case .invalidDraft: "The calculator draft contains an unsupported event."
        case .inconsistentTraining: "Pending training cannot contain completion dates or a certificate."
        case .conflict: "The record or saved file changed. Reopen the record or reload records before saving again."
        case .recoveryRequired: "Resolve the pending attachment cleanup before saving more changes."
        }
    }
}

/// Diagnostic causes are retained; presentation never interpolates file contents or system errors.
struct AppFailure: Error, Identifiable, LocalizedError, Sendable {
    let id = UUID()
    let operation: String
    let underlying: any Error
    let secondary: [AppFailure]
    init(_ operation: String, underlying: any Error, secondary: [AppFailure] = []) {
        self.operation = operation
        self.underlying = underlying
        self.secondary = secondary
    }
    var rootCause: any Error { (underlying as? AppFailure)?.rootCause ?? underlying }
    var errorDescription: String? {
        if let failure = underlying as? AppFailure { return failure.errorDescription }
        if let presentation = underlying as? any UserPresentableError { return presentation.userMessage }
        if underlying is RecoveryIssue { return RecordError.recoveryRequired.userMessage }
        return "\(operation) could not finish."
    }
}

struct RunningWork {
    let id: UUID
    fileprivate let task: Task<Void, Never>
}

enum OperationPhase {
    case idle
    case cancelled(AppFailure?)
    case running(RunningWork)
    case failed(AppFailure)
    var isRunning: Bool { if case .running = self { true } else { false } }
    var failure: AppFailure? { if case .failed(let error) = self { error } else { nil } }
}

/// UI-event bridge with an explicit owner. Replacement/dismissal cancels the old operation.
@MainActor @Observable
final class OwnedOperation {
    private(set) var phase: OperationPhase = .idle
    func start(_ operation: String, work: @escaping @MainActor () async throws -> Void) {
        cancel()
        let id = UUID()
        let task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                try await work()
                try Task.checkCancellation()
                guard let self, case .running(let active) = self.phase, active.id == id else { return }
                self.phase = .idle
            } catch let cancellation as CancellationError {
                // Cancellation is an owned transition, not an import failure.
                guard let self, case .running(let active) = self.phase, active.id == id else { return }
                self.phase = .cancelled(AppFailure(operation, underlying: cancellation))
            } catch let cancellation as CocoaError where cancellation.code == .userCancelled {
                guard let self, case .running(let active) = self.phase, active.id == id else { return }
                self.phase = .cancelled(AppFailure(operation, underlying: cancellation))
            } catch {
                guard let self, case .running(let active) = self.phase, active.id == id else { return }
                self.phase = .failed(AppFailure(operation, underlying: error))
            }
        }
        phase = .running(RunningWork(id: id, task: task))
    }
    func dismissFailure() { if case .failed = phase { phase = .idle } }
    func cancel() {
        if case .running(let work) = phase { work.task.cancel() }
        phase = .cancelled(nil)
    }
    isolated deinit { if case .running(let work) = phase { work.task.cancel() } }
}

struct NonemptyText: Equatable, Sendable {
    let value: String
    init(_ raw: String, error: RecordError) throws {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw error }
        self.value = value
    }
}

struct RecordedDate: Equatable, Sendable {
    let value: Date
    init(_ date: Date) throws {
        guard date.timeIntervalSinceReferenceDate.isFinite, date <= Date.now else { throw RecordError.invalidCompletionDates }
        value = date
    }
}
