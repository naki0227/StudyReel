import AVFoundation
import CoreImage
import UIKit

// Vlogで使う期間（週か月）
enum WeeklyVlogWeek: String, CaseIterable, Identifiable {
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth

    var isMonth: Bool { self == .thisMonth || self == .lastMonth }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisWeek: return L10n.string("今週")
        case .lastWeek: return L10n.string("先週")
        case .thisMonth: return L10n.string("今月")
        case .lastMonth: return L10n.string("先月")
        }
    }

    var headline: String {
        switch self {
        case .thisWeek: return L10n.string("今週の勉強")
        case .lastWeek: return L10n.string("先週の勉強")
        case .thisMonth: return L10n.string("今月の勉強")
        case .lastMonth: return L10n.string("先月の勉強")
        }
    }

    func interval(calendar: Calendar = .current, now: Date = Date()) -> DateInterval? {
        if isMonth {
            guard let month = calendar.dateInterval(of: .month, for: now) else { return nil }
            if self == .thisMonth { return month }
            guard let start = calendar.date(byAdding: .month, value: -1, to: month.start) else { return nil }
            return DateInterval(start: start, end: month.start)
        }
        guard let current = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        switch self {
        case .thisWeek:
            return current
        case .lastWeek:
            guard let start = calendar.date(byAdding: .day, value: -7, to: current.start) else { return nil }
            return DateInterval(start: start, end: current.start)
        case .thisMonth, .lastMonth:
            return nil
        }
    }
}

enum WeeklyVlogOrientation: String, CaseIterable, Identifiable {
    case portrait
    case landscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portrait: return L10n.string("縦向き")
        case .landscape: return L10n.string("横向き")
        }
    }

    var canvasSize: CGSize {
        switch self {
        case .portrait: return CGSize(width: 1080, height: 1920)
        case .landscape: return CGSize(width: 1920, height: 1080)
        }
    }
}

// Vlog に入れる1本ぶん。SwiftData のモデルは別スレッドに渡せないので、必要な値だけ取り出しておく
struct WeeklyVlogClip {
    let videoURL: URL
    let date: Date
    let studySeconds: Int

    init?(session: StudySession) {
        guard let url = MediaStore.videoURL(named: session.videoFileName) else { return nil }
        videoURL = url
        date = session.date
        studySeconds = session.duration
    }
}

struct WeeklyVlogOptions {
    var orientation: WeeklyVlogOrientation
    var bgm: BGMTrack
    var font: OverlayFont
    var showsWatermark: Bool
    var headline: String
}

enum WeeklyVlogError: Error {
    case noClips
    case failed
}

// 1週間ぶんの動画を、日付の文字とBGMを付けて30〜60秒くらいの1本にまとめる
enum WeeklyVlogMaker {
    static let frameRate: Int32 = 30
    static let titleSeconds = 1.5

    static func clips(from sessions: [StudySession], in week: WeeklyVlogWeek) -> [WeeklyVlogClip] {
        guard let interval = week.interval() else { return [] }
        let clips = sessions
            .filter { interval.contains($0.date) }
            .sorted { $0.date < $1.date }
            .compactMap(WeeklyVlogClip.init(session:))
        guard week.isMonth else { return clips }
        // 1か月は日ごとに1本（その日いちばん長く勉強した記録）にして、60秒に収まるようにする
        let calendar = Calendar.current
        var byDay: [Date: WeeklyVlogClip] = [:]
        for clip in clips {
            let day = calendar.startOfDay(for: clip.date)
            if let current = byDay[day], current.studySeconds >= clip.studySeconds { continue }
            byDay[day] = clip
        }
        return byDay.values.sorted { $0.date < $1.date }
    }

    static func durationText(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 && minutes > 0 { return L10n.format("%d時間%d分", hours, minutes) }
        if hours > 0 { return L10n.format("%d時間", hours) }
        return L10n.format("%d分", minutes)
    }

    // 別スレッドで作る。Task をキャンセルすると途中でやめて、作りかけのファイルは消す
    static func make(
        clips: [WeeklyVlogClip],
        options: WeeklyVlogOptions,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard !clips.isEmpty else { throw WeeklyVlogError.noClips }

        var durations: [Double] = []
        for clip in clips {
            let asset = AVURLAsset(url: clip.videoURL)
            let seconds = (try? await asset.load(.duration))?.seconds ?? 0
            durations.append(seconds.isFinite ? seconds : 0)
        }
        let plan = allocate(clips: clips, sourceDurations: durations)
        let total = titleSeconds + plan.reduce(0, +)

        let silentURL = FileManager.default.temporaryDirectory.appendingPathComponent("studyreel-week-\(UUID().uuidString).mp4")
        do {
            try await renderVideo(clips: clips, plan: plan, sourceDurations: durations, options: options, to: silentURL) { value in
                progress(value * 0.9)
            }
        } catch {
            try? FileManager.default.removeItem(at: silentURL)
            throw error
        }

        guard options.bgm != .none, let bgmURL = BGMRenderer.render(options.bgm, duration: total) else {
            progress(1)
            return silentURL
        }
        defer {
            try? FileManager.default.removeItem(at: bgmURL)
            try? FileManager.default.removeItem(at: silentURL)
        }
        try Task.checkCancellation()
        let outputURL = try await addMusic(video: silentURL, music: bgmURL)
        progress(1)
        return outputURL
    }

    // それぞれの動画に使う秒数。勉強時間に比べて長さを配り、1本あたり3秒はとる
    static func allocate(clips: [WeeklyVlogClip], sourceDurations: [Double]) -> [Double] {
        let count = Double(clips.count)
        let target = min(60, max(30, count * 6))
        let available = target - titleSeconds
        let minimum = min(3, available / count)
        let weights = clips.map { Double(max($0.studySeconds, 60)) }
        let weightSum = weights.reduce(0, +)

        var plan = weights.map { max(minimum, available * $0 / weightSum) }
        let sum = plan.reduce(0, +)
        if sum > available {
            plan = plan.map { max(minimum * 0.8, $0 * available / sum) }
        }
        // 元の動画より長くはしない（短い動画をむりに伸ばさない）
        return zip(plan, sourceDurations).map { planned, source in
            max(0, min(planned, source))
        }
    }

    // MARK: - 映像

    private static func renderVideo(
        clips: [WeeklyVlogClip],
        plan: [Double],
        sourceDurations: [Double],
        options: WeeklyVlogOptions,
        to url: URL,
        progress: @escaping (Double) -> Void
    ) async throws {
        let canvasSize = options.orientation.canvasSize
        let bounds = CGRect(origin: .zero, size: canvasSize)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(canvasSize.width),
            AVVideoHeightKey: Int(canvasSize.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(canvasSize.width),
                kCVPixelBufferHeightKey as String: Int(canvasSize.height)
            ]
        )
        guard writer.canAdd(input) else { throw WeeklyVlogError.failed }
        writer.add(input)
        guard writer.startWriting() else { throw WeeklyVlogError.failed }
        writer.startSession(atSourceTime: .zero)

        let context = CIContext()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let totalFrames = max(1, Int((titleSeconds + plan.reduce(0, +)) * Double(frameRate)))
        var frameIndex: Int64 = 0
        var lastProgress = 0.0

        // 1枚の絵を、決まったコマ数だけ書き込む
        func append(_ image: CIImage, frames: Int) throws {
            guard frames > 0 else { return }
            guard let pool = adaptor.pixelBufferPool else { throw WeeklyVlogError.failed }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
            guard let buffer else { throw WeeklyVlogError.failed }
            context.render(image, to: buffer, bounds: bounds, colorSpace: colorSpace)

            for _ in 0..<frames {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    try Task.checkCancellation()
                    usleep(2_000)
                }
                let time = CMTime(value: frameIndex, timescale: frameRate)
                guard adaptor.append(buffer, withPresentationTime: time) else { throw WeeklyVlogError.failed }
                frameIndex += 1
            }

            let value = Double(frameIndex) / Double(totalFrames)
            if value - lastProgress >= 0.01 {
                lastProgress = value
                progress(min(1, value))
            }
        }

        do {
            // はじめの1.5秒：1本目の最初のコマをぼかした上にタイトル
            let totalStudy = clips.reduce(0) { $0 + $1.studySeconds }
            let titleOverlay = textImage(canvasSize: canvasSize, options: options) { rect in
                drawTitle(
                    headline: options.headline,
                    detail: L10n.format("合計 %@", durationText(totalStudy)),
                    font: options.font,
                    in: rect
                )
            }
            let firstFrame = await firstImage(of: clips[0].videoURL)
            let titleBackground = firstFrame.map { blurredBackground($0, canvasSize: canvasSize, darken: -0.25) }
                ?? CIImage(color: CIColor(red: 0.18, green: 0.23, blue: 0.27)).cropped(to: bounds)
            try append(titleOverlay.map { $0.composited(over: titleBackground) } ?? titleBackground, frames: Int(titleSeconds * Double(frameRate)))

            for (index, clip) in clips.enumerated() {
                let frames = Int(plan[index] * Double(frameRate))
                guard frames > 0 else { continue }
                let overlay = textImage(canvasSize: canvasSize, options: options) { rect in
                    drawClipLabel(date: clip.date, study: clip.studySeconds, font: options.font, in: rect)
                }
                try await writeClip(
                    clip,
                    sourceDuration: sourceDurations[index],
                    frames: frames,
                    canvasSize: canvasSize,
                    overlay: overlay,
                    append: append
                )
            }

            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else { throw WeeklyVlogError.failed }
        } catch {
            if writer.status == .writing {
                writer.cancelWriting()
            }
            throw error
        }
    }

    // 1本の動画から、等間隔にコマを拾って frames コマにする
    private static func writeClip(
        _ clip: WeeklyVlogClip,
        sourceDuration: Double,
        frames: Int,
        canvasSize: CGSize,
        overlay: CIImage?,
        append: (CIImage, Int) throws -> Void
    ) async throws {
        let asset = AVURLAsset(url: clip.videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first, sourceDuration > 0 else { return }

        func compose(_ source: CIImage) -> CIImage {
            let frame = fitted(source, canvasSize: canvasSize)
            return overlay.map { $0.composited(over: frame) } ?? frame
        }

        // 何倍速か。速すぎるときは全部のコマを読まずに、必要な時刻だけ取り出す
        let speed = sourceDuration / (Double(frames) / Double(frameRate))
        if speed > 30 {
            let generator = AVAssetImageGenerator(asset: asset)
            let step = sourceDuration / Double(frames)
            let tolerance = CMTime(seconds: step / 2, preferredTimescale: 600)
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance
            var last: CIImage?
            for index in 0..<frames {
                try Task.checkCancellation()
                let time = CMTime(seconds: (Double(index) + 0.5) * step, preferredTimescale: 600)
                if let image = try? await generator.image(at: time).image {
                    let composed = compose(CIImage(cgImage: image))
                    try autoreleasepool {
                        try append(composed, 1)
                    }
                    last = composed
                } else if let last {
                    // 取り出せなかったコマは、ひとつ前のコマで埋めて長さを保つ
                    try append(last, 1)
                }
            }
            return
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return }
        reader.add(output)
        guard reader.startReading() else { return }
        defer { reader.cancelReading() }

        // 元の時刻 t のコマを、出力の何コマ目まで使うか決めて書き込む（遅い動画は同じコマをくり返す）
        var written = 0
        var last: CIImage?
        while written < frames {
            try Task.checkCancellation()
            guard let sample = output.copyNextSampleBuffer() else { break }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            let seconds = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            let target = min(frames, Int((seconds / sourceDuration) * Double(frames)) + 1)
            guard target > written else { continue }
            try autoreleasepool {
                let image = compose(CIImage(cvPixelBuffer: pixelBuffer))
                try append(image, target - written)
                last = image
            }
            written = target
        }
        // 最後のほうのコマが足りなければ、最後のコマで埋める
        if written < frames, let last {
            try append(last, frames - written)
        }
    }

    private static func firstImage(of url: URL) async -> CIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        guard let image = try? await generator.image(at: .zero).image else { return nil }
        return CIImage(cgImage: image)
    }

    // 動画を枠に収め、余白は同じ映像をぼかして暗くしたもので埋める
    private static func fitted(_ source: CIImage, canvasSize: CGSize) -> CIImage {
        let extent = source.extent
        guard extent.width > 0, extent.height > 0 else { return source }
        let bounds = CGRect(origin: .zero, size: canvasSize)
        let fitScale = min(canvasSize.width / extent.width, canvasSize.height / extent.height)
        let foreground = place(source, scale: fitScale, canvasSize: canvasSize)

        // 縦横比がほぼ同じなら余白は出ない
        let sourceRatio = extent.width / extent.height
        let canvasRatio = canvasSize.width / canvasSize.height
        if abs(sourceRatio - canvasRatio) < 0.01 {
            return foreground.cropped(to: bounds)
        }
        return foreground.composited(over: blurredBackground(source, canvasSize: canvasSize, darken: -0.12)).cropped(to: bounds)
    }

    // ぼかしは小さく縮めてからかけて、計算を軽くする
    private static func blurredBackground(_ source: CIImage, canvasSize: CGSize, darken: Double) -> CIImage {
        let extent = source.extent
        let bounds = CGRect(origin: .zero, size: canvasSize)
        guard extent.width > 0, extent.height > 0 else { return CIImage(color: .black).cropped(to: bounds) }
        let reduction: CGFloat = 0.25
        let fillScale = max(canvasSize.width / extent.width, canvasSize.height / extent.height) * reduction
        let small = CGSize(width: canvasSize.width * reduction, height: canvasSize.height * reduction)
        return place(source, scale: fillScale, canvasSize: small)
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 12])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: darken,
                kCIInputSaturationKey: 0.9
            ])
            .transformed(by: CGAffineTransform(scaleX: 1 / reduction, y: 1 / reduction))
            .cropped(to: bounds)
    }

    private static func place(_ image: CIImage, scale: CGFloat, canvasSize: CGSize) -> CIImage {
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dx = (canvasSize.width - scaled.extent.width) / 2 - scaled.extent.minX
        let dy = (canvasSize.height - scaled.extent.height) / 2 - scaled.extent.minY
        return scaled.transformed(by: CGAffineTransform(translationX: dx, y: dy))
    }

    // MARK: - 文字

    // 背景が透明な、動画と同じサイズの文字の画像。透かしもここで入れる
    private static func textImage(canvasSize: CGSize, options: WeeklyVlogOptions, draw: (CGRect) -> Void) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let rect = CGRect(origin: .zero, size: canvasSize)
        let image = UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            draw(rect)
            if options.showsWatermark {
                drawWatermark(in: rect)
            }
        }
        return image.cgImage.map { CIImage(cgImage: $0) }
    }

    private static func shadow(base: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = base * 0.018
        shadow.shadowOffset = .zero
        return shadow
    }

    private static func drawTitle(headline: String, detail: String, font: OverlayFont, in rect: CGRect) {
        let base = min(rect.width, rect.height)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let headlineSize = base * 0.085
        let primary = NSAttributedString(string: headline, attributes: [
            .font: font.uiFont(size: headlineSize),
            .foregroundColor: UIColor.white,
            .shadow: shadow(base: base),
            .paragraphStyle: paragraph,
            .kern: font == .wide ? headlineSize * 0.02 : 0
        ])
        let secondary = NSAttributedString(string: detail, attributes: [
            .font: font.uiFont(size: base * 0.045),
            .foregroundColor: UIColor.white.withAlphaComponent(0.92),
            .shadow: shadow(base: base),
            .paragraphStyle: paragraph
        ])
        let primaryHeight = primary.boundingRect(with: rect.size, options: .usesLineFragmentOrigin, context: nil).height
        let secondaryHeight = secondary.boundingRect(with: rect.size, options: .usesLineFragmentOrigin, context: nil).height
        let gap = base * 0.02
        let top = (rect.height - primaryHeight - gap - secondaryHeight) / 2
        primary.draw(in: CGRect(x: 0, y: top, width: rect.width, height: primaryHeight))
        secondary.draw(in: CGRect(x: 0, y: top + primaryHeight + gap, width: rect.width, height: secondaryHeight))
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MdE")
        return formatter
    }()

    // 左上に「10/14(火)」と、その日の勉強時間
    private static func drawClipLabel(date: Date, study: Int, font: OverlayFont, in rect: CGRect) {
        let base = min(rect.width, rect.height)
        let margin = base * 0.06
        let dateSize = base * 0.05
        let dateText = NSAttributedString(string: dayFormatter.string(from: date), attributes: [
            .font: font.uiFont(size: dateSize),
            .foregroundColor: UIColor.white,
            .shadow: shadow(base: base),
            .kern: font == .wide ? dateSize * 0.02 : 0
        ])
        let studyText = NSAttributedString(string: durationText(study), attributes: [
            .font: font.uiFont(size: base * 0.032),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            .shadow: shadow(base: base)
        ])
        // 縦長は上の UI と重ならないよう少し下げる
        let top = rect.height > rect.width ? rect.height * 0.1 : margin
        dateText.draw(at: CGPoint(x: margin, y: top))
        studyText.draw(at: CGPoint(x: margin, y: top + dateText.size().height + base * 0.008))
    }

    private static func drawWatermark(in rect: CGRect) {
        let base = min(rect.width, rect.height)
        let system = UIFont.systemFont(ofSize: base * 0.035, weight: .regular)
        let font = system.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: system.pointSize) } ?? system
        let watermark = NSAttributedString(string: "StudyReel", attributes: [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.8),
            .shadow: shadow(base: base)
        ])
        let size = watermark.size()
        let margin = base * 0.05
        watermark.draw(at: CGPoint(x: rect.width - size.width - margin, y: rect.height - size.height - margin))
    }

    // MARK: - BGM

    private static func addMusic(video: URL, music: URL) async throws -> URL {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        let musicAsset = AVURLAsset(url: music)
        let duration = try await videoAsset.load(.duration)
        let range = CMTimeRange(start: .zero, duration: duration)

        guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw WeeklyVlogError.failed
        }
        try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)

        if let sourceAudio = try await musicAsset.loadTracks(withMediaType: .audio).first,
           let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let musicDuration = try await musicAsset.load(.duration)
            let audioRange = CMTimeRange(start: .zero, duration: CMTimeMinimum(duration, musicDuration))
            try audioTrack.insertTimeRange(audioRange, of: sourceAudio, at: .zero)
        }

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw WeeklyVlogError.failed
        }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("StudyReel-Week-\(UUID().uuidString.prefix(8)).mp4")
        try await session.export(to: outputURL, as: .mp4)
        return outputURL
    }
}
