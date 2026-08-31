import XCTest

@MainActor
final class CoreFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testLaunchShowsGridAndPersistentDemoTrustState() {
        launchApp()
        XCTAssertTrue(waitForTrustLabel())
        XCTAssertTrue(app.tabBars.buttons["Grid"].exists)
        XCTAssertTrue(
            element("grid.status").waitForExistence(timeout: 8)
                || app.staticTexts["ServoGrid"].waitForExistence(timeout: 4),
            "Grid status chrome must be visible on launch"
        )
        XCTAssertTrue(demoTrustVisible, "Demo data must remain visible on launch")
    }

    func testSettingsShowsHonestSourceAccessMatrix() {
        launchApp()
        XCTAssertTrue(waitForTrustLabel())
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(
            revealMatrix(),
            "Settings must expose the Australia source-access matrix"
        )
        XCTAssertTrue(matrixCopyExists("wa-fuelwatch", "Public live and scheduled"))
        XCTAssertTrue(matrixCopyExists("nsw-fuelcheck", "Credentials and subscriber agreement required"))
        XCTAssertTrue(matrixCopyExists("tas-fuelcheck", "Credentials and subscriber agreement required"))
        XCTAssertTrue(matrixCopyExists("vic-servo-saver", "24-hour delayed"))
        XCTAssertTrue(matrixCopyExists("qld-fuel-prices", "Token and consumer signup"))
        XCTAssertTrue(matrixCopyExists("sa-fuel-pricing", "Registered publisher"))
        XCTAssertTrue(matrixCopyExists("nt-myfuel", "unverified"))
        XCTAssertTrue(matrixCopyExists("act-fuelcheck", "Coverage unverified"))
        XCTAssertTrue(matrixCopyExists("fixture-national", "fixture demo only"))
    }

    func testSelectingFuelGradeUpdatesSelectedControl() {
        launchApp()
        XCTAssertTrue(waitForTrustLabel())
        let e10 = app.buttons["fuel.grade.e10"]
        XCTAssertTrue(e10.waitForExistence(timeout: 8))
        e10.tap()
        XCTAssertTrue(
            e10.waitForExistence(timeout: 6) && e10.isSelected,
            "Selecting E10 should mark that fuel-grade control as selected"
        )
        XCTAssertFalse(e10.label.isEmpty)
        XCTAssertTrue(
            e10.label.localizedCaseInsensitiveContains("E10")
                || e10.label.localizedCaseInsensitiveContains("E 10"),
            "Fuel grade control must expose a readable name, not an unexplained identifier"
        )
    }

    func testTappingMarkerOpensStationDetailAndSourceDisclosure() {
        launchApp()
        XCTAssertTrue(waitForTrustLabel())
        openStationDetail()
        XCTAssertTrue(element("station.sheet").waitForExistence(timeout: 10))
        XCTAssertTrue(element("station.source").waitForExistence(timeout: 6))
        XCTAssertTrue(
            app.staticTexts["Demo data"].exists
                || element("trust.label").exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "demo")).firstMatch.exists
        )
        XCTAssertTrue(element("station.source.link").exists)
    }

    func testMonitorNavigationShowsSourceHealth() {
        launchApp()
        XCTAssertTrue(waitForTrustLabel())
        app.tabBars.buttons["Monitor"].tap()
        let health = element("monitor.health")
        XCTAssertTrue(health.waitForExistence(timeout: 8))
        let healthLabel = health.label
        XCTAssertTrue(
            healthLabel.localizedCaseInsensitiveContains("demo")
                || healthLabel.localizedCaseInsensitiveContains("fixture")
                || app.staticTexts["Demo data"].exists
                || textExists("Explicit evaluation fixtures"),
            "Monitor must show source health for the demo source"
        )
    }

    private func revealMatrix() -> Bool {
        if element("settings.source.matrix").waitForExistence(timeout: 4) { return true }
        if element("settings.source.row.wa-fuelwatch").waitForExistence(timeout: 2) { return true }
        for _ in 0..<8 {
            app.swipeUp()
            if element("settings.source.matrix").exists { return true }
            if element("settings.source.row.wa-fuelwatch").exists { return true }
            if app.staticTexts["WA"].exists { return true }
        }
        return false
    }

    private func matrixCopyExists(_ rowID: String, _ snippet: String) -> Bool {
        let row = element("settings.source.row.\(rowID)")
        for _ in 0..<10 {
            if row.exists, row.label.localizedCaseInsensitiveContains(snippet) {
                return true
            }
            if textExistsOnce(snippet) { return true }
            app.swipeUp()
        }
        return false
    }

    private func textExistsOnce(_ snippet: String) -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", snippet)).firstMatch.exists
    }

    func testEnteringAlertSetupDoesNotRequestNotificationAuthorization() {
        launchApp()
        XCTAssertTrue(waitForTrustLabel())
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(openAlertSetup(), "Alert setup must open from Settings without a notification prompt")
        XCTAssertTrue(element("alert.setup").waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["alert.enable"].exists)
        XCTAssertFalse(notificationPermissionPrompt.exists)
        XCTAssertFalse(springboard.alerts.element.exists)
    }

    func testCaptureEvidenceJourney() {
        launchApp()
        XCTAssertTrue(waitForTrustLabel())
        capture("01-grid")

        app.tabBars.buttons["Briefs"].tap()
        XCTAssertTrue(app.staticTexts["Briefs"].waitForExistence(timeout: 8))
        capture("02-briefs")

        app.tabBars.buttons["Monitor"].tap()
        XCTAssertTrue(element("monitor.health").waitForExistence(timeout: 8))
        capture("03-monitor")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(element("settings.source.matrix").waitForExistence(timeout: 8))
        capture("04-settings")

        app.tabBars.buttons["Grid"].tap()
        openStationDetail()
        XCTAssertTrue(element("station.sheet").waitForExistence(timeout: 10))
        capture("05-station-detail")
    }

    private var demoTrustVisible: Bool {
        app.staticTexts["Demo data"].exists
            || element("trust.label").label == "Demo data"
            || element("grid.status").label.localizedCaseInsensitiveContains("demo data")
    }

    @discardableResult
    private func waitForTrustLabel() -> Bool {
        if app.staticTexts["Demo data"].waitForExistence(timeout: 8) { return true }
        if element("trust.label").waitForExistence(timeout: 4) { return true }
        return element("grid.status").waitForExistence(timeout: 4)
    }

    private func openAlertSetup() -> Bool {
        let byID = app.buttons["settings.alert.create"]
        let byLabel = app.buttons["Create an alert"]
        for _ in 0..<10 {
            if byID.exists {
                byID.tap()
                return true
            }
            if byLabel.exists {
                byLabel.tap()
                return true
            }
            app.swipeUp()
        }
        return false
    }

    private func openStationDetail() {
        let markerIDs = [
            "station.marker.demo-sydney",
            "station.marker.demo-perth",
            "station.marker.demo-darwin",
            "station.marker.demo-hobart",
            "station.marker.demo-adelaide"
        ]
        for identifier in markerIDs {
            let marker = app.otherElements[identifier]
            if marker.waitForExistence(timeout: 2) {
                marker.tap()
                if element("station.sheet").waitForExistence(timeout: 3) { return }
            }
            let anyMatch = element(identifier)
            if anyMatch.exists {
                anyMatch.tap()
                if element("station.sheet").waitForExistence(timeout: 3) { return }
            }
        }

        let cluster = app.otherElements["cluster.marker"]
        if cluster.waitForExistence(timeout: 3) {
            cluster.tap()
            let afterZoom = app.otherElements.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "station.marker.")
            ).firstMatch
            if afterZoom.waitForExistence(timeout: 5) {
                afterZoom.tap()
                if element("station.sheet").waitForExistence(timeout: 3) { return }
            }
        }

        let index = app.buttons["grid.station.index"]
        XCTAssertTrue(index.waitForExistence(timeout: 6), "Expected a map marker, cluster, or station index")
        index.tap()
        let sydney = app.buttons["station.row.demo-sydney"]
        if sydney.waitForExistence(timeout: 6) {
            sydney.tap()
            return
        }
        let firstRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "station.row.")
        ).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 6))
        firstRow.tap()
    }

    private func textExists(_ snippet: String) -> Bool {
        let query = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", snippet)).firstMatch
        if query.waitForExistence(timeout: 2) { return true }
        for _ in 0..<6 {
            app.swipeUp()
            if query.exists { return true }
        }
        return query.exists
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    private var notificationPermissionPrompt: XCUIElement {
        springboard.alerts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Notification", "notify")
        ).firstMatch
    }
}
