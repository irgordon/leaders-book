import SwiftUI
import UIKit

/// A window-level cover also sits above sheets and Quick Look while the app is inactive.
struct PrivacyShield: UIViewRepresentable {
    let locked: Bool
    let active: Bool
    let onDisconnect: @MainActor () -> Void
    func makeUIView(context: Context) -> ShieldAnchor { ShieldAnchor() }
    func updateUIView(_ view: ShieldAnchor, context: Context) {
        view.onDisconnect = onDisconnect
        view.updateActive(active)
        view.updateLock(locked)
    }
    static func dismantleUIView(_ view: ShieldAnchor, coordinator: ()) { view.removeCover() }
}

@MainActor
final class ShieldAnchor: UIView {
    var onDisconnect: (@MainActor () -> Void)?
    private weak var owningScene: UIScene?
    private var cover: UIView?
    private var wasLocked = true
    private var active = UIApplication.shared.applicationState == .active
    func updateActive(_ active: Bool) {
        self.active = active
        cover?.isHidden = active
    }
    func updateLock(_ locked: Bool) {
        if locked && !wasLocked { window?.rootViewController?.dismiss(animated: false) }
        wasLocked = locked
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDisconnected(_:)), name: UIScene.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideContent), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showContent), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view only") }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        removeCover()
        guard let window else { return }
        owningScene = window.windowScene
        let cover = UIView(frame: window.bounds)
        cover.backgroundColor = UIColor(Color.theme(.privacyCover))
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cover.isAccessibilityElement = true
        cover.accessibilityLabel = "Records Hidden"
        cover.accessibilityViewIsModal = true
        cover.isHidden = active
        window.addSubview(cover)
        self.cover = cover
    }
    @objc private func sceneDisconnected(_ notification: Notification) {
        guard let scene = notification.object as? UIScene, scene === owningScene else { return }
        onDisconnect?()
        removeCover()
    }
    @objc private func hideContent() {
        active = false
        guard let cover else { return }
        cover.superview?.bringSubviewToFront(cover)
        cover.isHidden = false
    }
    @objc private func showContent() { updateActive(true) }
    func removeCover() { cover?.removeFromSuperview(); cover = nil }
    isolated deinit { NotificationCenter.default.removeObserver(self) }
}
