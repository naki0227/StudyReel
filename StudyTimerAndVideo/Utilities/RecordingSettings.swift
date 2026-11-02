import AVFoundation
import CoreGraphics
import Foundation

// 設定画面で変える撮影・保存の設定。録画やプレビューの画面からも同じキーで読む
enum RecordingSettings {
    static let intervalKey = "capture_interval"
    static let cameraKey = "camera_position"
    static let qualityKey = "video_quality"
    static let showLogoKey = "show_logo"
    static let autoMosaicKey = "auto_mosaic"
    static let saveToPhotosKey = "save_to_photos"

    // 6秒は「1分が1秒」（10fps で書き出すので、間隔×10倍の速さになる）
    static let intervalOptions: [Double] = [2, 5, 6, 10, 30]
    static let outputFrameRate: Double = 10

    // 1時間撮ったときの動画の長さ（秒）
    static func videoSecondsPerHour(interval: Double) -> Int {
        Int((3600 / interval / outputFrameRate).rounded())
    }

    // 1時間撮ったときの動画の長さ（「1分12秒」）
    static func lengthPerHour(interval: Double) -> String {
        let seconds = videoSecondsPerHour(interval: interval)
        if seconds < 60 { return L10n.format("%d秒", seconds) }
        return seconds % 60 == 0 ? L10n.format("%d分", seconds / 60) : L10n.format("%d分%d秒", seconds / 60, seconds % 60)
    }

    // 「1時間 → 1分12秒」のような見せ方。6秒は「1分が1秒」
    static func speedTitle(interval: Double) -> String {
        interval == 6 ? L10n.string("1分が1秒") : L10n.format("1時間 → %@", lengthPerHour(interval: interval))
    }

    static var interval: Double {
        let value = UserDefaults.standard.double(forKey: intervalKey)
        return intervalOptions.contains(value) ? value : 5
    }

    static var camera: CameraPosition {
        CameraPosition(rawValue: UserDefaults.standard.string(forKey: cameraKey) ?? "") ?? .front
    }

    static var quality: VideoQuality {
        VideoQuality(rawValue: UserDefaults.standard.string(forKey: qualityKey) ?? "") ?? .hd1080
    }

    static var autoMosaic: Bool {
        UserDefaults.standard.object(forKey: autoMosaicKey) as? Bool ?? true
    }

    static var savesToPhotos: Bool {
        UserDefaults.standard.object(forKey: saveToPhotosKey) as? Bool ?? true
    }

    // ロゴ（透かし）は無料版では必ず入る。Pro は設定で選べる
    static func showsWatermark(isPro: Bool) -> Bool {
        guard isPro else { return true }
        return UserDefaults.standard.bool(forKey: showLogoKey)
    }
}

enum CameraPosition: String, CaseIterable, Identifiable {
    case front
    case back

    var id: String { rawValue }

    var title: String {
        switch self {
        case .front: return L10n.string("前面カメラ")
        case .back: return L10n.string("背面カメラ")
        }
    }

    var avPosition: AVCaptureDevice.Position {
        self == .front ? .front : .back
    }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case hd720
    case hd1080

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hd720: return "720p"
        case .hd1080: return "1080p"
        }
    }

    // 横向きのときのサイズ。縦向きは幅と高さを入れ替える
    var landscapeSize: CGSize {
        switch self {
        case .hd720: return CGSize(width: 1280, height: 720)
        case .hd1080: return CGSize(width: 1920, height: 1080)
        }
    }
}
