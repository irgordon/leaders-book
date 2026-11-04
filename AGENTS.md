# AGENTS.md — Architectural Coding Directives

## 1. Core Philosophy

Your primary goal as an autonomous coding agent is to write Swift where failures are visible, contained, typed, and recoverable.

Do not engage in shallow defensive programming. Do not patch symptoms, hide impossible states, scatter redundant optional checks throughout trusted code, or guess intent when input is malformed.

Establish strict boundaries, create valid domain values once, enforce invariants through Swift’s type system, and allow failures to surface at the boundary that owns recovery.

## 2. Boundary Enforcement: Decode, Parse, and Establish Invariants Once

Untrusted values from APIs, JSON, persistence, user input, files, notifications, deep links, tool payloads, or IPC must become trusted domain types before entering core logic.

- **Strict Perimeter:** Decode external representations into boundary DTOs using `Codable`, then parse or construct strict domain models.
- **Trust the Core:** Once a valid domain value exists, do not repeatedly check the invariant inside business logic.
- **Boundary Revalidation:** Values crossing a trust boundary again must be parsed again.
- **No Loose Payloads in Core Logic:** Do not pass `[String: Any]`, `Any`, raw JSON, or loosely typed dictionaries through internal service layers.
- **Do Not Abuse Optionals:** Optional represents genuine absence. Do not use `T?` merely because validation was postponed.

Preferred:

```swift
struct CreateUserPayload: Decodable {
    let email: String
}

struct EmailAddress: Hashable, Sendable {
    let value: String
    init(_ rawValue: String) throws {
        guard isValidEmail(rawValue) else {
            throw UserInputError.invalidEmail
        }
        self.value = rawValue
    }
}
```

Core services receive `EmailAddress`, not arbitrary `String`.

## 3. State Management: Make Illegal States Unrepresentable

Use Swift enums, structs, access control, initializers, and associated values to prevent invalid combinations.

- **Avoid Boolean Soup:** Never represent lifecycle state with combinations such as `isLoading`, `didFail`, and `isComplete`.
- **Use Enums with Associated Values:** Model mutually exclusive states directly.
- **Bind State-Specific Data:** Data required by a state belongs to that enum case.
- **Restrict Construction:** Use private or internal initializers and validated factory methods where necessary.
- **Prefer Value Semantics:** Prefer structs and enums for domain state unless shared identity or reference semantics are required.

Preferred:

```swift
enum JobState: Sendable {
    case pending
    case running(startedAt: Date)
    case failed(JobError)
    case completed(Output)
}
```

Reject:

```swift
var isPending: Bool
var isRunning: Bool
var isFailed: Bool
var isComplete: Bool
```

## 4. Optionals

Optionals must communicate real domain uncertainty.

Allowed:

```swift
struct Profile {
    let middleName: String?
}
```

because a middle name may legitimately be absent.

Reject:

```swift
func loadConfiguration() -> Configuration?
```

when failure to load configuration is an error rather than legitimate absence.

Prefer:

```swift
func loadConfiguration() throws -> Configuration
```

Use optional chaining and `if let` / `guard let` where absence is meaningful. Do not scatter nil handling through code that should already operate on validated non-optional domain values.

## 5. Error Handling: Distinguish, Contain, and Route

### Expected Errors

Failures anticipated by an operation’s contract must be represented explicitly.

Examples:

- Invalid client input.
- Network timeout.
- Permitted resource absence.
- Optimistic concurrency failure.
- Authentication failure.
- Expected filesystem condition.

Use Swift error types:

```swift
enum RepositoryError: Error {
    case notFound
    case conflict
    case unavailable(underlying: Error)
}
```

Prefer specific throws semantics over sentinel values.

### Invariant Violations

Impossible internal states must fail loudly.

Do not silently convert them into `nil`, `false`, `[]`, `""`, or `[:]`.

If an internal invariant has been violated, terminate the current unit of work with enough context to diagnose it.

Use `precondition`, `assert`, or `fatalError` only when the condition truly represents a programmer or invariant violation, not ordinary recoverable input failure.

## 6. Error Provenance

Never discard the originating error.

Reject:

```swift
do {
    try client.execute()
} catch {
    throw AppError.operationFailed
}
```

Prefer preserving the cause explicitly in the domain error:

```swift
enum AppError: Error {
    case operationFailed(underlying: Error)
}
do {
    try client.execute()
} catch {
    throw AppError.operationFailed(underlying: error)
}
```

When bridging to `NSError`, logging, telemetry, or user-facing messages, preserve the original diagnostic context separately from the sanitized presentation.

## 7. Recovery Ownership

Recovery belongs at the boundary with enough information to recover correctly.

Lower layers: detect → preserve context → propagate.

Recovery boundaries: classify → retry / compensate / escalate / terminate.

Do not retry merely because an operation failed. Retryability must be explicitly defined by the operation contract.

## 8. Swift Concurrency

Concurrency safety is an architectural requirement.

- Prefer structured concurrency using `async` / `await`.
- Use actors to protect mutable shared state.
- Values crossing actor or task boundaries should conform to `Sendable` when appropriate.
- Do not add `@unchecked Sendable` merely to silence compiler diagnostics.
- Do not place unrelated application state on `@MainActor`.
- UI-owned mutable state belongs on `@MainActor`.
- Background subsystem state should use appropriate isolation rather than global mutable storage.
- Avoid detached tasks unless detached lifetime and isolation are explicitly required.
- Do not use `Task {}` as an arbitrary escape hatch from isolation errors.

Example:

```swift
actor TokenStore {
    private var token: Token?
    func current() -> Token? { token }
    func update(_ newToken: Token) { token = newToken }
}
```

## 9. Blast-Radius Containment and Recoverability

- **Explicit Retry Semantics:** Retriable operations must be idempotent, protected by an idempotency key or equivalent mechanism, or explicitly marked non-retryable.
- **Atomic Persistence:** Related persistent mutations must use the transactional or consistency mechanism provided by the storage layer.
- **Task Isolation:** Failure in independently recoverable work must remain within that task, actor, worker, or process boundary.
- **Cancellation:** Long-running asynchronous operations must respect Swift task cancellation where practical.
- **No Orphaned Tasks:** Do not create background tasks whose lifecycle is disconnected from the owning operation without explicit architectural justification.

## 10. Runtime Invariants

Not every invariant can be expressed statically. When an invariant depends on runtime information:

1. Enforce it at the narrowest authoritative boundary.
2. Construct a valid domain representation.
3. Expose only that valid representation inward.

Do not repeatedly enforce the same runtime invariant throughout downstream business logic.

## 11. Conceptual Pipeline

```text
UNTRUSTED INPUT
      ↓
Decodable DTO / raw representation
      ↓
parse + establish invariant
      ↓
TRUSTED SWIFT DOMAIN TYPE
      ↓
simple core logic
      ↓
explicit enum state transitions
      ↓
expected failure → throws / typed propagation
      ↓
invariant violation → terminate unit
      ↓
recovery boundary
      ↓
retry / compensate / escalate
```

## 12. Pattern Enforcement Matrix

| Reject | Accept |
| --- | --- |
| `[String: Any]` passed through services | Decode at boundary into concrete types |
| Repeated `if value != nil` checks in trusted logic | Construct a non-optional domain type once |
| `try?` used to suppress meaningful failure | `do/catch` or propagated `throws` |
| `try!` on fallible external operations | Explicit failure handling |
| Multiple status booleans | Enum with associated values |
| Catching `Error` and continuing with defaults | Propagating or recovering at an owning boundary |
| `@unchecked Sendable` used to silence diagnostics | Correct isolation or genuine thread-safe design |
| Global mutable state | Actor isolation or explicit ownership |
| Detached tasks without lifecycle ownership | Structured tasks with clear cancellation/lifetime |
| Generic error replacement | Domain error retaining underlying cause |
| Retry on arbitrary failure | Contracted and bounded retry behavior |
| Partial persistence updates | Atomic transaction or explicit compensation |

## 13. Operational Constraints and Quality Gates

These existing project constraints remain in force alongside the architectural directives.

### Scope and Change Budget

- Before editing, estimate scope. If the solution requires modifying more than three tracked files or adding more than 100 non-generated lines, stop and request approval unless the user has already explicitly approved that scope.
- Tests and newly created source files count toward the three-file limit.
- Generated artifacts and dependency lockfile changes caused solely by an approved dependency do not count toward either limit.
- Touch only files directly required for the task. Do not reformat, reorder imports, or clean up adjacent code unless necessary.

### Discovery and Architectural Restraint

- Read applicable `AGENTS.md` instructions and the directly relevant implementation and tests before editing. Reuse existing conventions and mechanisms where practical.
- Do not extract single-use helpers solely for hypothetical reuse. Extract only to materially improve readability, isolate a meaningful operation, or follow established conventions.
- Build strictly for the stated requirement. Do not add generic wrappers, unused options, or speculative edge-case handling.

### Test Execution and Failure Protocols

- During iteration, run the smallest existing test selection exercising the changed behavior. Do not run full project suites unless repository instructions require them or the user explicitly requests them.
- If the same targeted test fails twice consecutively and the cause of the second failure is not understood with high confidence, stop making changes and report the exact command, relevant error output or stack trace, files changed, and current hypothesis. Do not make speculative changes.
- Leave unrelated pre-existing failures untouched and report them separately.
- After targeted tests pass, run the smallest existing broader validation appropriate to the modified area. Run the full suite only when required or explicitly requested.
- If a required check cannot run, report its command and blocker. Never claim it passed.

### Invariant Rules

- Never weaken or delete assertions merely to make tests pass. Update assertions only for an authorized behavior change, preserving meaningful coverage.
- Never skip, disable, or comment out failing tests to obtain a passing result.
- Never replace an integration test’s verified system boundary with a mock. Mock only dependencies outside the behavior under test.
- Never add external libraries or install new dependencies without explicit user approval.

## Governance

Use [docs/GOVERNANCE.md](docs/GOVERNANCE.md) for the review gates and validation procedure. Record code-backed findings and fresh check results in [docs/ARCHITECTURE-AUDIT.md](docs/ARCHITECTURE-AUDIT.md). Existing violations are findings, not exemptions. Passing a build or functional tests does not establish architectural compliance.
