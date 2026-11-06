import XCTest

@MainActor
final class LeadersBookUITests: XCTestCase {
    func testSoldierEditsRestoreAfterUnlockAndClearAfterSaveOrDiscard() {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchUnlocked(app)
        selectTab("Soldiers", in: app)
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        app.buttons.matching(identifier: "Add Soldier").firstMatch.tap()
        let name = app.textFields["soldierName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Memory Draft")
        let notes = app.descendants(matching: .any).matching(identifier: "soldierNotes").firstMatch
        reveal(notes, in: app)
        notes.tap(); notes.typeText("Unsaved notes survive locking")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["unlockRecords"].waitForExistence(timeout: 5))
        XCTAssertFalse(name.exists)
        app.buttons["unlockRecords"].tap()
        XCTAssertTrue(app.buttons["saveSoldier"].waitForExistence(timeout: 5))
        reveal(notes, in: app)
        XCTAssertEqual(notes.value as? String, "Unsaved notes survive locking")
        app.buttons["saveSoldier"].tap()
        XCTAssertTrue(app.navigationBars.staticTexts["PVT Memory Draft"].waitForExistence(timeout: 5))
        let delete = app.buttons["Delete Soldier"]
        reveal(delete, in: app); delete.tap()
        app.buttons["Delete Soldier and Results"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "Add Soldier").firstMatch.waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Add Soldier").firstMatch.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Discarded Draft")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["unlockRecords"].waitForExistence(timeout: 5))
        app.buttons["unlockRecords"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Discarded Draft")
        app.buttons["Cancel"].tap()
        app.buttons["Discard Changes"].tap()
        app.buttons["lockRecords"].tap()
        app.buttons["unlockRecords"].tap()
        XCTAssertTrue(app.buttons["lockRecords"].waitForExistence(timeout: 5))
        XCTAssertFalse(name.exists)
    }

    func testSimultaneousFailuresAreBothPresented() {
        let app = XCUIApplication()
        app.launchArguments = ["--authentication-test-simultaneous-errors"]
        app.launch()
        let operation = app.alerts["Records Remain Locked"]
        XCTAssertTrue(operation.waitForExistence(timeout: 5))
        operation.buttons["OK"].tap()
        let draft = app.alerts["Draft Not Saved"]
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        draft.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["unlockRecords"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    func testLockedSummaryAndRejectedAuthentication() {
        let app = XCUIApplication()
        app.launchArguments = ["--authentication-test-denied"]
        app.launch()
        XCTAssertTrue(app.buttons["unlockRecords"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lockRecords"].exists)
        XCTAssertFalse(app.tabBars.buttons["Soldiers"].exists)
        app.buttons["unlockRecords"].tap()
        XCTAssertTrue(app.alerts["Records Remain Locked"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lockRecords"].exists)
        capture("Locked Summary — Denied Authentication", app: app)
        app.terminate()
        app.launchArguments = []
        launchUnlocked(app)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["unlockRecords"].waitForExistence(timeout: 5))
        app.buttons["unlockRecords"].tap()
        XCTAssertTrue(app.buttons["lockRecords"].waitForExistence(timeout: 5))
        app.buttons["lockRecords"].tap()
        XCTAssertTrue(app.buttons["unlockRecords"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Soldiers"].exists)
        capture("Locked Summary — Manual Lock", app: app)
    }

    func testAFTEventFailureExplanation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-light"]
        launchUnlocked(app)
        selectTab("Today", in: app)
        app.buttons["Score an AFT"].tap()
        enterMaximumAFT(in: app)
        let deadlift = app.textFields["aft-mdl"]
        for _ in 0..<6 { app.swipeDown() }
        reveal(deadlift, in: app)
        replaceText(in: deadlift, with: "0")
        app.buttons["dismissFitnessKeyboard"].tap()
        let failure = app.staticTexts["Deadlift: 0/100 — No Go (60 Points Below Standard)"]
        reveal(failure, in: app)
        XCTAssertTrue(failure.exists)
        XCTAssertEqual(app.staticTexts["aftTotal"].label, "400 / 500")
        XCTAssertTrue(app.staticTexts["Does Not Meet Standard"].exists)
        capture("AFT Event Failure — Icon and Text", app: app)
    }

    func testRankAndPlaceholderPreviews() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchUnlocked(app)
        let team = [("PFC", "Jordan Morgan"), ("SPC", "Alex Chen"), ("CPL", "Taylor Brooks"), ("SGT", "Casey Turner"), ("PV2", "Riley Davis")]
        for (rank, name) in team {
            selectTab("Soldiers", in: app)
            if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
            if app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "\(rank) \(name)")).firstMatch.exists { continue }
            app.buttons.matching(identifier: "Add Soldier").firstMatch.tap()
            let field = app.textFields["soldierName"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            let picker = app.buttons["soldierRank"]
            reveal(picker, in: app)
            picker.tap()
            app.buttons[rank].tap()
            field.tap(); field.typeText(name)
            app.buttons["saveSoldier"].tap()
            XCTAssertTrue(app.navigationBars.staticTexts["\(rank) \(name)"].waitForExistence(timeout: 5))
        }
        selectTab("Today", in: app)
        capture("Front Cover — Layout Preview", app: app)
        selectTab("Soldiers", in: app)
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "SGT Casey Turner")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars.staticTexts["SGT Casey Turner"].waitForExistence(timeout: 5))
        assertHeaderSpacing(in: app)
        capture("Open Record — Layout Preview", app: app)
        if !app.staticTexts["Unit Safety Training"].firstMatch.exists {
        let add = app.buttons["addTrainingRecord"]
        reveal(add, in: app)
        add.tap()
        let training = app.textFields["trainingTitle"]
        XCTAssertTrue(training.waitForExistence(timeout: 5))
        training.tap(); training.typeText("Cyber Awareness")
        app.buttons["saveTraining"].tap()
        reveal(add, in: app)
        add.tap()
        XCTAssertTrue(training.waitForExistence(timeout: 5))
        training.tap(); training.typeText("Unit Safety Training")
        app.buttons["saveTraining"].tap()
        }
        for _ in 0..<5 { app.swipeDown() }
        reveal(app.staticTexts["Unit Safety Training"].firstMatch, in: app)
        capture("Training Rows — Layout Preview", app: app)
        let originalAppearance = XCUIDevice.shared.appearance
        defer { XCUIDevice.shared.appearance = originalAppearance }
        for (appearance, name) in [(XCUIDevice.Appearance.light, "Light"), (.dark, "Dark")] {
            XCUIDevice.shared.appearance = appearance
            app.terminate()
            app.launchArguments = [name == "Dark" ? "--preview-dark" : "--preview-light"]
            launchUnlocked(app)
            selectTab("Today", in: app)
            capture("Theme Front Cover — \(name)", app: app)
            selectTab("Soldiers", in: app)
            if !app.navigationBars.staticTexts["SGT Casey Turner"].exists {
                app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "SGT Casey Turner")).firstMatch.tap()
            }
            // The profile may retain its training scroll position across tab changes.
            for _ in 0..<5 { app.swipeDown() }
            assertHeaderSpacing(in: app)
            capture("Theme Soldier Profile — \(name)", app: app)
        }
    }

    func testRankSpacingAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchUnlocked(app)
        selectTab("Soldiers", in: app)
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        let soldier = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "SGT Casey Turner")).firstMatch
        reveal(soldier, in: app)
        soldier.tap()
        assertHeaderSpacing(in: app)
        capture("Accessibility Text — Rank Spacing", app: app)
    }

    private func assertHeaderSpacing(in app: XCUIApplication) {
        let name = app.descendants(matching: .any).matching(identifier: "soldierHeaderName").firstMatch
        let rank = app.descendants(matching: .any).matching(identifier: "soldierHeaderRank").firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(rank.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(rank.frame.minY - name.frame.maxY, 8, "Rank must remain below the name with a visible gap")
        XCTAssertGreaterThan(rank.frame.height, 0)
    }

    func testPhotoTrainingAndHeightWeightWorkflow() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchUnlocked(app)
        selectTab("Today", in: app)
        capture("Front Cover — Layout Preview", app: app)
        selectTab("Soldiers", in: app)
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        app.buttons.matching(identifier: "Add Soldier").firstMatch.tap()
        app.buttons["Choose From Photo Library"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH 'Photo,'")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8), app.debugDescription)
        photo.tap()
        let name = "Jordan Morgan"
        let field = app.textFields["soldierName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["saveSoldier"].tap()
        XCTAssertTrue(app.navigationBars.staticTexts["PVT \(name)"].waitForExistence(timeout: 5))
        let measurements = app.buttons["Add HT/WT Record"]
        reveal(measurements, in: app)
        measurements.tap()
        let height = app.textFields["recordHeight"]
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        height.tap(); height.typeText("70")
        let weight = app.textFields["recordWeight"]
        weight.tap(); weight.typeText("165")
        app.buttons["saveHeightWeight"].tap()
        for title in ["Cyber Awareness", "Unit Safety Training"] {
            let add = app.buttons["addTrainingRecord"]
            reveal(add, in: app)
            add.tap()
            let training = app.textFields["trainingTitle"]
            XCTAssertTrue(training.waitForExistence(timeout: 5))
            training.tap(); training.typeText(title)
            app.buttons["saveTraining"].tap()
        }
        selectTab("Today", in: app)
        app.buttons["Score an AFT"].tap()
        enterMaximumAFT(in: app)
        let assignment = app.buttons["aftSoldierPicker"]
        reveal(assignment, in: app)
        assignment.tap()
        app.buttons["PVT \(name)"].tap()
        let saveResult = app.buttons["saveAFTResult"]
        reveal(saveResult, in: app)
        saveResult.tap()
        app.terminate()
        launchUnlocked(app)
        selectTab("Soldiers", in: app)
        if !app.navigationBars.staticTexts["PVT \(name)"].exists {
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "PVT \(name)")).firstMatch.tap()
        }
        let score = app.descendants(matching: .any).matching(identifier: "currentSoldierAFT").firstMatch
        reveal(score, in: app)
        XCTAssertTrue(score.label.contains("500 / 500"), score.label)
        let completed = app.staticTexts["Unit Safety Training"].firstMatch
        reveal(completed, in: app)
        XCTAssertTrue(completed.exists)
        capture("Training Rows — Layout Preview", app: app)
        app.swipeDown()
        capture("Open Record — Layout Preview", app: app)
        let delete = app.buttons["Delete Soldier"]
        reveal(delete, in: app)
        delete.tap()
        app.buttons["Delete Soldier and Results"].tap()
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSoldierCreationEditingRelaunchAndDeletion() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchUnlocked(app)
        let name = "Alex Turner"
        let editedName = "Alex Taylor"
        selectTab("Soldiers", in: app)
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        app.buttons.matching(identifier: "Add Soldier").firstMatch.tap()
        let field = app.textFields["soldierName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["saveSoldier"].tap()
        XCTAssertTrue(app.navigationBars.staticTexts["PVT \(name)"].waitForExistence(timeout: 5))

        app.buttons["Edit Soldier"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: name.count))
        field.typeText(editedName)
        app.buttons["saveSoldier"].tap()
        XCTAssertTrue(app.navigationBars.staticTexts["PVT \(editedName)"].waitForExistence(timeout: 5))
        app.terminate()
        launchUnlocked(app)
        selectTab("Soldiers", in: app)
        if !app.navigationBars.staticTexts["PVT \(editedName)"].exists {
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "PVT \(editedName)")).firstMatch.tap()
        }
        XCTAssertTrue(app.navigationBars.staticTexts["PVT \(editedName)"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Persistent soldier record"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let delete = app.buttons["Delete Soldier"]
        if !delete.isHittable { app.swipeUp() }
        delete.tap()
        app.buttons["Delete Soldier and Results"].tap()
        XCTAssertTrue(app.navigationBars.staticTexts["PVT \(editedName)"].waitForNonExistence(timeout: 5))
        app.terminate()
        launchUnlocked(app)
        selectTab("Soldiers", in: app)
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "PVT \(editedName)")).firstMatch.exists)
    }

    func testRatioShortcutCalculationAndRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchUnlocked(app)
        selectTab("Today", in: app)
        app.buttons["HT/WT Calculator"].tap()
        let height = app.textFields["ratioHeight"]
        let waist = app.textFields["ratioWaist"]
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        // Exercise unit switching to start with empty measurements on repeat runs.
        app.buttons["ratioUnits"].tap()
        app.buttons["Centimeters"].tap()
        app.buttons["ratioUnits"].tap()
        app.buttons["Inches"].tap()
        replaceText(in: height, with: "70")
        replaceText(in: waist, with: "35")
        app.buttons["dismissFitnessKeyboard"].tap()
        XCTAssertEqual(app.staticTexts["ratioResult"].label, "0.500")
        selectTab("Soldiers", in: app)
        selectTab("Fitness", in: app)
        XCTAssertEqual(height.value as? String, "70")
        app.terminate()
        launchUnlocked(app)
        selectTab("Fitness", in: app)
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        XCTAssertEqual(height.value as? String, "70")
        XCTAssertEqual(waist.value as? String, "35")
        XCTAssertEqual(app.staticTexts["ratioResult"].label, "0.500")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "HT/WT Calculator"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testAFTCalculationSavingAndHistory() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        launchUnlocked(app)
        selectTab("Today", in: app)
        app.buttons["Score an AFT"].tap()
        enterMaximumAFT(in: app)
        let total = app.staticTexts["aftTotal"]
        reveal(total, in: app)
        XCTAssertEqual(total.label, "500 / 500")
        let save = app.buttons["saveAFTResult"]
        reveal(save, in: app)
        save.tap()
        let result = app.staticTexts["Personal Result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertEqual(app.staticTexts["savedAFTTotal"].label, "500 / 500")
        app.terminate()
        launchUnlocked(app)
        selectTab("Fitness", in: app)
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertEqual(app.staticTexts["savedAFTTotal"].label, "500 / 500")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved AFT result"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func launchUnlocked(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.buttons["unlockRecords"].waitForExistence(timeout: 5))
        app.buttons["unlockRecords"].tap()
        XCTAssertTrue(app.buttons["lockRecords"].waitForExistence(timeout: 5))
    }

    private func selectTab(_ title: String, in app: XCUIApplication) {
        // iPadOS floating tabs need not expose a TabBar ancestor.
        if app.tabBars.buttons[title].exists {
            app.tabBars.buttons[title].tap()
        } else {
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch.tap()
        }
    }

    private func enterMaximumAFT(in app: XCUIApplication) {
        for (event, value) in [("mdl", "340"), ("hrp", "58"), ("sdc", "1:00"), ("plk", "5:00"), ("run", "10:00")] {
            let field = app.textFields["aft-\(event)"]
            reveal(field, in: app)
            replaceText(in: field, with: value)
            app.buttons["dismissFitnessKeyboard"].tap()
        }
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Control should be reachable by scrolling")
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty,
           current.first?.isNumber == true {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }
}
