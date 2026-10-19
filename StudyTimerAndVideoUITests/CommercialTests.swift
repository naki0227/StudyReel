import XCTest

// 紹介動画（CM）用に、デモ表示のアプリを決まった順番で操作する。
// 録画は GitHub Actions の commercial.yml がシミュレータの画面を撮っている
final class CommercialTests: XCTestCase {
    override func setUpWithError() throws {
        // 途中のボタンが見つからなくても、残りの場面は撮り続ける
        continueAfterFailure = true
        // 権限などのダイアログが出たら閉じて先に進む
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
        app.launchArguments = ["-StudyReelDemo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"] + extra
        app.launch()
        return app
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @discardableResult
    private func tap(_ element: XCUIElement, timeout: Double = 8) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        return true
    }

    private func button(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    // 1本目：初回の案内とスポットライト
    @MainActor
    func test1Intro() throws {
        let app = launch(["-StudyReelDemoOnboarding", "-StudyReelDemoTour"])
        pause(4)
        for _ in 0..<2 {
            pause(2.2)
            tap(app.buttons["次へ"])
        }
        pause(2.2)
        tap(app.buttons["カメラを許可してはじめる"])
        // スポットライトの案内を数枚見せる
        pause(3)
        for _ in 0..<3 {
            pause(2.4)
            tap(app.buttons["次へ"])
        }
        pause(2)
        tap(app.buttons["スキップ"])
        pause(1)
        app.terminate()
    }

    // 2本目：記録してから、共有・教材・Vlog まで
    @MainActor
    func test2Main() throws {
        let app = launch([])
        pause(6)

        // ホームをゆっくり見せる
        app.swipeUp(velocity: .slow)
        pause(1.2)
        app.swipeDown(velocity: .slow)
        pause(1.5)

        // 新しい記録 → 録画
        tap(app.buttons["新しい記録"])
        pause(1.5)
        tap(app.buttons["50分"])
        pause(1.2)
        tap(app.buttons["撮影をはじめる"])
        pause(2)
        tap(app.buttons["開始"])
        pause(4.5)

        // 画面を暗くする
        tap(app.buttons["画面を暗くする"])
        pause(2.5)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        pause(1.5)

        // 終了して確認画面
        tap(app.buttons["終了して保存"])
        pause(4)
        tap(button(app, containing: "モザイク"), timeout: 12)
        pause(2.5)
        tap(button(app, containing: "フィルター"))
        pause(2)
        tap(button(app, containing: "音楽"))
        pause(2)
        tap(app.buttons["保存"].firstMatch)
        pause(5)
        tap(app.alerts.buttons["OK"], timeout: 30)
        pause(1.5)

        // 保存画面
        let titleField = app.textFields.firstMatch
        if titleField.waitForExistence(timeout: 8) {
            titleField.tap()
            titleField.typeText("図書館で数学")
        }
        pause(1.2)
        tap(app.navigationBars.buttons["保存"].firstMatch)
        pause(2.5)

        // 共有
        tap(button(app, containing: "共有する"))
        pause(3)
        tap(app.buttons["今週"])
        pause(3)
        tap(app.buttons["閉じる"])
        pause(1.5)

        // 教材
        tap(button(app, containing: "すべて見る"))
        pause(2.5)
        tap(app.staticTexts["青チャート 数学I+A"].firstMatch)
        pause(3.5)
        tap(app.navigationBars.buttons.element(boundBy: 0))
        pause(1.2)
        tap(app.buttons["閉じる"])
        pause(1.5)

        // 1週間のVlog
        tap(app.buttons["1週間のVlog"])
        pause(2.5)
        tap(app.buttons["Vlogを作る"])
        _ = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "共有する")).firstMatch.waitForExistence(timeout: 90)
        pause(6)
    }
}
