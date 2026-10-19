import XCTest

// 目標と過去問の画面を順に開いて撮る（layout-check.yml）。押せる部品が画面の左右からはみ出していないかも見る
final class GoalFeatureTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func tap(_ element: XCUIElement, timeout: Double = 10) {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("見つかりません: \(element)")
            return
        }
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertInsideScreen(_ app: XCUIApplication, _ screen: String) {
        let window = app.windows.firstMatch.frame
        for element in app.buttons.allElementsBoundByIndex where element.exists && element.isHittable {
            let frame = element.frame
            guard !frame.isEmpty, frame.width < window.width else { continue }
            XCTAssert(frame.minX >= window.minX - 0.5 && frame.maxX <= window.maxX + 0.5,
                      "\(screen): 「\(element.label)」が画面の外にはみ出しています: \(frame)")
        }
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-StudyReelDemo"] + extra + ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        return app
    }

    // デモの目標（TOEIC 800点・過去問6回）がある状態
    @MainActor
    func test1GoalScreens() throws {
        let app = launch(["-StudyReelDemoGoal"])
        pause(6)
        shot("goal-01-home")
        assertInsideScreen(app, "ホーム")

        tap(app.buttons["home.goal.papers"])
        pause(2.5)
        shot("goal-02-papers")
        assertInsideScreen(app, "過去問")
        tap(app.buttons["papers.add"])
        pause(1.5)
        tap(app.buttons["公式問題集10 Test 1"])
        pause(1)
        shot("goal-03-record")
        tap(app.buttons["キャンセル"])
        pause(1)
        tap(app.buttons["papers.share"])
        pause(2.5)
        shot("goal-04-card-scoreup")
        tap(app.buttons["閉じる"])
        pause(1)
        tap(app.buttons["閉じる"])
        pause(1.5)

        tap(app.buttons["home.goal.share"])
        pause(2.5)
        shot("goal-05-card-progress")
        tap(app.buttons["宣言"])
        pause(1.5)
        shot("goal-06-card-declaration")
        tap(app.buttons["閉じる"])
        pause(1.5)

        tap(app.buttons["home.goal.edit"])
        pause(2)
        shot("goal-07-edit")
        assertInsideScreen(app, "目標の編集")
    }

    // 目標がない状態から作る
    @MainActor
    func test2CreateGoal() throws {
        let app = launch([])
        pause(6)
        shot("goal-08-home-empty")
        tap(app.buttons["home.goal.create"])
        pause(1.5)
        let title = app.textFields["goal.title"]
        tap(title)
        title.typeText("英検2級 合格")
        tap(app.textFields["goal.targetHours"])
        app.textFields["goal.targetHours"].typeText("120")
        pause(0.5)
        shot("goal-09-create")
        tap(app.buttons["goal.create"])
        pause(3)
        shot("goal-10-declared")
        XCTAssert(app.otherElements["goal.share.card"].exists || app.images["goal.share.card"].exists || app.buttons["閉じる"].exists)
    }
}
