import FamilyControls
import Foundation
import ManagedSettings

// 撮影している間だけ、選んだアプリ（Instagram・TikTok など）を開けなくする。iPhone のスクリーンタイムの仕組みを使う。
// - 本人の iPhone で本人が許可する（保護者の承認は要らない）
// - どのアプリを選んだかは iOS が持っていて、StudyReel には中身が分からない形（トークン）でしか渡らない
// - 撮影を終えると元に戻す。アプリが途中で落ちたときは、次に開いたときに戻す
@MainActor
final class FocusShield: ObservableObject {
    static let shared = FocusShield()

    // Apple からスクリーンタイムの機能（Family Controls Distribution）の許可が下りた（2026-11）。
    // entitlements に com.apple.developer.family-controls を入れてある。困ったときは false にすれば画面から消える
    static let isAvailableInBuild = true

    static let enabledKey = "focus_shield_enabled"
    private static let selectionKey = "focus_shield_selection"

    @Published private(set) var isAuthorized = false
    @Published var selection = FamilyActivitySelection() {
        didSet { saveSelection() }
    }

    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("studyreel.recording"))

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.selectionKey),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        }
        refreshStatus()
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    // 選んだアプリとカテゴリの数（設定の画面に出す）
    var selectionCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    func refreshStatus() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // 許可を求める。断られたり使えなかったりしたら false
    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            refreshStatus()
            return false
        }
        refreshStatus()
        return isAuthorized
    }

    // 撮影を始めたとき
    func startRecording() {
        guard Self.isAvailableInBuild, isEnabled, isAuthorized, hasSelection else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    // 撮影を終えたとき・やめたとき・アプリを開いたとき
    func stopRecording() {
        guard Self.isAvailableInBuild else { return }
        store.clearAllSettings()
    }

    private func saveSelection() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: Self.selectionKey)
    }
}
