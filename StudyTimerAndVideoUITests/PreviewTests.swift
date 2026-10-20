import XCTest

// App Store のプレビュー動画用に、デモ表示のアプリを決まった順番で操作する（1.6：目標・過去問・カード・テーマカラー・録画）。
// 録画は preview.yml がシミュレータの画面を撮り、tools/appstore/preview.py が 30 秒以内に切り詰める。
// 言語は環境変数 PREVIEW_LANG（ja / en）。preview.yml が TEST_RUNNER_PREVIEW_LANG で渡す
final class PreviewTests: XCTestCase {
    private var isEnglish: Bool {
        ProcessInfo.processInfo.environment["PREVIEW_LANG"] == "en"
    }

    override func setUpWithError() throws {
        // 途中のボタンが見つからなくても、残りの場面は撮り続ける
        continueAfterFailure = true
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for title in ["Allow", "許可", "OK", "Allow While Using App", "Don’t Allow"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
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

    private func close(_ app: XCUIApplication, _ title: String) {
        let bar = app.navigationBars[title]
        guard bar.waitForExistence(timeout: 4) else { return }
        tap(bar.buttons[label("閉じる", "Close")])
        let gone = NSPredicate(format: "exists == false")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: gone, object: bar)], timeout: 4)
    }

    // 目標（D-day）→ 過去問 → 点数アップのカード → 宣言のカード → テーマカラー → 録画 → モザイク
    @MainActor
    func test1Preview() throws {
        let app = launch(["-StudyReelDemoGoal", "-StudyReelDemoTool", "mosaic"])
        pause(6)

        // ホーム：目標カードをゆっくり見せる
        app.swipeUp(velocity: .slow)
        pause(1.2)
        app.swipeDown(velocity: .slow)
        pause(2)

        // 過去問：点数の推移
        tap(app.buttons["home.goal.papers"])
        pause(3)
        app.swipeUp(velocity: .slow)
        pause(1.5)
        tap(app.buttons["papers.share"])
        pause(3.5)
        close(app, label("カードで共有", "Share Card"))
        pause(0.8)
        close(app, label("過去問・模試", "Past Papers"))
        pause(1.5)

        // 共有カード：途中経過 → 宣言
        tap(app.buttons["home.goal.share"])
        pause(3)
        tap(app.buttons[label("宣言", "Goal")])
        pause(3)
        close(app, label("カードで共有", "Share Card"))
        pause(1.5)

        // テーマカラー：設定でラベンダーに
        tap(app.buttons["gearshape"])
        pause(2.5)
        tap(app.buttons["theme.lavender"])
        pause(1.5)
        tap(app.buttons["theme.mint"])
        pause(1.5)
        tap(app.buttons["theme.lavender"])
        pause(1.5)
        close(app, label("設定", "Settings"))
        pause(2.5)

        // 録画 → 終了して保存 → モザイクの確認画面
        tap(app.buttons[label("新しい記録", "New Session")])
        pause(1.5)
        tap(app.buttons[label("撮影をはじめる", "Start Recording")])
        pause(2)
        tap(app.buttons[label("開始", "Start")], timeout: 15)
        pause(5)
        tap(app.buttons[label("終了して保存", "Stop & Save")])
        pause(4)
        _ = app.buttons["review.tool.mosaic"].waitForExistence(timeout: 15)
        pause(2.5)
        tap(app.buttons[label("フィルター", "Filter")])
        pause(2)
        tap(app.buttons[label("音楽", "Music")])
        pause(2.5)
    }
}
