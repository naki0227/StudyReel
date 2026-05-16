import Foundation

enum SessionLaunchSource: String, Codable {
    case app
    case widget
    case notification
}

struct CurrentSessionDraft: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let startedAt: Date
    let plannedDurationSeconds: Int
    let mode: String
    let source: SessionLaunchSource
    let shouldRecordTimelapse: Bool
    let requiresClassificationAfterFinish: Bool

    var resolvedMode: Mode {
        mode == "stopwatch" ? .stopwatch : .timer
    }

    static func timer(
        durationSeconds: Int,
        source: SessionLaunchSource,
        shouldRecordTimelapse: Bool
    ) -> CurrentSessionDraft {
        CurrentSessionDraft(
            id: UUID(),
            createdAt: Date(),
            startedAt: Date(),
            plannedDurationSeconds: durationSeconds,
            mode: "timer",
            source: source,
            shouldRecordTimelapse: shouldRecordTimelapse,
            requiresClassificationAfterFinish: true
        )
    }

    static func stopwatch(
        source: SessionLaunchSource,
        shouldRecordTimelapse: Bool
    ) -> CurrentSessionDraft {
        CurrentSessionDraft(
            id: UUID(),
            createdAt: Date(),
            startedAt: Date(),
            plannedDurationSeconds: 0,
            mode: "stopwatch",
            source: source,
            shouldRecordTimelapse: shouldRecordTimelapse,
            requiresClassificationAfterFinish: true
        )
    }
}

final class CurrentSessionDraftStore: ObservableObject {
    static let appGroupKey = "group.com.ni.StudyTimerAndVideo"
    private static let draftKey = "current_session_draft"

    @Published private(set) var pendingDraft: CurrentSessionDraft?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        reload()
    }

    func reload() {
        let userDefaults = UserDefaults(suiteName: Self.appGroupKey) ?? .standard
        guard let data = userDefaults.data(forKey: Self.draftKey) else {
            pendingDraft = nil
            return
        }

        pendingDraft = try? decoder.decode(CurrentSessionDraft.self, from: data)
    }

    func save(_ draft: CurrentSessionDraft) {
        let userDefaults = UserDefaults(suiteName: Self.appGroupKey) ?? .standard
        guard let data = try? encoder.encode(draft) else { return }
        userDefaults.set(data, forKey: Self.draftKey)
        pendingDraft = draft
    }

    @discardableResult
    func consumePendingDraft() -> CurrentSessionDraft? {
        reload()
        let draft = pendingDraft
        clear()
        return draft
    }

    func clear() {
        let userDefaults = UserDefaults(suiteName: Self.appGroupKey) ?? .standard
        userDefaults.removeObject(forKey: Self.draftKey)
        pendingDraft = nil
    }
}
