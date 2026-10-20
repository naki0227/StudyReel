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

    // 閉じたことを確かめる。1回目の「閉じる」が効かなかったときだけ、もう一度押す
    private func close(_ app: XCUIApplication, _ title: String) {
        let bar = app.navigationBars[title]
        for attempt in 0..<2 where bar.exists {
            if attempt > 0 { print("「\(title)」: 1回目の「閉じる」で閉じませんでした") }
            tap(bar.buttons["閉じる"])
            let gone = NSPredicate(format: "exists == false")
            if XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: gone, object: bar)], timeout: 4) == .completed { return }
        }
        XCTAssertFalse(bar.exists, "「\(title)」の画面が閉じません")
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertInsideScreen(_ app: XCUIApplication, _ screen: String) {
        let window = app.windows.firstMatch.frame
        // 横にスクロールする候補の列（〜.chips）は、画面の外まで続くのが正しい
        let chips = NSPredicate(format: "identifier ENDSWITH '.chips'")
        let scrolling = app.scrollViews.matching(chips).allElementsBoundByIndex
            .flatMap { $0.buttons.allElementsBoundByIndex.map(\.frame) }
        for element in app.buttons.allElementsBoundByIndex where element.exists && element.isHittable {
            let frame = element.frame
            guard !frame.isEmpty, frame.width < window.width else { continue }
            guard !element.identifier.hasSuffix(".chips"), !scrolling.contains(frame) else { continue }
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
        // 共有画面が過去問の画面に重なるので、閉じるボタンはそれぞれの画面のものを押す
        close(app, "カードで共有")
        close(app, "過去問・模試")
        pause(1.5)

        tap(app.buttons["home.goal.share"])
        pause(2.5)
        shot("goal-05-card-progress")
        tap(app.buttons["宣言"])
        pause(1.5)
        shot("goal-06-card-declaration")
        close(app, "カードで共有")
        pause(1)

        tap(app.buttons["home.goal.edit"])
        XCTAssert(app.navigationBars["目標"].waitForExistence(timeout: 5), "目標の編集画面が開きません")
        pause(1)
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
        let hours = app.textFields["goal.targetHours"]
        tap(hours)
        hours.typeText("120")
        pause(0.5)
        shot("goal-09-create")
        // キーボードの「完了」で閉じてから、下の作成ボタンを押す
        tap(app.buttons["完了"])
        pause(0.8)
        tap(app.buttons["goal.create"])
        pause(3)
        shot("goal-10-declared")
        // 作ったら宣言カードの共有画面が開く
        XCTAssert(app.navigationBars["カードで共有"].waitForExistence(timeout: 5))
    }

    // テーマカラー。ミントで起動して、設定でラベンダーに変えると、設定とホームと共有カードが変わる
    @MainActor
    func test3ThemeColors() throws {
        let app = launch(["-StudyReelDemoGoal", "-StudyReelDemoTheme", "mint"])
        pause(6)
        shot("theme-01-home-mint")

        tap(app.buttons["gearshape"])
        pause(2)
        shot("theme-02-settings-mint")
        XCTAssert(app.navigationBars["設定"].exists, "設定の見出しが出ていません")
        assertInsideScreen(app, "設定")
        tap(app.buttons["theme.lavender"])
        pause(1)
        shot("theme-03-settings-lavender")
        XCTAssert(app.buttons["theme.lavender"].isSelected, "ラベンダーが選ばれていません")
        tap(app.buttons["閉じる"])
        pause(2)
        shot("theme-04-home-lavender")

        tap(app.buttons["home.goal.share"])
        pause(2.5)
        shot("theme-05-card-lavender")
        tap(app.buttons["点数アップ"])
        pause(1.5)
        shot("theme-06-scoreup-lavender")
        close(app, "カードで共有")

        tap(app.buttons["home.goal.papers"])
        pause(2.5)
        shot("theme-07-papers-lavender")
    }

    // 閉じるボタンは、どの画面でも左にある
    @MainActor
    func test4CloseButtonsOnTheLeft() throws {
        let app = launch([])
        pause(6)
        for (icon, name) in [("gearshape", "設定"), ("chart.bar", "統計"), ("calendar", "カレンダー")] {
            tap(app.buttons[icon])
            pause(2)
            shot("close-\(icon)")
            let bar = app.navigationBars[name]
            XCTAssert(bar.waitForExistence(timeout: 5), "「\(name)」が開きません")
            let closeButton = bar.buttons["閉じる"]
            XCTAssert(closeButton.exists, "「\(name)」に閉じるがありません")
            XCTAssertLessThan(closeButton.frame.midX, app.windows.firstMatch.frame.midX, "「\(name)」の閉じるが右にあります")
            close(app, name)
            pause(1)
        }
    }
}
