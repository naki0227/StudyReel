import XCTest

// App Store に載せるスクリーンショット用に、デモ表示のアプリの画面を順に撮る。
// 言語は環境変数 SHOT_LANG（ja / en）で選ぶ。store-shots.yml が TEST_RUNNER_SHOT_LANG で渡す
final class StoreScreenshotTests: XCTestCase {
    private var isEnglish: Bool {
        ProcessInfo.processInfo.environment["SHOT_LANG"] == "en"
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for title in ["Allow", "許可", "OK", "Allow While Using App"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-StudyReelDemo"] + extra + (isEnglish
            ? ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            : ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"])
        app.launch()
        return app
    }

    private func label(_ ja: String, _ en: String) -> String { isEnglish ? en : ja }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @discardableResult
    private func tap(_ element: XCUIElement, timeout: Double = 10) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        return true
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // 共有と教材は、ボタンを押す代わりに起動引数で直接開く（ホームのボタンはテストから押しにくい）
    @MainActor
    func test3Share() throws {
        let app = launch(["-StudyReelDemoScreen", "share"])
        pause(6)
        tap(app.buttons[label("今週", "This week")])
        pause(2.5)
        shot("04-share")
    }

    @MainActor
    func test4Materials() throws {
        _ = launch(["-StudyReelDemoScreen", "materials"])
        pause(7)
        shot("05-materials")
    }

    // ホーム（目標のデモ入り）と1週間のVlog
    @MainActor
    func test1Home() throws {
        let app = launch(["-StudyReelDemoGoal"])
        pause(6)
        shot("01-home")

        tap(app.buttons[label("1週間のVlog", "Weekly Vlog")])
        pause(3.5)
        shot("06-vlog")
    }

    // 録画中（勉強中の音を選ぶところ）と、終わったあとの仕上げ
    @MainActor
    func test2Recording() throws {
        let app = launch(["-StudyReelDemoTool", "mosaic"])
        pause(5)
        tap(app.buttons[label("新しい記録", "New Session")])
        pause(1.5)
        tap(app.buttons[label("撮影をはじめる", "Start Recording")])
        pause(2)
        tap(app.buttons[label("開始", "Start")], timeout: 15)
        pause(4)
        // 雨の音を選んでから、もう一度メニューを開いて選んだところを撮る
        let sounds = app.buttons[label("勉強中の音", "Study Sounds")]
        tap(sounds)
        pause(1.5)
        tap(app.buttons[label("雨の音", "Rain")])
        pause(1.5)
        if !app.buttons[label("集中ノイズ", "Focus Noise")].exists {
            tap(sounds)
        }
        pause(1.5)
        shot("02-recording")

        // メニューを閉じてから終了する（iPad ではメニューが開いたままになる）
        if app.buttons[label("集中ノイズ", "Focus Noise")].exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            pause(1.2)
        }
        tap(app.buttons[label("終了して保存", "Stop & Save")])
        pause(4)
        // 確認画面はモザイクの道具を開いた状態で出る
        _ = app.buttons["review.tool.mosaic"].waitForExistence(timeout: 15)
        pause(2.5)
        shot("03-review")
    }

    // 目標の宣言カード（共有画面）
    @MainActor
    func test5GoalCard() throws {
        let app = launch(["-StudyReelDemoGoal", "-StudyReelDemoScreen", "goalShare"])
        pause(6)
        tap(app.buttons[label("宣言", "Goal")])
        pause(2.5)
        shot("07-goal")
    }

    // PV（tools/pv）に使う画面。過去問、途中経過と点数アップのカード、ミントとラベンダーのホーム
    @MainActor
    func test6PastPapers() throws {
        _ = launch(["-StudyReelDemoGoal", "-StudyReelDemoScreen", "papers"])
        pause(7)
        shot("08-papers")
    }

    @MainActor
    func test7GoalCards() throws {
        let app = launch(["-StudyReelDemoGoal", "-StudyReelDemoScreen", "goalShare"])
        pause(6)
        tap(app.buttons[label("途中経過", "Progress")])
        pause(2.5)
        shot("09-card-progress")
        tap(app.buttons[label("点数アップ", "Score Up")])
        pause(2.5)
        shot("10-card-scoreup")
    }

    @MainActor
    func test8ThemeHomes() throws {
        _ = launch(["-StudyReelDemoGoal", "-StudyReelDemoTheme", "mint"])
        pause(6)
        shot("11-home-mint")
        _ = launch(["-StudyReelDemoGoal", "-StudyReelDemoTheme", "lavender"])
        pause(6)
        shot("12-home-lavender")
    }

    // 1.7 の PV に使う画面。新しい問題を開くと満点に目標の満点が入っている → 点数を入れて保存 → ホームの最高点、設定のレビューの行
    @MainActor
    func test9ScoreAndReview() throws {
        let app = launch(["-StudyReelDemoGoal"])
        pause(6)
        tap(app.buttons["home.goal.score"])
        pause(1.5)
        let paper = app.textFields["score.paper"]
        tap(paper)
        paper.typeText(label("模試 A", "Mock Test A"))
        // キーボードが点数の欄に重なるので閉じてから撮る
        tap(app.buttons[label("完了", "Done")])
        pause(1.2)
        shot("13-score-prefilled")
        let value = app.textFields["score.value"]
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<3 where !(value.value(forKey: "hasKeyboardFocus") as? Bool ?? false) {
            value.tap()
            _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: focused, object: value)], timeout: 2)
        }
        value.typeText("820")
        tap(app.buttons[label("完了", "Done")])
        pause(1.2)
        shot("14-score-entered")
        tap(app.buttons["score.save"])
        pause(2.5)
        shot("15-home-score")

        tap(app.buttons["gearshape"])
        pause(2)
        app.swipeUp(velocity: .fast)
        pause(0.8)
        app.swipeUp(velocity: .fast)
        pause(1.5)
        shot("16-settings-review")
    }
}
