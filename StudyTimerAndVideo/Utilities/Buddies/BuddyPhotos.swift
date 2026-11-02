import AVFoundation
import CloudKit
import CoreImage
import SensitiveContentAnalysis
import UIKit
import Vision
#if canImport(DeclaredAgeRange)
import DeclaredAgeRange
#endif

// 勉強仲間に見せる1コマ。自分のタイムラプスから選んだ瞬間だけで、カメラロールの写真は使えない
// - 顔（見つからなければ頭のあたり）にモザイクをかけてから送る
// - 端末の「センシティブな内容の警告」がオンなら、裸などの画像は送れない・受け取っても出さない
// - 24時間で消える
enum BuddyPhotos {
    static let lifetime: TimeInterval = 24 * 3600
    private static let maxSide: CGFloat = 1080
    private static let context = CIContext()

    // MARK: - タイムラプスから1コマ取り出す

    static func frame(from url: URL, at fraction: Double) async -> CGImage? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration), duration.seconds > 0 else { return nil }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxSide, height: maxSide)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        let time = CMTime(seconds: duration.seconds * min(max(fraction, 0), 0.999), preferredTimescale: 600)
        return try? await generator.image(at: time).image
    }

    // MARK: - 顔にモザイク

    static func mosaicked(_ image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        let extent = input.extent
        let rects = hideRects(in: image).map { normalized in
            CGRect(x: normalized.minX * extent.width, y: normalized.minY * extent.height,
                   width: normalized.width * extent.width, height: normalized.height * extent.height)
        }
        guard !rects.isEmpty else { return image }
        let pixelated = input
            .clampedToExtent()
            .applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: max(extent.width, extent.height) / 28])
            .cropped(to: extent)
        var mask = CIImage(color: .black).cropped(to: extent)
        for rect in rects {
            mask = CIImage(color: .white).cropped(to: rect.intersection(extent)).composited(over: mask)
        }
        let output = pixelated.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: input,
            kCIInputMaskImageKey: mask,
        ])
        return context.createCGImage(output, from: extent)
    }

    // Vision の座標（左下が原点、0〜1）で、隠す範囲を返す。顔は少し広めに、顔が見つからなければ上半身の上の方を隠す
    static func hideRects(in image: CGImage) -> [CGRect] {
        let faces = VNDetectFaceRectanglesRequest()
        let bodies = VNDetectHumanRectanglesRequest()
        bodies.upperBodyOnly = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([faces, bodies])
        let faceRects = (faces.results ?? []).map { face -> CGRect in
            let box = face.boundingBox
            return box.insetBy(dx: -box.width * 0.35, dy: -box.height * 0.45)
        }
        if !faceRects.isEmpty { return faceRects }
        return (bodies.results ?? []).map { body -> CGRect in
            let box = body.boundingBox
            let height = box.height * 0.55
            return CGRect(x: box.minX - box.width * 0.1, y: box.maxY - height, width: box.width * 1.2, height: height + box.height * 0.1)
        }
    }

    static func jpeg(_ image: CGImage) -> Data? {
        UIImage(cgImage: image).jpegData(compressionQuality: 0.7)
    }

    // MARK: - センシティブな内容

    // 端末の設定がオフのとき（アプリからは変えられない）は判定できないので false を返す
    static func isSensitive(_ image: CGImage) async -> Bool {
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else { return false }
        return (try? await analyzer.analyzeImage(image))?.isSensitive ?? false
    }

    // MARK: - 受け取った写真（端末に24時間だけ置く）

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("BuddyPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func cacheURL(_ recordName: String) -> URL {
        cacheDirectory.appendingPathComponent(recordName.replacingOccurrences(of: "/", with: "_") + ".jpg")
    }

    static func store(_ data: Data, for recordName: String) {
        try? data.write(to: cacheURL(recordName))
    }

    static func remove(_ recordName: String) {
        try? FileManager.default.removeItem(at: cacheURL(recordName))
    }

    static func clearOldCache() {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for file in files {
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            if Date().timeIntervalSince(created) > lifetime { try? manager.removeItem(at: file) }
        }
    }

    // 写真の画像を取ってくる。センシティブと判定されたものは nil（出さない）
    @MainActor
    static func data(for photo: BuddyCloud.Photo, in group: BuddyCloud.Group) async -> Data? {
        let url = cacheURL(photo.recordName)
        var data = try? Data(contentsOf: url)
        if data == nil {
            let cloud = BuddyCloud.shared
            let id = CKRecord.ID(recordName: photo.recordName, zoneID: group.zoneID)
            guard let record = try? await cloud.database(for: group).record(for: id),
                  let asset = record["image"] as? CKAsset, let file = asset.fileURL,
                  let fetched = try? Data(contentsOf: file) else { return nil }
            store(fetched, for: photo.recordName)
            data = fetched
        }
        guard let data, let image = UIImage(data: data)?.cgImage else { return nil }
        if await isSensitive(image) { return nil }
        return data
    }

    // 10秒の動画を取ってくる。端末に24時間置き、センシティブと判定されたものは nil
    @MainActor
    static func clipURL(for photo: BuddyCloud.Photo, in group: BuddyCloud.Group) async -> URL? {
        guard photo.isClip else { return nil }
        let url = BuddyClips.cacheURL(photo.recordName)
        if !FileManager.default.fileExists(atPath: url.path) {
            let id = CKRecord.ID(recordName: photo.recordName, zoneID: group.zoneID)
            guard let results = try? await BuddyCloud.shared.database(for: group).records(for: [id], desiredKeys: ["clip"]),
                  case .success(let record)? = results[id],
                  let asset = record["clip"] as? CKAsset, let file = asset.fileURL else { return nil }
            try? FileManager.default.removeItem(at: url)
            guard (try? FileManager.default.copyItem(at: file, to: url)) != nil else { return nil }
        }
        if await BuddyClips.isSensitive(fileAt: url) {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return url
    }

    // MARK: - 年齢の範囲（iOS 26）

    // 本人や保護者が許したときだけ、18歳未満かどうかが分かる。分かったら写真を初期オフにする
    @MainActor
    static func checkAgeIfNeeded() async {
        let key = "buddy_age_checked"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        #if canImport(DeclaredAgeRange)
        if #available(iOS 26.0, *) {
            guard let controller = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
            var top = controller
            while let presented = top.presentedViewController { top = presented }
            do {
                let response = try await AgeRangeService.shared.requestAgeRange(ageGates: 18, in: top)
                if case .sharing(let range) = response {
                    if let upper = range.upperBound, upper < 18 {
                        BuddyProfile.isUnder18 = true
                    } else if let lower = range.lowerBound, lower >= 18 {
                        BuddyProfile.isUnder18 = false
                    }
                }
                UserDefaults.standard.set(true, forKey: key)
            } catch {
                // 使えない端末・設定のときは、分からないままにする
            }
        }
        #endif
    }
}

// 通報の理由
enum BuddyReportReason: String, CaseIterable, Identifiable {
    case name, photo, harassment, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return L10n.string("名前やグループ名がよくない")
        case .photo: return L10n.string("写真・動画がよくない")
        case .harassment: return L10n.string("いやがらせ")
        case .other: return L10n.string("その他")
        }
    }
}
