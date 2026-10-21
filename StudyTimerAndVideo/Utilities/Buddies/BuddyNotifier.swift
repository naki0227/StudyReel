import Foundation
import UIKit
import UserNotifications

// 勉強仲間の通知。CloudKit の静かなプッシュで目を覚まし、新しく届いたスタンプや、仲間が勉強を始めたことを端末の中で通知する
// 一度見たものは覚えておき、同じ通知を二度出さない
@MainActor
enum BuddyNotifier {
    private static let seenStampsKey = "buddy_seen_stamps"
    private static let seenStudyKey = "buddy_seen_study"
    private static let primedKey = "buddy_notifier_primed"

    static func registerForPush() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // 通知を出してよいか、初めてグループに入ったときに聞く
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // post が false のとき（アプリを開いて読み込んだとき）は、見たことにするだけで通知は出さない
    static func process(groups: [BuddyCloud.Group], me: String?, blocked: Set<String>, post: Bool) {
        guard let me else { return }
        let defaults = UserDefaults.standard
        var seenStamps = Set(defaults.stringArray(forKey: seenStampsKey) ?? [])
        var seenStudy = Set(defaults.stringArray(forKey: seenStudyKey) ?? [])
        // 初めて読み込んだときは、今あるものを全部見たことにする
        let primed = defaults.bool(forKey: primedKey)
        let shouldPost = post && primed

        for group in groups {
            let names = Dictionary(group.members.map { ($0.userRecordName, $0.nickname) }, uniquingKeysWith: { first, _ in first })
            for stamp in group.stamps where stamp.to == me && !seenStamps.contains(stamp.recordName) {
                seenStamps.insert(stamp.recordName)
                guard shouldPost, BuddyProfile.notifiesStamps, !blocked.contains(stamp.from) else { continue }
                notify(
                    id: stamp.recordName,
                    title: group.name,
                    body: L10n.format("%@さんから「%@」", names[stamp.from] ?? "", stamp.kind.title)
                )
            }
            for member in group.members where member.userRecordName != me && member.isStudyingNow {
                guard let since = member.studyingSince else { continue }
                let key = "\(member.userRecordName)-\(Int(since.timeIntervalSince1970))"
                guard !seenStudy.contains(key) else { continue }
                seenStudy.insert(key)
                guard shouldPost, BuddyProfile.notifiesStudying, !blocked.contains(member.userRecordName) else { continue }
                notify(id: key, title: group.name, body: L10n.format("%@さんが勉強を始めました", member.nickname))
            }
        }
        defaults.set(Array(Array(seenStamps).suffix(500)), forKey: seenStampsKey)
        defaults.set(Array(Array(seenStudy).suffix(500)), forKey: seenStudyKey)
        defaults.set(true, forKey: primedKey)
    }

    private static func notify(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: "buddy-" + id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
