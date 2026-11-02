import Foundation
import StoreKit
import UIKit

// App Store のレビューを頼む。頼むのは、勉強を保存して気持ちよくホームに戻ったときだけ。
// 3回保存したときか、初めて15分以上のタイムラプスを撮れたとき（いちばん「いいな」と思うところ）。
// 自前の「レビューしてね」の画面は審査ガイドライン 5.6.1 で出せないので、iOS の仕組みだけを使う。
// 同じバージョンでは1回、前に頼んでから90日は空ける。出すかどうかの最終判断は iOS がする（年3回まで）。
// 設定には「レビューを書く」の行もあり、そちらは App Store のレビュー画面を直接開く。
enum ReviewRequest {
    static let minimumSessions = 3
    static let firstVideoSeconds = 15 * 60
    static let interval: TimeInterval = 90 * 24 * 60 * 60
    private static let lastAskedKey = "review_last_asked"
    private static let askedVersionKey = "review_asked_version"

    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6756177589?action=write-review")!

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    // 保存した記録の数を見て、頼んでよいときだけ頼む。画面が落ち着いてから出したいので少し待つ
    @MainActor
    static func askIfDeserved(sessionCount: Int, latestHasVideo: Bool = false, latestSeconds: Int = 0, delay: TimeInterval = 1.5) {
        let firstGoodVideo = latestHasVideo && latestSeconds >= firstVideoSeconds
        guard !DemoMode.isActive, sessionCount >= minimumSessions || firstGoodVideo else { return }
        let defaults = UserDefaults.standard
        if defaults.string(forKey: askedVersionKey) == version { return }
        if let last = defaults.object(forKey: lastAskedKey) as? Date, Date().timeIntervalSince(last) < interval { return }
        defaults.set(Date(), forKey: lastAskedKey)
        defaults.set(version, forKey: askedVersionKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
