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

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-StudyReelDemo"] + (isEnglish
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

    private func button(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // ホーム・共有・教材・1週間のVlog
    @MainActor
    func test1Home() throws {
        let app = launch()
        pause(6)
        shot("01-home")

        tap(button(app, containing: label("共有する", "Share")))
        pause(2)
        tap(app.buttons[label("今週", "This week")])
        pause(2.5)
        shot("04-share")
        tap(app.buttons[label("閉じる", "Close")])
        pause(1.5)

        tap(button(app, containing: label("すべて見る", "See All")))
        pause(3)
        shot("05-materials")
        tap(app.buttons[label("閉じる", "Close")])
        pause(1.5)

        tap(app.buttons[label("1週間のVlog", "Weekly Vlog")])
        pause(3.5)
        shot("06-vlog")
    }

    // 録画中（勉強中の音を選ぶところ）と、終わったあとの仕上げ
    @MainActor
    func test2Recording() throws {
        let app = launch()
        pause(5)
        tap(app.buttons[label("新しい記録", "New Session")])
        pause(1.5)
        tap(app.buttons[label("撮影をはじめる", "Start Recording")])
        pause(2)
        tap(app.buttons[label("開始", "Start")], timeout: 15)
        pause(4)
        tap(app.buttons[label("勉強中の音", "Study Sounds")])
        pause(1.5)
        tap(app.buttons[label("雨の音", "Rain")])
        pause(2.5)
        shot("02-recording")

        tap(app.buttons[label("終了して保存", "Stop & Save")])
        pause(4)
        tap(button(app, containing: label("モザイク", "Mosaic")), timeout: 15)
        pause(2.5)
        shot("03-review")
    }
}
