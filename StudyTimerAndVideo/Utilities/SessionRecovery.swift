import CoreGraphics
import Foundation

// 勉強中にアプリが終了してしまったときのための控え。
// 画面側が時間を、録画側が動画の場所と顔の位置を、それぞれ数秒〜30秒おきに書き残す。
// 次に開いたとき残っていれば、そこまでの記録を保存できるようにする
struct SessionRecoveryInfo: Codable {
    var startedAt: Date
    var elapsedSeconds: Int
    var isTimer: Bool
    var updatedAt: Date
}

struct RecordingRecoveryInfo: Codable {
    var videoPath: String
    var canvasWidth: Double
    var canvasHeight: Double
    var sessionStart: Date
    var isRealTime: Bool
    var samples: [FaceSample]
    // 机を離れていた時間（秒）。書き終えたあとの控えにだけ入る。古い控えには無い
    var awaySeconds: Int?
}

enum SessionRecovery {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Recovery", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var sessionURL: URL { directory.appendingPathComponent("session.json") }
    private static var recordingURL: URL { directory.appendingPathComponent("recording.json") }

    static func saveSession(_ info: SessionRecoveryInfo) {
        write(info, to: sessionURL)
    }

    static func saveRecording(_ info: RecordingRecoveryInfo) {
        write(info, to: recordingURL)
    }

    // 録画を書き終えたあとも、確認画面で保存し終えるまで控えを残す。
    // 確認画面や書き出しの途中でアプリが落ちても、次に開いたとき動画ごと保存し直せるように
    static func saveRecording(_ result: RecordingResult) {
        saveRecording(RecordingRecoveryInfo(
            videoPath: result.url.path,
            canvasWidth: result.canvasSize.width,
            canvasHeight: result.canvasSize.height,
            sessionStart: result.sessionStart,
            isRealTime: result.track.isRealTime,
            samples: result.track.samples,
            awaySeconds: result.awaySeconds
        ))
    }

    static func clearSession() {
        try? FileManager.default.removeItem(at: sessionURL)
    }

    static func clearRecording() {
        try? FileManager.default.removeItem(at: recordingURL)
    }

    static var pendingSession: SessionRecoveryInfo? {
        read(SessionRecoveryInfo.self, from: sessionURL)
    }

    // 書きかけの動画が読めるときだけ、確認画面に渡せる形で返す
    static var pendingRecording: RecordingResult? {
        guard let info = read(RecordingRecoveryInfo.self, from: recordingURL) else { return nil }
        // 一時フォルダの場所は起動ごとに変わることがあるので、ファイル名で探し直す
        let fileName = URL(fileURLWithPath: info.videoPath).lastPathComponent
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var track = FaceTrack(samples: info.samples)
        track.isRealTime = info.isRealTime
        var result = RecordingResult(
            url: url,
            canvasSize: CGSize(width: info.canvasWidth, height: info.canvasHeight),
            sessionStart: info.sessionStart,
            track: track
        )
        result.awaySeconds = info.awaySeconds
        return result
    }

    // 保存しないと決めたときは、書きかけの動画も消す
    static func discardAll() {
        if let recording = pendingRecording {
            try? FileManager.default.removeItem(at: recording.url)
        }
        clearRecording()
        clearSession()
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
