import XCTest

// 横向きの録画画面と確認画面で、ボタンやスイッチが左右のセーフエリアの内側に収まっているかを確かめる。
// Dynamic Island のある iPhone で動かす（layout-check.yml）。横幅の狭い Pro（874pt）ではみ出しやすい。画面は成果物にも残す
final class LandscapeLayoutTests: XCTestCase {
    // 横向きのときの左右のセーフエリアの幅。Dynamic Island のある iPhone でいちばん狭いもの（59pt）に合わせる
    private let sideInset: CGFloat = 59

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

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
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

    // 押せる部品が、左右のセーフエリアにかかっていないか
    private func assertInsideSafeArea(_ app: XCUIApplication, _ screen: String) {
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, window.height, "\(screen): 横向きになっていません")
        let safe = window.insetBy(dx: sideInset, dy: 0)
        // スクロールする欄は、欄そのものがセーフエリアに収まっていればよい（中身は欄の端で切れて、スクロールで出てくる）
        let scrollFrames = app.scrollViews.allElementsBoundByIndex.map(\.frame).filter { !$0.isEmpty }
        for frame in scrollFrames {
            XCTAssert(
                frame.minX >= safe.minX - 0.5 && frame.maxX <= safe.maxX + 0.5,
                "\(screen): スクロールする欄がセーフエリアの外にあります: \(frame)（画面 \(window.width)pt、内側 \(safe.minX)〜\(safe.maxX)）"
            )
        }
        let kinds: [(String, XCUIElementQuery)] = [
            ("button", app.buttons), ("switch", app.switches), ("slider", app.sliders)
        ]
        for (kind, query) in kinds {
            for element in query.allElementsBoundByIndex where element.exists {
                var frame = element.frame
                // スクロールする欄の中なら、見えている部分だけを確かめる
                let center = CGPoint(x: frame.midX, y: frame.midY)
                for scroll in scrollFrames where scroll.contains(center) {
                    frame = frame.intersection(scroll)
                }
                guard !frame.isNull, !frame.isEmpty else { continue }
                XCTAssert(
                    frame.minX >= safe.minX - 0.5 && frame.maxX <= safe.maxX + 0.5,
                    "\(screen): \(kind) 「\(element.label)」(\(element.identifier)) がセーフエリアの外にあります: \(frame)（画面 \(window.width)pt、内側 \(safe.minX)〜\(safe.maxX)）"
                )
            }
        }
    }

    @MainActor
    func testLandscapeRecordingAndReview() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-StudyReelDemo", "-StudyReelDemoOrientation", "landscape",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"
        ]
        app.launch()
        pause(5)
        tap(app.buttons["新しい記録"])
        pause(1.5)
        tap(app.buttons["撮影をはじめる"])
        pause(2)
        // 横向きの撮影は、ホームインジケーターが右にくる向き
        XCUIDevice.shared.orientation = .landscapeLeft
        tap(app.buttons["開始"], timeout: 15)
        pause(4)
        shot("landscape-recording")
        assertInsideSafeArea(app, "録画画面")

        tap(app.buttons["終了して保存"])
        pause(4)
        XCTAssert(app.buttons["review.tool.mosaic"].waitForExistence(timeout: 15))
        for tool in ["cut", "filter", "mosaic", "music"] {
            tap(app.buttons["review.tool.\(tool)"])
            pause(1.5)
            shot("landscape-review-\(tool)")
            assertInsideSafeArea(app, "確認画面（\(tool)）")
        }
    }
}
