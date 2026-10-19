import StoreKitTest
import SwiftUI
import UIKit
import XCTest
@testable import StudyTimerAndVideo

// App Store の審査に出す、課金画面のスクリーンショットを作る。
// StudyReelReview.storekit の商品（買い切り）を読み込ませた本物の PaywallView を描いて、画像を添付する。
// review-shot.yml が添付を取り出して appstore/purchases/ に置く画像にする
@MainActor
final class ReviewScreenshotTests: XCTestCase {
    func testLifetimePaywall() async throws {
        let config = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("StudyReelReview.storekit")
        let session = try SKTestSession(contentsOf: config)
        session.disableDialogs = true
        session.clearTransactions()

        // 開発用の「Pro を有効にする」を切って、買う前の画面にする
        UserDefaults.standard.set(false, forKey: "debug_pro_unlocked")
        let store = StoreKitManager()
        await store.refresh()
        XCTAssertTrue(store.products.contains { $0.id == StoreKitManager.lifetimeID }, "買い切りの商品を読み込めません")

        // 画面いっぱいに縦長で描いて、スクロールの下にある商品の欄まで入れる
        let size = CGSize(width: 402, height: 1900)
        let host = UIHostingController(rootView: PaywallView().environmentObject(store))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(2))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let shot = XCTAttachment(image: image)
        shot.name = "lifetime-review"
        shot.lifetime = .keepAlways
        add(shot)
        window.isHidden = true
    }
}
