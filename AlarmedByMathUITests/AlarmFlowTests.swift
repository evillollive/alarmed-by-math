import XCTest

final class AlarmFlowTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-settings_theme", "chalk", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        addUIInterruptionMonitor(withDescription: "Alarm permission") { alert in
            let deny = alert.buttons["Don't Allow"]
            guard deny.exists else { return false }
            deny.tap()
            return true
        }
        XCTAssertTrue(app.buttons["alarms.add"].waitForExistence(timeout: 15))
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testDuplicateAlarmRequiresReviewAndPreservesOriginal() {
        // Keep the editing fixture visible in full at accessibility text sizes.
        let suffix = UUID().uuidString.prefix(3)
        let originalName = "A\(suffix)"
        let copyName = "B\(suffix)"
        capture("01 - Alarm list before editing")
        app.buttons["alarms.add"].tap()
        let label = app.textFields["Alarm label (optional)"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        label.typeText(originalName)
        app.navigationBars.buttons["Save"].tap()

        let original = alarmButton(named: originalName)
        scrollTo(original)
        XCTAssertTrue(original.waitForExistence(timeout: 5))
        original.press(forDuration: 1)
        app.buttons["Duplicate alarm"].tap()
        XCTAssertTrue(app.navigationBars["Copy Alarm"].waitForExistence(timeout: 5))
        XCTAssertEqual(label.value as? String, originalName)
        capture("02 - Review alarm copy")
        app.navigationBars.buttons["Cancel"].tap()
        scrollTo(original)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(originalName),")).count, 1)

        original.press(forDuration: 1)
        app.buttons["Duplicate alarm"].tap()
        XCTAssertTrue(app.navigationBars["Copy Alarm"].waitForExistence(timeout: 5))
        label.tap()
        label.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalName.count))
        label.typeText(copyName)
        XCTAssertEqual(label.value as? String, copyName)
        app.navigationBars.buttons["Save"].tap()
        let copied = alarmButton(named: copyName)
        scrollTo(copied)
        XCTAssertTrue(copied.waitForExistence(timeout: 5))
        scrollTo(original)
        XCTAssertTrue(original.exists)
        capture("03 - Original and copied alarms")

        deleteAlarm(named: copyName)
        deleteAlarm(named: originalName)
    }

    func testRingingAndMathScreensKeepControlsReachable() {
        app.buttons["alarms.settings"].tap()
        let testAlarm = app.buttons["Trigger Test Alarm"]
        scrollTo(testAlarm)
        testAlarm.tap()
        let solve = app.buttons["Solve to dismiss alarm"]
        XCTAssertTrue(solve.waitForExistence(timeout: 8))
        XCTAssertTrue(solve.isHittable)
        capture("04 - Ringing screen")
        solve.tap()
        let submit = app.buttons["Submit answer"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        scrollTo(submit)
        XCTAssertTrue(submit.isHittable)
        XCTAssertTrue(app.staticTexts["Sound preview only. No alarm will be scheduled."].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "could not be rescheduled")).firstMatch.exists)
        capture("05 - Math challenge")
        submit.tap()
        let feedback = app.staticTexts["challenge.feedback"]
        let incorrect = NSPredicate(format: "label == %@", "Not quite. Try a fresh problem.")
        expectation(for: incorrect, evaluatedWith: feedback)
        waitForExpectations(timeout: 2)
    }

    func testSoundMigrationPreviewAndSelectionStaySeparate() {
        app.terminate()
        app.launchArguments += ["-settings_sound", "classic"]
        app.launch()
        XCTAssertTrue(app.buttons["alarms.settings"].waitForExistence(timeout: 10))
        app.buttons["alarms.settings"].tap()
        let choose = app.buttons["settings.choose-sound"]
        scrollTo(choose)
        XCTAssertEqual(app.staticTexts["sound.current"].label, "Roll Call")
        choose.tap()
        XCTAssertTrue(app.navigationBars["Alarm Sounds"].waitForExistence(timeout: 5))

        let preview = app.buttons["sound.preview.glasshouse"]
        scrollTo(preview)
        let start = ProcessInfo.processInfo.systemUptime
        preview.tap()
        let stop = app.buttons["soundpicker.stop-preview"]
        XCTAssertTrue(stop.waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["sound.select.glasshouse"].value as? String, "Not selected")
        capture("06 - Sound V2 preview without selection")
        XCTAssertTrue(stop.waitForNonExistence(timeout: 30))
        XCTAssertGreaterThan(ProcessInfo.processInfo.systemUptime - start, 20)

        preview.tap()
        XCTAssertTrue(stop.waitForExistence(timeout: 3))
        stop.tap()
        XCTAssertTrue(stop.waitForNonExistence(timeout: 3))
        app.buttons["sound.select.glasshouse"].tap()
        XCTAssertEqual(app.buttons["sound.select.glasshouse"].value as? String, "Selected")
        capture("07 - Sound V2 selected")
        app.buttons["soundpicker.done"].tap()
        XCTAssertEqual(app.staticTexts["sound.current"].label, "Glasshouse")

        app.terminate()
        app.launchArguments = ["-settings_theme", "chalk", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["alarms.settings"].waitForExistence(timeout: 10))
        app.buttons["alarms.settings"].tap()
        scrollTo(choose)
        XCTAssertEqual(app.staticTexts["sound.current"].label, "Glasshouse")
        choose.tap()
        app.buttons["sound.select.chime"].tap()
        app.buttons["soundpicker.done"].tap()
    }

    func testSilentPracticeConfigurationRetryCompletionAndExit() throws {
        let practice = app.buttons["alarms.practice"]
        scrollTo(practice)
        practice.tap()
        XCTAssertTrue(app.buttons["practice.difficulty.easy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["practice.difficulty.whiz"].exists)
        scrollTo(app.buttons["practice.difficulty.easy"])
        app.buttons["practice.difficulty.easy"].tap()
        let count = app.steppers["practice.problem-count"]
        let increment = count.buttons["practice.problem-count-Increment"]
        scrollTo(increment)
        increment.tap()
        capture("08 - Silent practice setup")
        let start = app.buttons["practice.start"]
        scrollTo(start)
        start.tap()
        XCTAssertTrue(app.staticTexts["practice.expression"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["practice.progress"].label, "Problem 1 of 2")
        let submit = app.buttons["Submit answer"]
        scrollTo(submit)
        submit.tap()
        XCTAssertEqual(app.staticTexts["practice.feedback"].label, "Enter a number before checking your answer.")
        app.buttons["Number 0"].tap()
        submit.tap()
        XCTAssertTrue(app.buttons["practice.next"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["practice.progress"].label, "Problem 1 of 2")
        app.buttons["practice.next"].tap()

        for index in 1...2 {
            let expression = app.staticTexts["practice.expression"].label
            let parts = expression.split(separator: " ")
            XCTAssertEqual(parts.count, 5)
            XCTAssertEqual(parts[1], "+")
            let answer = try XCTUnwrap(Int(parts[0])) + XCTUnwrap(Int(parts[2]))
            for digit in String(answer) {
                let key = app.buttons["Number \(digit)"]
                scrollTo(key)
                key.tap()
            }
            scrollTo(submit)
            if index == 1 { capture("09 - Silent practice challenge") }
            submit.tap()
            if index == 1 {
                XCTAssertTrue(app.buttons["practice.next"].waitForExistence(timeout: 3))
                app.buttons["practice.next"].tap()
                XCTAssertEqual(app.staticTexts["practice.progress"].label, "Problem 2 of 2")
            }
        }
        XCTAssertTrue(app.buttons["practice.again"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["practice.feedback"].label, "Practice complete. Your alarms and streak are unchanged.")
        capture("10 - Silent practice completed")
        app.buttons["practice.again"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        scrollTo(start)
        start.tap()
        app.buttons["practice.done"].tap()
        XCTAssertTrue(app.buttons["alarms.add"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Solve to dismiss alarm"].exists)
    }

    private func alarmButton(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    private func deleteAlarm(named name: String) {
        let alarm = alarmButton(named: name)
        scrollTo(alarm)
        alarm.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(alarm.waitForNonExistence(timeout: 5))
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            if element.exists && element.frame.maxY < app.frame.minY + 100 {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        // Lazy list rows may not exist in the accessibility tree until visible.
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeDown()
        }
        XCTAssertTrue(element.isHittable, "Expected control to be reachable by scrolling: \(element)\n\(app.debugDescription)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
