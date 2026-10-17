import AVFoundation
import CoreImage
import Foundation

// 04 フィルター。プレビューと書き出しの両方で同じ処理を使う
enum VideoFilter: String, CaseIterable, Identifiable {
    case none
    case clear
    case film
    case cozy
    case mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return L10n.string("なし")
        case .clear: return "Clear"
        case .film: return "Film"
        case .cozy: return "Cozy"
        case .mono: return "Mono"
        }
    }

    func apply(to image: CIImage) -> CIImage {
        let extent = image.extent
        switch self {
        case .none:
            return image
        case .clear:
            // 少し明るく、青みを足して透明感を出す
            return image
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 7300, y: 0)
                ])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputBrightnessKey: 0.03,
                    kCIInputContrastKey: 0.95,
                    kCIInputSaturationKey: 1.02
                ])
                .cropped(to: extent)
        case .film:
            // 黒を少し持ち上げて、彩度を抑えた暖かい色に
            return image
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 5900, y: 10)
                ])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.06,
                    kCIInputSaturationKey: 0.82
                ])
                .applyingFilter("CIToneCurve", parameters: [
                    "inputPoint0": CIVector(x: 0, y: 0.07),
                    "inputPoint1": CIVector(x: 0.25, y: 0.27),
                    "inputPoint2": CIVector(x: 0.5, y: 0.52),
                    "inputPoint3": CIVector(x: 0.75, y: 0.76),
                    "inputPoint4": CIVector(x: 1, y: 0.95)
                ])
                .cropped(to: extent)
        case .cozy:
            // 暖かい色と、周りを少し暗くするビネット
            return image
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 5200, y: 0)
                ])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 1.08,
                    kCIInputBrightnessKey: 0.01
                ])
                .applyingFilter("CIVignette", parameters: [
                    kCIInputIntensityKey: 0.55,
                    kCIInputRadiusKey: max(extent.width, extent.height) * 0.0012
                ])
                .cropped(to: extent)
        case .mono:
            return image
                .applyingFilter("CIPhotoEffectMono")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.08])
                .cropped(to: extent)
        }
    }
}

// 04 BGM。曲は tools/bgm のスクリプトで作ったオリジナル
enum BGMTrack: String, CaseIterable, Identifiable {
    case none
    case morning
    case coffeeTime
    case lofiStudy
    case piano

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return L10n.string("なし")
        case .morning: return "Morning"
        case .coffeeTime: return "Coffee Time"
        case .lofiStudy: return "Lo-fi Study"
        case .piano: return "Piano"
        }
    }

    // Morning と Lo-fi Study は無料、残りは Pro
    var isPro: Bool {
        self == .coffeeTime || self == .piano
    }

    var url: URL? {
        let name: String
        switch self {
        case .none: return nil
        case .morning: name = "Morning"
        case .coffeeTime: name = "CoffeeTime"
        case .lofiStudy: name = "LofiStudy"
        case .piano: name = "Piano"
        }
        return Bundle.main.url(forResource: name, withExtension: "m4a")
    }
}

enum BGMRenderer {
    static let volume: Float = 0.8

    // 動画の長さに合わせて曲をくり返し、最初と最後をなめらかに出し入れした音声ファイルを作る
    static func render(_ track: BGMTrack, duration: Double) -> URL? {
        guard let source = track.url, duration > 0,
              let file = try? AVAudioFile(forReading: source) else { return nil }

        let format = file.processingFormat
        let totalFrames = AVAudioFramePosition(duration * format.sampleRate)
        let fadeIn = AVAudioFramePosition(0.4 * format.sampleRate)
        let fadeOut = min(AVAudioFramePosition(2.0 * format.sampleRate), totalFrames / 3)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("studyreel-bgm-\(UUID().uuidString).caf")

        do {
            let output = try AVAudioFile(forWriting: outputURL, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else { return nil }

            var written: AVAudioFramePosition = 0
            while written < totalFrames {
                if file.framePosition >= file.length {
                    file.framePosition = 0
                }
                let remaining = AVAudioFrameCount(min(Int64(buffer.frameCapacity), totalFrames - written))
                try file.read(into: buffer, frameCount: remaining)
                let frames = Int(buffer.frameLength)
                if frames == 0 {
                    file.framePosition = 0
                    continue
                }

                if let channels = buffer.floatChannelData {
                    for frame in 0..<frames {
                        let position = written + AVAudioFramePosition(frame)
                        var gain = volume
                        if position < fadeIn {
                            gain *= Float(position) / Float(fadeIn)
                        }
                        let fromEnd = totalFrames - position
                        if fromEnd < fadeOut {
                            gain *= Float(fromEnd) / Float(fadeOut)
                        }
                        for channel in 0..<Int(format.channelCount) {
                            channels[channel][frame] *= gain
                        }
                    }
                }

                try output.write(from: buffer)
                written += AVAudioFramePosition(frames)
            }
            output.close()
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            return nil
        }
    }
}
