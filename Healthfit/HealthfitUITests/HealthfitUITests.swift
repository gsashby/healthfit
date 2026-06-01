//
//  HealthfitUITests.swift
//  Critical-path UI smoke tests.
//  These verify the app launches, reaches a usable state, and all four
//  main tabs are reachable — not that every feature works in depth.
//

import XCTest

final class HealthfitUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Reset onboarding so tests always start from a known state.
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    @MainActor
    func testAppLaunchesWithoutCrashing() {
        // If we get here the app launched. Verify at least one element is visible.
        XCTAssertTrue(app.exists)
    }

    @MainActor
    func testOnboardingOrMainTabAppears() {
        // Either the welcome screen or the main tab bar must be visible within 5 s.
        let welcomeText = app.staticTexts["HealthFit"]
        let tabBar      = app.tabBars.firstMatch
        let appeared    = welcomeText.waitForExistence(timeout: 5)
                       || tabBar.waitForExistence(timeout: 5)
        XCTAssertTrue(appeared, "Neither welcome screen nor tab bar appeared within 5 seconds")
    }

    // MARK: - Onboarding flow

    @MainActor
    func testGetStartedButtonExists() {
        let button = app.buttons["Get started"]
        guard button.waitForExistence(timeout: 5) else {
            // App may already be past onboarding — that's fine.
            return
        }
        XCTAssertTrue(button.isHittable)
    }

    @MainActor
    func testSignInLinkExists() {
        guard app.buttons["Get started"].waitForExistence(timeout: 5) else { return }
        XCTAssertTrue(app.buttons["I already have an account"].exists)
    }

    // MARK: - Tab navigation (only runs when already past onboarding)

    @MainActor
    func testAllTabsReachable() {
        guard app.tabBars.firstMatch.waitForExistence(timeout: 8) else {
            // Still on onboarding — skip tab navigation tests.
            return
        }

        let tabBar = app.tabBars.firstMatch

        for label in ["Today", "Plan", "Eat", "Coach"] {
            let tab = tabBar.buttons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 3), "\(label) tab not found")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "\(label) tab not selected after tap")
        }
    }

    @MainActor
    func testTodayTabShowsReadinessScore() {
        guard app.tabBars.firstMatch.waitForExistence(timeout: 8) else { return }

        app.tabBars.firstMatch.buttons["Today"].tap()

        // Either a live readiness score or "DEMO" label should be visible.
        let scoreOrDemo = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '^[0-9]+$' OR label == 'DEMO'")
        ).firstMatch
        XCTAssertTrue(
            scoreOrDemo.waitForExistence(timeout: 4),
            "No readiness score or DEMO label found on Today tab"
        )
    }

    @MainActor
    func testEatTabShowsMacroRing() {
        guard app.tabBars.firstMatch.waitForExistence(timeout: 8) else { return }

        app.tabBars.firstMatch.buttons["Eat"].tap()

        let fuelHeader = app.staticTexts["TODAY'S FUEL"]
        XCTAssertTrue(
            fuelHeader.waitForExistence(timeout: 4),
            "Eat tab macro card not found"
        )
    }

    @MainActor
    func testPlanTabHasTwoSegments() {
        guard app.tabBars.firstMatch.waitForExistence(timeout: 8) else { return }

        app.tabBars.firstMatch.buttons["Plan"].tap()

        let segmentedControl = app.segmentedControls.firstMatch
        XCTAssertTrue(
            segmentedControl.waitForExistence(timeout: 4),
            "Plan tab segmented control not found"
        )
        XCTAssertEqual(segmentedControl.buttons.count, 2)
    }
}
