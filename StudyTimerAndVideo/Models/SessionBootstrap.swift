import Foundation

struct SessionBootstrap: Identifiable, Equatable {
    let id = UUID()
    let totalSeconds: Int
    let mode: Mode
    let startedAt: Date?
    let autoStart: Bool
    let initialRecordingEnabled: Bool
    let source: SessionLaunchSource
    // ホームで選んだ教材。保存画面で最初から選んでおく
    var materialID: UUID? = nil

    var elapsedSecondsAtLaunch: Int {
        guard let startedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(startedAt)))
    }
}
