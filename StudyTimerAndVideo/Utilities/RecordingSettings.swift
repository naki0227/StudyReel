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

    static let intervalOptions: [Double] = [2, 5, 10, 30]

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
