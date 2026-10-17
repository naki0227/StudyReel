import AVFoundation
import CoreImage
import UIKit

struct VideoExportOptions {
    var hidesFaces: Bool
    var hideStyle: FaceHideStyle
    var stamp: String
    var overlay: VideoOverlayStyle
    var filter: VideoFilter = .none
    var bgm: BGMTrack = .none
    // 素の録画の中で使う範囲（秒）。nil なら全体
    var trim: ClosedRange<Double>?
}

// 録画した素の動画に、フィルター・モザイク（またはスタンプ）・中央の時刻・透かし・BGM を重ねて書き出す
enum VideoExporter {
    private static let queue = DispatchQueue(label: "com.studyTimer.exportQueue", qos: .userInitiated)

    static func export(
        result: RecordingResult,
        options: VideoExportOptions,
        progress: @escaping (Double) -> Void,
        completion: @escaping (URL?) -> Void
    ) {
        queue.async {
            let url = render(result: result, options: options) { value in
                DispatchQueue.main.async { progress(value) }
            }
            DispatchQueue.main.async { completion(url) }
        }
    }

    // フレームごとの見た目（フィルター → 顔 → 時刻と透かし）。プレビュー用のサムネイルでも使う
    final class FrameRenderer {
        let result: RecordingResult
        let options: VideoExportOptions
        private var overlayCache: (text: OverlayText, image: CIImage)?
        private var stampCache: (side: Int, image: CIImage)?

        init(result: RecordingResult, options: VideoExportOptions) {
            self.result = result
            self.options = options
        }

        func render(_ source: CIImage, at seconds: Double) -> CIImage {
            let canvasSize = result.canvasSize
            var image = options.filter.apply(to: source)

            if options.hidesFaces, let rect = result.track.rect(at: seconds) {
                let ciRect = VideoExporter.ciRect(for: rect, canvasSize: canvasSize)
                switch options.hideStyle {
                case .mosaic:
                    image = VideoExporter.mosaic(image, in: ciRect, canvasSize: canvasSize)
                case .stamp:
                    let side = Int(max(ciRect.width, ciRect.height) / 16) * 16 + 16
                    if stampCache?.side != side {
                        stampCache = VideoExporter.stampImage(options.stamp, side: CGFloat(side)).map { (side, $0) }
                    }
                    if let stamp = stampCache?.image {
                        let placed = stamp.transformed(by: CGAffineTransform(
                            translationX: ciRect.midX - CGFloat(side) / 2,
                            y: ciRect.midY - CGFloat(side) / 2
                        ))
                        image = placed.composited(over: image)
                    }
                }
            }

            let text = OverlayText(
                sessionStart: result.sessionStart,
                elapsedSeconds: Int(result.track.elapsed(at: seconds)),
                layout: options.overlay.layout
            )
            if overlayCache?.text != text {
                overlayCache = VideoOverlayRenderer.makeImage(text: text, style: options.overlay, canvasSize: canvasSize)
                    .map { (text, CIImage(cgImage: $0)) }
            }
            if let overlay = overlayCache?.image {
                image = overlay.composited(over: image)
            }
            return image.cropped(to: CGRect(origin: .zero, size: canvasSize))
        }
    }

    private static func render(result: RecordingResult, options: VideoExportOptions, progress: @escaping (Double) -> Void) -> URL? {
        let asset = AVURLAsset(url: result.url)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return nil }
        let fullDuration = max(asset.duration.seconds, 0.001)
        let trim = options.trim.map { max(0, $0.lowerBound)...min(fullDuration, $0.upperBound) } ?? 0...fullDuration
        let start = CMTime(seconds: trim.lowerBound, preferredTimescale: 600)
        let duration = max(trim.upperBound - trim.lowerBound, 0.001)
        let canvasSize = result.canvasSize
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("studyreel-export-\(UUID().uuidString).mov")
        let bgmURL = options.bgm == .none ? nil : BGMRenderer.render(options.bgm, duration: duration)
        defer {
            if let bgmURL { try? FileManager.default.removeItem(at: bgmURL) }
        }

        do {
            // 映像の読み込み（カットした範囲だけ）
            let reader = try AVAssetReader(asset: asset)
            reader.timeRange = CMTimeRange(start: start, duration: CMTime(seconds: duration, preferredTimescale: 600))
            let readerOutput = AVAssetReaderTrackOutput(
                track: videoTrack,
                outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            )
            readerOutput.alwaysCopiesSampleData = false
            guard reader.canAdd(readerOutput) else { return nil }
            reader.add(readerOutput)

            // BGM の読み込み
            var audioReader: AVAssetReader?
            var audioOutput: AVAssetReaderTrackOutput?
            if let bgmURL {
                let audioAsset = AVURLAsset(url: bgmURL)
                if let audioTrack = audioAsset.tracks(withMediaType: .audio).first {
                    let r = try AVAssetReader(asset: audioAsset)
                    let o = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsNonInterleaved: false
                    ])
                    if r.canAdd(o) {
                        r.add(o)
                        audioReader = r
                        audioOutput = o
                    }
                }
            }

            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            var settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(canvasSize.width),
                AVVideoHeightKey: Int(canvasSize.height)
            ]
            if result.track.isRealTime {
                settings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey: 5_000_000]
            }
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            videoInput.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: Int(canvasSize.width),
                    kCVPixelBufferHeightKey as String: Int(canvasSize.height)
                ]
            )
            guard writer.canAdd(videoInput) else { return nil }
            writer.add(videoInput)

            var audioInput: AVAssetWriterInput?
            if audioOutput != nil {
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44_100,
                    AVEncoderBitRateKey: 160_000
                ])
                input.expectsMediaDataInRealTime = false
                if writer.canAdd(input) {
                    writer.add(input)
                    audioInput = input
                }
            }

            guard reader.startReading(), writer.startWriting() else { return nil }
            if let audioReader, audioInput != nil, !audioReader.startReading() {
                return nil
            }
            writer.startSession(atSourceTime: .zero)

            let context = CIContext()
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bounds = CGRect(origin: .zero, size: canvasSize)
            let frameRenderer = FrameRenderer(result: result, options: options)
            let group = DispatchGroup()
            var lastProgress = 0.0
            var videoFailed = false

            // 映像と音声は、それぞれ書き込める状態になったときに交互に流し込む
            group.enter()
            let videoQueue = DispatchQueue(label: "com.studyTimer.export.video")
            videoInput.requestMediaDataWhenReady(on: videoQueue) {
                while videoInput.isReadyForMoreMediaData {
                    guard let sample = readerOutput.copyNextSampleBuffer() else {
                        videoInput.markAsFinished()
                        group.leave()
                        return
                    }
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample),
                          let pool = adaptor.pixelBufferPool else { continue }

                    let sourceTime = CMSampleBufferGetPresentationTimeStamp(sample)
                    let seconds = sourceTime.seconds
                    let image = frameRenderer.render(CIImage(cvPixelBuffer: pixelBuffer), at: seconds)

                    var outputBuffer: CVPixelBuffer?
                    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)
                    guard let outputBuffer else { continue }
                    context.render(image, to: outputBuffer, bounds: bounds, colorSpace: colorSpace)

                    if !adaptor.append(outputBuffer, withPresentationTime: CMTimeSubtract(sourceTime, start)) {
                        videoFailed = true
                        reader.cancelReading()
                        videoInput.markAsFinished()
                        group.leave()
                        return
                    }

                    let value = min(1, (seconds - trim.lowerBound) / duration)
                    if value - lastProgress >= 0.01 {
                        lastProgress = value
                        progress(value)
                    }
                }
            }

            if let audioInput, let audioOutput {
                group.enter()
                let audioQueue = DispatchQueue(label: "com.studyTimer.export.audio")
                audioInput.requestMediaDataWhenReady(on: audioQueue) {
                    while audioInput.isReadyForMoreMediaData {
                        guard let sample = audioOutput.copyNextSampleBuffer() else {
                            audioInput.markAsFinished()
                            group.leave()
                            return
                        }
                        if !audioInput.append(sample) {
                            audioInput.markAsFinished()
                            group.leave()
                            return
                        }
                    }
                }
            }

            group.wait()

            let semaphore = DispatchSemaphore(value: 0)
            writer.finishWriting { semaphore.signal() }
            semaphore.wait()

            guard !videoFailed, reader.status != .failed, writer.status == .completed else {
                try? FileManager.default.removeItem(at: outputURL)
                return nil
            }
            progress(1)
            return outputURL
        } catch {
            print("❌ export error: \(error)")
            try? FileManager.default.removeItem(at: outputURL)
            return nil
        }
    }

    // 動画の座標（左上原点・0〜1）を Core Image の座標（左下原点・ピクセル）に直す
    static func ciRect(for rect: CGRect, canvasSize: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * canvasSize.width,
            y: (1 - rect.maxY) * canvasSize.height,
            width: rect.width * canvasSize.width,
            height: rect.height * canvasSize.height
        ).integral
    }

    // 顔の範囲を楕円（丸）に切り抜いてモザイクをかける。縁は少しだけぼかして自然になじませる
    static func mosaic(_ image: CIImage, in ciRect: CGRect, canvasSize: CGSize) -> CIImage {
        guard ciRect.width > 0, ciRect.height > 0 else { return image }

        let pixellated = image.clampedToExtent()
            .applyingFilter("CIPixellate", parameters: [
                kCIInputScaleKey: max(canvasSize.width, canvasSize.height) * 0.03,
                kCIInputCenterKey: CIVector(x: ciRect.midX, y: ciRect.midY)
            ])
            .cropped(to: ciRect)

        let radius = ciRect.height / 2
        guard let circle = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: 0, y: 0),
            "inputRadius0": radius * 0.94,
            "inputRadius1": radius,
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 1),
            "inputColor1": CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        ])?.outputImage else {
            return pixellated.composited(over: image)
        }

        // 円を顔の範囲の縦横比に合わせて楕円にする
        let mask = circle
            .transformed(by: CGAffineTransform(scaleX: ciRect.width / ciRect.height, y: 1))
            .transformed(by: CGAffineTransform(translationX: ciRect.midX, y: ciRect.midY))
            .cropped(to: ciRect)

        return pixellated.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: mask
        ])
    }

    static func stampImage(_ stamp: String, side: CGFloat) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: side, height: side)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: side * 0.85)]
            let string = NSAttributedString(string: stamp, attributes: attributes)
            let textSize = string.size()
            string.draw(at: CGPoint(x: (side - textSize.width) / 2, y: (side - textSize.height) / 2))
        }
        return image.cgImage.map { CIImage(cgImage: $0) }
    }
}
