import LocalAuthentication

@MainActor
final class DeviceAuthenticator: RecordAuthenticating {
    private var context: LAContext?
    func authenticate() async throws { try await evaluate(reason: "Unlock soldier records, photos, and certificates.") }
    func authenticateForExport() async throws { try await evaluate(reason: "Authorize exporting private soldier data outside this app.", cancelTitle: "Cancel Export") }
    private func evaluate(reason: String, cancelTitle: String = "Keep Records Locked") async throws {
        let context = LAContext()
        self.context = context
        defer { if self.context === context { self.context = nil }; context.invalidate() }
        context.localizedCancelTitle = cancelTitle
        var cause: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &cause) else {
            throw DeviceAuthenticationFailure(underlying: cause ?? RecordAccessError.unavailable as NSError)
        }
        try Task.checkCancellation()
        let accepted: Bool
        do {
            accepted = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                localizedReason: reason)
        } catch { throw DeviceAuthenticationFailure(underlying: error) }
        try Task.checkCancellation()
        guard accepted else { throw RecordAccessError.locked }
    }
    func cancel() { context?.invalidate(); context = nil }
}

struct DeviceAuthenticationFailure: UserPresentableError {
    let underlying: any Error
    var userMessage: String {
        guard let error = underlying as? LAError else { return RecordAccessError.unavailable.userMessage }
        switch error.code {
        case .passcodeNotSet: return "Set a device passcode in Settings before unlocking records."
        case .userCancel, .systemCancel, .appCancel: return "Authentication was cancelled."
        default: return "Authentication did not finish. Try again using device biometrics or your device passcode."
        }
    }
}

#if AUTHENTICATION_TEST_DOUBLE
/// Only the explicit Testing build configuration substitutes the external OS authenticator.
@MainActor
struct UITestAuthenticator: RecordAuthenticating {
    func authenticate() async throws {
        try Task.checkCancellation()
        if ProcessInfo.processInfo.arguments.contains("--authentication-test-denied") {
            throw RecordAccessError.cancelled
        }
    }
    func authenticateForExport() async throws {
        if ProcessInfo.processInfo.arguments.contains("--authentication-test-export-denied") { throw RecordAccessError.cancelled }
        try await authenticate()
    }
    func cancel() {}
}
#endif
