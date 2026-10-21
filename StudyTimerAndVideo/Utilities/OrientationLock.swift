import CloudKit
import SwiftUI
import UIKit

// 録画画面だけ向きを固定するために、アプリ全体で許可する向きをここで切り替える
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationMask: UIInterfaceOrientationMask = .all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }

    // 勉強仲間の CloudKit の変化（静かなプッシュ）。読み直して、新しいスタンプなどを通知する
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else { return .noData }
        await BuddyCloud.shared.handlePush()
        return .newData
    }
}

// 撮影の向き。基本は横向きで、ボタンで縦向きに切り替える
enum CaptureOrientation: String, CaseIterable, Identifiable {
    case landscape
    case portrait

    static let storageKey = "capture_orientation"

    var id: String { rawValue }

    var isLandscape: Bool { self == .landscape }

    var title: String {
        switch self {
        case .landscape: return L10n.string("横向き")
        case .portrait: return L10n.string("縦向き")
        }
    }

    // 横向きはホームインジケーターが右側の向きにそろえる（カメラの向きと一致させるため）
    var mask: UIInterfaceOrientationMask {
        isLandscape ? .landscapeRight : .portrait
    }

    var toggled: CaptureOrientation {
        isLandscape ? .portrait : .landscape
    }
}

enum OrientationLock {
    @MainActor
    static func lock(_ mask: UIInterfaceOrientationMask) {
        apply(allowed: mask, request: mask)
    }

    // 録画画面を閉じたら向きの固定を外す。回転ロック中の人が横向きのまま残らないよう、
    // 端末が横に倒れていなければ縦に戻す
    @MainActor
    static func unlock() {
        let request: UIInterfaceOrientationMask = UIDevice.current.orientation.isLandscape ? .all : .portrait
        apply(allowed: .all, request: request)
    }

    @MainActor
    private static func apply(allowed mask: UIInterfaceOrientationMask, request: UIInterfaceOrientationMask) {
        AppDelegate.orientationMask = mask

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        // 表示中の画面すべてに、許可する向きが変わったことを伝える
        var controller = scene.keyWindow?.rootViewController
        while let current = controller {
            current.setNeedsUpdateOfSupportedInterfaceOrientations()
            controller = current.presentedViewController
        }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: request)) { error in
            print("⚠️ orientation update failed: \(error)")
        }
    }
}
