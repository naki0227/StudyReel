import ActivityKit
import Foundation

// ロック画面と Dynamic Island に出す勉強中の表示。
// アプリ側（StudyTimerAndVideo/Models/StudyActivityAttributes.swift）にも同じ定義を置いている。片方を変えたらもう片方も合わせる
struct StudyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // タイマーの終わる時刻。ストップウォッチなら nil
        var timerEnd: Date?
        // ストップウォッチの数え始め（一時停止を除いて計算した見かけの開始時刻）
        var countingFrom: Date?
        // 一時停止中に表示する秒数
        var pausedSeconds: Int
        var isPaused: Bool
        var isRecording: Bool
    }

    var isTimer: Bool
}
