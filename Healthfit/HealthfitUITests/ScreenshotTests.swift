//
//  ScreenshotTests.swift
//  App Store screenshot capture — run via Scripts/screenshots.sh
//
//  Requires the app to be built with the --screenshots launch argument,
//  which bypasses auth and loads demo data automatically.
//

import XCTest

final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--screenshots"]
        app.launch()
        // Allow the app and any animations to settle
        sleep(2)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot 1: Today — Readiness & Coach (top of screen)

    @MainActor
    func test01_Today_Readiness() throws {
        // Should land on Today tab by default
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        // Tap Today tab to ensure we're there
        let todayTab = tabBar.buttons.element(boundBy: 0)
        if todayTab.exists { todayTab.tap() }
        sleep(1)

        snapshot("01-Today-Readiness")
    }

    // MARK: - Screenshot 2: Today — scroll down to Session widget

    @MainActor
    func test02_Today_Session() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        let todayTab = tabBar.buttons.element(boundBy: 0)
        if todayTab.exists { todayTab.tap() }
        sleep(1)

        // Scroll down to show the session widget
        app.swipeUp()
        sleep(1)

        snapshot("02-Today-Session")
    }

    // MARK: - Screenshot 3: Plan tab

    @MainActor
    func test03_Plan() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        let planTab = tabBar.buttons.element(boundBy: 1)
        XCTAssertTrue(planTab.waitForExistence(timeout: 5))
        planTab.tap()
        sleep(2)

        snapshot("03-Plan")
    }

    // MARK: - Screenshot 4: Eat / Nutrition tab

    @MainActor
    func test04_Eat() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        let eatTab = tabBar.buttons.element(boundBy: 2)
        XCTAssertTrue(eatTab.waitForExistence(timeout: 5))
        eatTab.tap()
        sleep(2)

        snapshot("04-Eat")
    }

    // MARK: - Screenshot 5: Coach chat tab

    @MainActor
    func test05_Coach() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        let coachTab = tabBar.buttons.element(boundBy: 3)
        XCTAssertTrue(coachTab.waitForExistence(timeout: 5))
        coachTab.tap()
        sleep(2)

        snapshot("05-Coach")
    }
}

// MARK: - Snapshot helper

/// Saves a screenshot as an XCTest attachment (visible in Xcode's test report).
@MainActor
func snapshot(_ name: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: "Snapshot: \(name)") { activity in
        activity.add(attachment)
    }
}
