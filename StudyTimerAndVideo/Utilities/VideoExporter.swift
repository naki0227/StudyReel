import AVFoundation
import CoreImage
import UIKit

struct VideoExportOptions {
    var hidesFaces: Bool
    var hideStyle: FaceHideStyle
    var stamp: String
    var overlay: VideoOverlayStyle
}

// 録画した素の動画に、モザイク（またはスタンプ）・中央の時刻・透かしを重ねて書き出す
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

    private static func render(result: RecordingResult, options: VideoExportOptions, progress: (Double) -> Void) -> URL? {
        let asset = AVURLAsset(url: result.url)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return nil }
        let duration = max(asset.duration.seconds, 0.001)
        let canvasSize = result.canvasSize
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("studyreel-export-\(UUID().uuidString).mov")

        do {
            let reader = try AVAssetReader(asset: asset)
            let readerOutput = AVAssetReaderTrackOutput(
                track: videoTrack,
                outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            )
            readerOutput.alwaysCopiesSampleData = false
            guard reader.canAdd(readerOutput) else { return nil }
            reader.add(readerOutput)

            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            var settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(canvasSize.width),
                AVVideoHeightKey: Int(canvasSize.height)
            ]
            if result.track.isRealTime {
                settings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey: 5_000_000]
            }
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: Int(canvasSize.width),
                    kCVPixelBufferHeightKey as String: Int(canvasSize.height)
                ]
            )
            guard writer.canAdd(input) else { return nil }
            writer.add(input)

            guard reader.startReading(), writer.startWriting() else { return nil }
            writer.startSession(atSourceTime: .zero)

            let context = CIContext()
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bounds = CGRect(origin: .zero, size: canvasSize)
            var overlayCache: (text: HourBlockText, image: CIImage)?
            var stampCache: (side: Int, image: CIImage)?
            var lastProgress = 0.0

            while let sample = readerOutput.copyNextSampleBuffer() {
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
                let time = CMSampleBufferGetPresentationTimeStamp(sample)
                let seconds = time.seconds

                var image = CIImage(cvPixelBuffer: pixelBuffer)

                if options.hidesFaces, let rect = result.track.rect(at: seconds) {
                    let ciRect = CGRect(
                        x: rect.minX * canvasSize.width,
                        y: (1 - rect.maxY) * canvasSize.height,
                        width: rect.width * canvasSize.width,
                        height: rect.height * canvasSize.height
                    ).integral

                    switch options.hideStyle {
                    case .mosaic:
                        let pixellated = image.clampedToExtent()
                            .applyingFilter("CIPixellate", parameters: [
                                kCIInputScaleKey: max(canvasSize.width, canvasSize.height) * 0.03,
                                kCIInputCenterKey: CIVector(x: ciRect.midX, y: ciRect.midY)
                            ])
                            .cropped(to: ciRect)
                        image = pixellated.composited(over: image)
                    case .stamp:
                        let side = Int(max(ciRect.width, ciRect.height) / 16) * 16 + 16
                        if stampCache?.side != side {
                            stampCache = stampImage(options.stamp, side: CGFloat(side)).map { (side, $0) }
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

                let text = HourBlockText(sessionStart: result.sessionStart, elapsedSeconds: Int(result.track.elapsed(at: seconds)))
                if overlayCache?.text != text {
                    overlayCache = VideoOverlayRenderer.makeImage(text: text, style: options.overlay, canvasSize: canvasSize)
                        .map { (text, CIImage(cgImage: $0)) }
                }
                if let overlay = overlayCache?.image {
                    image = overlay.composited(over: image)
                }

                while !input.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.005)
                }

                guard let pool = adaptor.pixelBufferPool else { break }
                var outputBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)
                guard let outputBuffer else { continue }

                context.render(image.cropped(to: bounds), to: outputBuffer, bounds: bounds, colorSpace: colorSpace)
                adaptor.append(outputBuffer, withPresentationTime: time)

                let value = min(1, seconds / duration)
                if value - lastProgress >= 0.01 {
                    lastProgress = value
                    progress(value)
                }
            }

            input.markAsFinished()
            let semaphore = DispatchSemaphore(value: 0)
            writer.finishWriting { semaphore.signal() }
            semaphore.wait()

            guard reader.status == .completed, writer.status == .completed else {
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

    private static func stampImage(_ stamp: String, side: CGFloat) -> CIImage? {
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
