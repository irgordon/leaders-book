# Architectural Governance

The root [AGENTS.md](../AGENTS.md) is the authoritative coding policy. Its twelve architectural directives and pattern matrix apply to new work and review of existing Swift code; its operational constraints also remain mandatory. This document defines how to validate that policy without duplicating or weakening it.

## Review Gates

| Gate | Required Evidence |
| --- | --- |
| Boundary Construction | Inventory untrusted entry points; identify DTOs, parsers, validated factories, and the trusted types passed inward. Include persistence reloads, not only UI saves. |
| State and Optionals | Show valid lifecycle cases and ownership of case-specific data. Distinguish absent values, incomplete drafts, invalid input, expected failures, and internal violations. |
| Typed Failures | Identify expected error cases and preserve underlying diagnostics separately from sanitized presentation. No meaningful failures may be hidden by `try?`, defaults, or generic replacements. |
| Recovery Ownership | Name the boundary that decides retry, compensation, escalation, or termination. Define retryability and idempotency before introducing retries. |
| Concurrency and Cancellation | Identify UI isolation and subsystem isolation. Document task lifetime, cancellation, stale-result prevention, and Sendable contracts. An unstructured UI event task needs an explicit lifetime owner. |
| Persistence Consistency | Identify commit ordering, atomic scope, compensation failures, restart recovery, and attachment garbage collection. An atomic JSON write alone does not prove a multi-file transaction. |
| Verification | Run the smallest relevant existing tests, then the smallest broader validation. Preserve assertions and real integration boundaries. Record failures, unavailable checks, and remaining coverage gaps. |

## Validation Procedure

1. Read the task, root instructions, relevant Swift implementation, and existing tests. Estimate scope before edits.
2. Map user input, JSON, file imports, UIKit delegate callbacks, and persisted records to their authoritative parsing boundaries.
3. Search for potentially prohibited patterns, then inspect each occurrence in context. Search results are candidates, not an automated compliance verdict.
4. Review domain construction, state transitions, recovery ownership, error provenance, task cancellation, and transactional behavior, including problems that text search cannot detect.
5. Run the smallest test target that covers the reviewed boundary. For the current core package:

   ```sh
   swift test --scratch-path /private/tmp/leaders-book-governance-tests --filter AttachmentTests
   swift test --scratch-path /private/tmp/leaders-book-governance-tests
   ```

6. Build the native app with strict Swift concurrency checking already configured in the Xcode project:

   ```sh
   xcodebuild -project LeadersBook.xcodeproj -scheme LeadersBook \
     -configuration Release -destination 'generic/platform=iOS' \
     -derivedDataPath /private/tmp/leaders-book-governance-build \
     CODE_SIGNING_ALLOWED=NO build
   ```

7. Record exact commands, outcomes, source locations, policy mappings, and unresolved findings in [ARCHITECTURE-AUDIT.md](ARCHITECTURE-AUDIT.md). An unsigned build validates compilation; it does not validate signing or physical-device runtime behavior.
8. Report functional validation and architectural compliance separately. Do not close a finding until implementation and meaningful verification demonstrate its required outcome.

Suggested discovery command:

```sh
rg -n 'try\?|try!|Task\s*\{|Task\.detached|@unchecked|catch|\[String: Any\]|Any\b|@MainActor|isLoading|loading|loadError|errorMessage' LeadersBook --glob '*.swift'
```

## Interpretation Rules

- A draft may legitimately contain incomplete user input. It must not be mistaken for a validated domain object.
- An optional photo or certificate is genuine absence. A parse failure or unavailable required configuration is an expected error, not mere absence.
- A UIKit-required `[InfoKey: Any]` callback is a perimeter representation. It is not a loose-payload violation if adapted immediately; its failure path still needs typed, contextual handling.
- An intentional empty store on first launch and a legitimate zero-point score are valid values, not automatic violations. Empty fallback after unexpected failure is different.
- A `Task {}` occurrence is not automatically invalid. Its lifetime and cancellation ownership must be established through review.
- `Sendable` and compiler success establish only part of concurrency safety. They do not establish lifecycle ownership or responsiveness of main-actor disk operations.
- Test-only JSON mutation to construct a legacy fixture is boundary test setup, not production service-layer JSON transport. Meaningful production cleanup failures require explicit handling even if teardown of isolated temporary test directories is best effort.
- A pre-existing violation is not approval to copy the pattern. Proposed remediation must still honor scope approval, data preservation, dependency restrictions, and the failure circuit breaker.

## Reporting and Remediation

Use **Pass**, **Fail**, **Partial**, and **Not Verified**, with specific evidence. Do not assign Pass when material findings remain. Record impact and acceptance criteria for each finding; distinguish observed defects from untested risks. Maintain one authoritative audit rather than silently relabeling historical functional results as architectural certification.

Remediation should proceed by owned boundary: persistence DTO/domain construction; validated scoring inputs and outputs; diagnostic errors and load/import state; attachment transaction/recovery; import task ownership. Any source refactor exceeding the existing three-file/100-line budget requires an explicit approved scope. Governance documentation is not permission to perform unrelated application refactors.

## Implemented Boundary Contracts

The approved remediation implements the review gates through immutable domain factories, explicit DTOs/drafts, actor-owned persistence, enum-owned UI operations, and a transaction journal. [ARCHITECTURE-AUDIT.md](ARCHITECTURE-AUDIT.md) is the authoritative inventory and consistency/retry contract. Keep that inventory current when changing a boundary; do not reintroduce raw DTOs as committed domain values or presentation strings as diagnostic storage.

For remediation regressions, the focused selections are `FitnessTests`, `GovernanceTests`, `AttachmentTests`, and `RecoveryTests`. The broader check is the existing combined core target, followed by the existing native UI target and Release build when their affected areas warrant them. No new dependency or mocked storage boundary is needed. Hardware validation and full architectural review remain distinct from compiler success.
