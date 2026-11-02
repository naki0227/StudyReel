import AVFoundation
import CoreImage
import SensitiveContentAnalysis
import Vision

// 仲間に出す10秒の動画。アプリに残した動画はモザイクなしのこともあるので、送る前に必ずここでモザイクをかけ直す
// - 0.2秒おきに顔（見つからなければ上半身の上の方）を探し、前後の枠を合わせて隠す
// - どのコマでも見つからなければ、画面の上6割を隠す（隠しすぎる側に倒す）
// - 送れるのは MosaickedClip だけ。これはこのファイルの中でしか作れないので、モザイクのない動画は送れない
struct MosaickedClip {
    let url: URL
    // 一覧に出す1コマ（モザイク済み）
    let thumbnail: CGImage

    fileprivate init(url: URL, thumbnail: CGImage) {
        self.url = url
        self.thumbnail = thumbnail
    }
}

enum BuddyClips {
    static let seconds: Double = 10
    private static let maxSide: CGFloat = 720
    private static let sampleStep: Double = 0.2
    private static let context = CIContext()

    // 動画の fraction（0〜1）の位置から10秒。作れなければ nil
    static func make(from source: URL, at fraction: Double) async -> MosaickedClip? {
        let asset = AVURLAsset(url: source)
        guard let duration = try? await asset.load(.duration).seconds, duration > 0.5,
              let track = try? await asset.loadTracks(withMediaType: .video).first,
              let natural = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else { return nil }
        let length = min(seconds, duration)
        let start = max(0, (duration - length) * min(max(fraction, 0), 1))
        let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: length, preferredTimescale: 600))

        let oriented = CGRect(origin: .zero, size: natural).applying(transform).size
        let scale = min(1, maxSide / max(abs(oriented.width), abs(oriented.height)))
        let size = CGSize(width: even(abs(oriented.width) * scale), height: even(abs(oriented.height) * scale))

        // 1回目：顔の位置だけ見る
        let samples = await hideSamples(asset: asset, start: start, length: length)
        let fallback = samples.flatMap(\.rects).isEmpty ? [CGRect(x: 0, y: 0.4, width: 1, height: 0.6)] : nil

        // 2回目：1コマずつモザイクをかけて書く
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString).mp4")
        guard let thumbnail = await write(asset: asset, track: track, transform: transform, range: range, size: size, to: url, rects: { time in
            fallback ?? rects(near: time, in: samples)
        }) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return MosaickedClip(url: url, thumbnail: thumbnail)
    }

    // 端末の「センシティブな内容の警告」がオンなら、送る前の動画を確かめる。オフなら判定できないので false
    static func isSensitive(_ clip: MosaickedClip) async -> Bool {
        await isSensitive(fileAt: clip.url)
    }

    static func isSensitive(fileAt url: URL) async -> Bool {
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else { return false }
        let handler = analyzer.videoAnalysis(forFileAt: url)
        return (try? await handler.hasSensitiveContent())?.isSensitive ?? false
    }

    // MARK: - 顔の位置

    private struct Sample {
        let time: Double
        let rects: [CGRect]   // Vision の座標（左下が原点、0〜1）
    }

    private static func hideSamples(asset: AVURLAsset, start: Double, length: Double) async -> [Sample] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
        var result: [Sample] = []
        var time = 0.0
        while time <= length {
            if let image = try? await generator.image(at: CMTime(seconds: start + time, preferredTimescale: 600)).image {
                result.append(Sample(time: time, rects: BuddyPhotos.hideRects(in: image)))
            }
            time += sampleStep
        }
        return result
    }

    // その時刻の前後のサンプルの枠をまとめて使う。前後とも見つかっていなければ、いちばん近くで見つかった枠
    private static func rects(near time: Double, in samples: [Sample]) -> [CGRect] {
        let near = samples.filter { abs($0.time - time) <= sampleStep * 1.5 }.flatMap(\.rects)
        if !near.isEmpty { return near }
        let found = samples.filter { !$0.rects.isEmpty }
        guard let closest = found.min(by: { abs($0.time - time) < abs($1.time - time) }) else { return [] }
        // 離れたところの枠なので、少し広げる
        return closest.rects.map { $0.insetBy(dx: -$0.width * 0.25, dy: -$0.height * 0.25) }
    }

    // MARK: - 書き出し

    private static func write(
        asset: AVURLAsset, track: AVAssetTrack, transform: CGAffineTransform, range: CMTimeRange,
        size: CGSize, to url: URL, rects: @escaping (Double) -> [CGRect]
    ) async -> CGImage? {
        guard let reader = try? AVAssetReader(asset: asset),
              let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        reader.timeRange = range
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return nil }
        reader.add(output)

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 1_200_000,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        guard reader.startReading(), writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        var thumbnail: CGImage?
        let extent = CGRect(origin: .zero, size: size)
        while let sample = output.copyNextSampleBuffer() {
            if Task.isCancelled { break }
            guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            let time = CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(sample), range.start)
            let frame = autoreleasepool { () -> CIImage in
                let image = orient(CIImage(cvPixelBuffer: buffer), transform: transform, to: size)
                return hide(image, rects: rects(time.seconds), extent: extent)
            }
            while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 5_000_000) }
            guard let pool = adaptor.pixelBufferPool else { break }
            var out: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &out)
            guard let out else { continue }
            context.render(frame, to: out, bounds: extent, colorSpace: CGColorSpaceCreateDeviceRGB())
            if thumbnail == nil { thumbnail = context.createCGImage(frame, from: extent) }
            adaptor.append(out, withPresentationTime: CMTimeMaximum(time, .zero))
        }
        input.markAsFinished()
        reader.cancelReading()
        await writer.finishWriting()
        guard writer.status == .completed, !Task.isCancelled else { return nil }
        return thumbnail
    }

    // 撮った向きに回して、size に合わせて縮める
    private static func orient(_ image: CIImage, transform: CGAffineTransform, to size: CGSize) -> CIImage {
        var oriented = image.transformed(by: transform)
        oriented = oriented.transformed(by: CGAffineTransform(translationX: -oriented.extent.minX, y: -oriented.extent.minY))
        let scale = min(size.width / oriented.extent.width, size.height / oriented.extent.height)
        return oriented.transformed(by: CGAffineTransform(scaleX: scale, y: scale)).cropped(to: CGRect(origin: .zero, size: size))
    }

    // モザイクのうえに少しぼかしを重ねる（コマを重ねて元に戻されにくくする）
    private static func hide(_ input: CIImage, rects: [CGRect], extent: CGRect) -> CIImage {
        guard !rects.isEmpty else { return input }
        let pixelated = input
            .clampedToExtent()
            .applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: max(extent.width, extent.height) / 28])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(extent.width, extent.height) / 120])
            .cropped(to: extent)
        var mask = CIImage(color: .black).cropped(to: extent)
        for normalized in rects {
            let rect = CGRect(x: normalized.minX * extent.width, y: normalized.minY * extent.height,
                              width: normalized.width * extent.width, height: normalized.height * extent.height)
            mask = CIImage(color: .white).cropped(to: rect.intersection(extent)).composited(over: mask)
        }
        return pixelated.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: input,
            kCIInputMaskImageKey: mask
        ])
    }

    private static func even(_ value: CGFloat) -> CGFloat {
        max(2, (value / 2).rounded(.down) * 2)
    }

    // MARK: - 受け取った動画（端末に24時間だけ置く）

    static func cacheURL(_ recordName: String) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("BuddyPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(recordName.replacingOccurrences(of: "/", with: "_") + ".mp4")
    }
}
