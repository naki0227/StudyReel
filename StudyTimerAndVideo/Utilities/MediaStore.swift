import AVFoundation
import CoreImage
import UIKit

// アプリ内に残すサムネイルと動画。どちらも端末の中だけに置き、外部には送らない
enum MediaStore {
    static let keepVideoKey = "keep_video_in_app"

    static var keepsVideoInApp: Bool {
        UserDefaults.standard.object(forKey: keepVideoKey) as? Bool ?? true
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    private static let cache = NSCache<NSString, UIImage>()

    static func thumbnail(named name: String?) -> UIImage? {
        guard let name else { return nil }
        if let cached = cache.object(forKey: name as NSString) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: url(for: name).path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func videoURL(named name: String?) -> URL? {
        guard let name else { return nil }
        let url = url(for: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func delete(_ names: String?...) {
        for name in names.compactMap({ $0 }) {
            cache.removeObject(forKey: name as NSString)
            try? FileManager.default.removeItem(at: url(for: name))
        }
    }

    // 書き出した動画をアプリ内にコピーする（写真アプリから消しても見返せるように）
    static func storeVideo(copying source: URL) -> String? {
        let name = "\(UUID().uuidString).mov"
        do {
            try FileManager.default.copyItem(at: source, to: url(for: name))
            return name
        } catch {
            return nil
        }
    }

    // 素の録画から真ん中あたりの1コマを取り出し、顔にモザイクをかけて保存する
    static func makeThumbnail(from result: RecordingResult, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let name = renderThumbnail(from: result)
            DispatchQueue.main.async { completion(name) }
        }
    }

    private static func renderThumbnail(from result: RecordingResult) -> String? {
        let asset = AVURLAsset(url: result.url)
        let duration = asset.duration.seconds
        guard duration.isFinite, duration > 0 else { return nil }

        let time = duration * 0.5
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let frame = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil) else {
            return nil
        }

        let size = CGSize(width: frame.width, height: frame.height)
        var image = CIImage(cgImage: frame)
        // サムネイルは常に顔を隠す。少し広めにとる
        if let rect = result.track.rect(at: time) {
            let wider = FaceTrack.apply(FaceAdjustment(scale: 1.15), to: rect)
            image = VideoExporter.mosaic(image, in: VideoExporter.ciRect(for: wider, canvasSize: size), canvasSize: size)
        }

        let scale = 640 / max(size.width, size.height)
        let scaled = image.cropped(to: CGRect(origin: .zero, size: size))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let output = CIContext().createCGImage(scaled, from: scaled.extent),
              let data = UIImage(cgImage: output).jpegData(compressionQuality: 0.82) else { return nil }

        let name = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: url(for: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }
}

// 録画後に保存画面へ渡すもの
struct SessionMedia {
    var thumbnailFileName: String?
    var videoFileName: String?

    func discard() {
        MediaStore.delete(thumbnailFileName, videoFileName)
    }
}
