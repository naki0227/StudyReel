import CoreGraphics
import Foundation

// 顔の隠し方。スタンプは Pro
enum FaceHideStyle: String, CaseIterable, Identifiable {
    case mosaic
    case stamp

    static let storageKey = "face_hide_style"

    var id: String { rawValue }

    var isPro: Bool { self == .stamp }

    var title: String {
        switch self {
        case .mosaic: return L10n.string("モザイク")
        case .stamp: return L10n.string("スタンプ")
        }
    }

    static func resolved(rawValue: String, isPro: Bool) -> FaceHideStyle {
        let style = FaceHideStyle(rawValue: rawValue) ?? .mosaic
        return style.isPro && !isPro ? .mosaic : style
    }
}

enum FaceStamp {
    static let storageKey = "face_stamp"
    static let options = ["😊", "🐱", "🐻", "📚", "✏️", "⭐️"]
    static let defaultStamp = options[0]
}

// 書き出す動画の組み合わせ
enum VideoSaveOption: String, CaseIterable, Identifiable {
    case hidden
    case plain
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hidden: return L10n.string("モザイクあり")
        case .plain: return L10n.string("モザイクなし")
        case .both: return L10n.string("両方")
        }
    }
}

struct FaceSample {
    let time: Double     // 動画上の秒
    let elapsed: Double  // その時点までの勉強時間（秒）
    let rect: CGRect     // 動画に対する 0〜1 の座標（左上原点）
    let segment: Int     // 検出状態が切り替わるごとに増える区間番号
}

// 確認画面でユーザーが動かした量。区間ごとに持つ
struct FaceAdjustment {
    var offset: CGSize = .zero
    var scale: CGFloat = 1
}

struct FaceTrack {
    var samples: [FaceSample] = []
    var adjustments: [Int: FaceAdjustment] = [:]
    // 全部録画は動画の秒と勉強時間が同じ速さで進む。タイムラプスは1フレームごとに記録してある
    var isRealTime = false

    func segment(at time: Double) -> Int? {
        sampleIndex(at: time).map { samples[$0].segment }
    }

    func rect(at time: Double) -> CGRect? {
        guard let base = baseRect(at: time) else { return nil }
        return Self.apply(adjustments[base.1] ?? FaceAdjustment(), to: base.0)
    }

    func baseRect(at time: Double) -> (CGRect, Int)? {
        guard let index = sampleIndex(at: time) else { return nil }
        let a = samples[index]
        if index + 1 < samples.count {
            let b = samples[index + 1]
            if b.segment == a.segment, b.time > a.time, time > a.time {
                let t = CGFloat(min(1, (time - a.time) / (b.time - a.time)))
                return (Self.lerp(a.rect, b.rect, t), a.segment)
            }
        }
        return (a.rect, a.segment)
    }

    func elapsed(at time: Double) -> Double {
        guard let index = sampleIndex(at: time) else { return 0 }
        let sample = samples[index]
        return sample.elapsed + (isRealTime ? max(0, time - sample.time) : 0)
    }

    private func sampleIndex(at time: Double) -> Int? {
        guard !samples.isEmpty else { return nil }
        var low = 0
        var high = samples.count - 1
        guard samples[0].time <= time else { return 0 }
        while low < high {
            let mid = (low + high + 1) / 2
            if samples[mid].time <= time {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    static func apply(_ adjustment: FaceAdjustment, to rect: CGRect) -> CGRect {
        let width = rect.width * adjustment.scale
        let height = rect.height * adjustment.scale
        let center = CGPoint(x: rect.midX + adjustment.offset.width, y: rect.midY + adjustment.offset.height)
        return clamp(CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
    }

    static func clamp(_ rect: CGRect) -> CGRect {
        let width = min(max(rect.width, 0.02), 1)
        let height = min(max(rect.height, 0.02), 1)
        let x = min(max(rect.minX, 0), 1 - width)
        let y = min(max(rect.minY, 0), 1 - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func lerp(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(
            x: a.minX + (b.minX - a.minX) * t,
            y: a.minY + (b.minY - a.minY) * t,
            width: a.width + (b.width - a.width) * t,
            height: a.height + (b.height - a.height) * t
        )
    }
}

// 録画が終わったときに確認画面へ渡すもの
struct RecordingResult: Identifiable {
    let id = UUID()
    let url: URL
    let canvasSize: CGSize
    let sessionStart: Date
    var track: FaceTrack
}
