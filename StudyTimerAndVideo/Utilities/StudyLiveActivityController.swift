import ActivityKit
import Foundation

// 勉強中のロック画面・Dynamic Island の表示を出したり消したりする
@MainActor
final class StudyLiveActivityController {
    static let shared = StudyLiveActivityController()

    private var activity: Activity<StudyActivityAttributes>?

    private init() {}

    // タイマーなら残り秒数、ストップウォッチなら経過秒数を渡す
    func start(isTimer: Bool, seconds: Int, isRecording: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAll()

        let attributes = StudyActivityAttributes(isTimer: isTimer)
        let content = ActivityContent(state: state(isTimer: isTimer, seconds: seconds, isPaused: false, isRecording: isRecording), staleDate: nil)
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    func update(isTimer: Bool, seconds: Int, isPaused: Bool, isRecording: Bool) {
        guard let activity else { return }
        let content = ActivityContent(state: state(isTimer: isTimer, seconds: seconds, isPaused: isPaused, isRecording: isRecording), staleDate: nil)
        Task {
            await activity.update(content)
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // 前回アプリが落ちたときなどに残った表示も消す
    func endAll() {
        activity = nil
        for leftover in Activity<StudyActivityAttributes>.activities {
            Task {
                await leftover.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func state(isTimer: Bool, seconds: Int, isPaused: Bool, isRecording: Bool) -> StudyActivityAttributes.ContentState {
        let now = Date()
        return StudyActivityAttributes.ContentState(
            timerEnd: isTimer ? now.addingTimeInterval(TimeInterval(seconds)) : nil,
            countingFrom: isTimer ? nil : now.addingTimeInterval(-TimeInterval(seconds)),
            pausedSeconds: seconds,
            isPaused: isPaused,
            isRecording: isRecording
        )
    }
}
