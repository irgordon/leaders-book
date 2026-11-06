import XCTest
import SwiftUI
@testable import LeadersBook

@MainActor
final class ThemeAdapterTests: XCTestCase {
 func testSimultaneousFailuresRetainDraftUntilAcknowledged() async throws {
  let scorer = try AFTScoring()
  let store = LeaderStore(scorer: scorer)
  store.draftSave.start("Test Draft") { throw CocoaError(.fileWriteNoPermission) }
  for _ in 0..<100 where store.draftSave.phase.isRunning { await Task.yield() }
  let draft = try XCTUnwrap(store.draftSave.phase.failure)
  let operation = AppFailure("Unlock Records", underlying: RecordAccessError.cancelled)
  store.operationFailure = operation
  let binding = ContentView(store: store, scorer: scorer).presentedFailure
  XCTAssertEqual(binding.wrappedValue?.id, operation.id)
  XCTAssertEqual(binding.wrappedValue?.title, "Records Remain Locked")
  binding.wrappedValue = nil
  XCTAssertNil(store.operationFailure)
  XCTAssertEqual(store.draftSave.phase.failure?.id, draft.id)
  XCTAssertEqual(binding.wrappedValue?.id, draft.id)
  XCTAssertEqual(binding.wrappedValue?.title, "Draft Not Saved")
  binding.wrappedValue = nil
  XCTAssertNil(binding.wrappedValue)
 }

 func testPrivacyCoverThemeAndInactiveAttachment() throws {
  let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
  let previous = scene.windows.first(where: \.isKeyWindow)
  let window = UIWindow(windowScene: scene)
  let controller = UIViewController()
  window.rootViewController = controller
  window.makeKeyAndVisible()
  defer { window.isHidden = true; previous?.makeKey() }
  let anchor = ShieldAnchor(frame: window.bounds)
  anchor.updateActive(false)
  controller.view.addSubview(anchor)
  let cover = try XCTUnwrap(window.subviews.last)
  XCTAssertEqual(cover.accessibilityLabel, "Records Hidden")
  XCTAssertFalse(cover.isHidden)
  XCTAssertTrue(cover.accessibilityViewIsModal)
  for mode in ThemeMode.allCases {
   let traits = UITraitCollection(userInterfaceStyle: mode == .dark ? .dark : .light)
   let color = try XCTUnwrap(cover.backgroundColor?.resolvedColor(with: traits))
   var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
   XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &a))
   let expected = ThemeRole.privacyCover.rgb(in: mode)
   XCTAssertEqual(r, CGFloat(expected.red)/255, accuracy: 0.00001)
   XCTAssertEqual(g, CGFloat(expected.green)/255, accuracy: 0.00001)
   XCTAssertEqual(b, CGFloat(expected.blue)/255, accuracy: 0.00001)
   XCTAssertEqual(a, 1)
  }
  anchor.updateActive(true)
  XCTAssertTrue(cover.isHidden)
  NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
  XCTAssertFalse(cover.isHidden)
  NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
  XCTAssertTrue(cover.isHidden)
  anchor.removeCover()
 }

 func testOverdueTrainingBoundaries() throws {
  let today = Calendar.current.startOfDay(for: .now)
  var draft = TrainingDraft()
  draft.title = "Status Test"
  draft.tracksDueDate = true
  draft.dueDate = today
  XCTAssertFalse(try TrainingItem(draft: draft).isOverdue(on: today))
  draft.dueDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
  XCTAssertTrue(try TrainingItem(draft: draft).isOverdue(on: today))
  draft.completed = true
  XCTAssertFalse(try TrainingItem(draft: draft).isOverdue(on: today))
  draft.completed = false
  draft.tracksDueDate = false
  XCTAssertFalse(try TrainingItem(draft: draft).isOverdue(on: today))
 }
 func testStatusCuesAndDifferentiateWithoutColor() {
  XCTAssertEqual(Set(LBStatus.allCases.map(\.symbol)).count, 3)
  for status in LBStatus.allCases {
   XCTAssertNotNil(UIImage(systemName: status.symbol), "Status symbol must exist on the deployment platform")
   XCTAssertEqual(status.foreground(selected: false, differentiate: true), .textPrimary)
   XCTAssertEqual(status.foreground(selected: true, differentiate: true), .textOnSelected)
   XCTAssertEqual(status.foreground(selected: true, differentiate: false), .textOnSelected)
   XCTAssertEqual(status.foreground(selected: false, differentiate: false), status.role)
  }
 }

 func testActionStyleUsesRowSelectionForRenderedLabel() async throws {
  for mode in ThemeMode.allCases {
   for contrast in ThemeAccessibilityContrast.allCases {
    for selected in [false, true] {
     for enabled in [false, true] {
      let traits = UITraitCollection(traitsFrom: [
       UITraitCollection(userInterfaceStyle: mode == .dark ? .dark : .light),
       UITraitCollection(accessibilityContrast: contrast == .increased ? .high : .normal)
      ])
       let label = Button {} label: { Rectangle().frame(width: 24, height: 24) }
        .buttonStyle(LBActionButtonStyle()).disabled(!enabled)
        .leadersBookRow(selected: selected)
        .environment(\.colorScheme, mode == .dark ? .dark : .light)
       let host = UIHostingController(rootView: label)
       let parent = UIViewController()
       let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
       let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
       let window = UIWindow(windowScene: scene)
       window.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
       host.safeAreaRegions = []
       window.rootViewController = parent
       window.makeKeyAndVisible()
       defer { window.isHidden = true; previousKeyWindow?.makeKey() }
       parent.addChild(host)
       parent.view.addSubview(host.view)
       host.didMove(toParent: parent)
       parent.setOverrideTraitCollection(traits, forChild: host)
       host.view.frame = window.bounds
       host.view.backgroundColor = .clear
       host.view.layoutIfNeeded()
       try await Task.sleep(for: .milliseconds(100))
       var hierarchySucceeded = false
       let rendered = try XCTUnwrap(UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
        hierarchySucceeded = host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
       }.cgImage)
       let diagnosticName = "\(mode)-\(contrast)-selected-\(selected)-enabled-\(enabled)"
       let bitmap = XCTAttachment(image: UIImage(cgImage: rendered))
       bitmap.name = diagnosticName
       bitmap.lifetime = .keepAlways
       add(bitmap)
       var rgba = [UInt8](repeating: 0, count: rendered.width * rendered.height * 4)
       try rgba.withUnsafeMutableBytes { bytes in
        let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: rendered.width,
         height: rendered.height, bitsPerComponent: 8, bytesPerRow: rendered.width * 4,
         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(rendered, in: CGRect(x: 0, y: 0, width: rendered.width, height: rendered.height))
       }
       let alpha = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
       let diagnostic = "\(diagnosticName): nontransparent=\(alpha.filter { $0 > 0 }.count)/\(alpha.count), maxAlpha=\(alpha.max() ?? 0), drawHierarchy=\(hierarchySucceeded), sceneAttached=\(window.windowScene != nil), connectedScenes=\(UIApplication.shared.connectedScenes.count), actualStyle=\(host.view.traitCollection.userInterfaceStyle.rawValue), actualContrast=\(host.view.traitCollection.accessibilityContrast.rawValue)"
       print(diagnostic)
       let metadata = XCTAttachment(string: diagnostic)
       metadata.name = diagnosticName + "-metadata"
       metadata.lifetime = .keepAlways
       add(metadata)
       var pixel = [UInt8](repeating: 0, count: 4)
       try pixel.withUnsafeMutableBytes { bytes in
       let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1, height: 1,
        bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
       context.draw(rendered, in: CGRect(x: 0, y: 0, width: 1, height: 1))
       }
       let role: ThemeRole = selected ? .textOnSelected : (enabled ? .accentText : .disabledText)
       let expected = role.rgb(in: mode, contrast: contrast)
       XCTAssertEqual(pixel, [expected.red, expected.green, expected.blue, 255])
       if selected {
        XCTAssertGreaterThanOrEqual(expected.contrastRatio(with: ThemeRole.rowSelected.rgb(in: mode, contrast: contrast)), 4.5)
       }
     }
    }
   }
  }
 }
 func testActualSwiftUIColorAdapterResolvesAllTraitCombinations() {
  for style in [UIUserInterfaceStyle.light, .dark] {
   for contrast in [UIAccessibilityContrast.normal, .high] {
    for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
     let traits = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: style), UITraitCollection(accessibilityContrast: contrast), UITraitCollection(preferredContentSizeCategory: category)])
     traits.performAsCurrent {
      for role in ThemeRole.allCases {
       let actual = UIColor(Color.theme(role)).resolvedColor(with: traits)
       var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
       XCTAssertTrue(actual.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
       let expected = role.rgb(in: style == .dark ? .dark : .light, contrast: contrast == .high ? .increased : .standard)
       let label = "\(role), \(style.rawValue), \(contrast.rawValue), \(category.rawValue)"
       XCTAssertEqual(red, CGFloat(expected.red)/255, accuracy: 0.00001, label)
       XCTAssertEqual(green, CGFloat(expected.green)/255, accuracy: 0.00001, label)
       XCTAssertEqual(blue, CGFloat(expected.blue)/255, accuracy: 0.00001, label)
       XCTAssertEqual(alpha, 1, accuracy: 0.00001, label)
      }
     }
    }
   }
  }
 }
 func testBodyFontRespondsToAccessibilityCategory() {
  let normal = UIFont.preferredFont(forTextStyle: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
  let large = UIFont.preferredFont(forTextStyle: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
  XCTAssertGreaterThan(large.pointSize, normal.pointSize)
 }
}
