import XCTest

// App Store の審査に出す、課金画面のスクリーンショットを撮る。
// StudyReelReview スキームで動かすと、StudyReelReview.storekit の商品（買い切り）が課金画面に並ぶ
final class ReviewScreenshotTests: XCTestCase {
    @MainActor
    func testLifetimePaywall() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-StudyReelDemo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        let settings = app.buttons["設定・情報"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.tap()

        let pro = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Pro")).firstMatch
        XCTAssertTrue(pro.waitForExistence(timeout: 10))
        pro.tap()

        // 商品の行はボタンなので、値段の文字はボタンのラベルにまとまっている
        let price = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "4,800")).firstMatch
        XCTAssertTrue(price.waitForExistence(timeout: 30), "買い切りの商品が課金画面に出ていません")
        Thread.sleep(forTimeInterval: 1.5)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "lifetime-review"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
