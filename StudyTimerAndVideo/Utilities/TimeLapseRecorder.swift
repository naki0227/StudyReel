import SwiftUI
import AVFoundation
import CoreImage

enum RecordingMode: String, CaseIterable, Identifiable {
    case timelapse
    case full
    case off

    var id: String { rawValue }

    var isPro: Bool { self == .full }

    var title: String {
        switch self {
        case .timelapse: return L10n.string("タイムラプス")
        case .full: return L10n.string("全部録画")
        case .off: return L10n.string("録画なし")
        }
    }
}

//MARK: - 録画クラス
// カメラのフレームを受け取りながら、その場で文字を重ねて動画ファイルに書き込む。
// タイムラプスは一定間隔ごとに1枚、全部録画はすべてのフレームを書き込む。
class TimeLapseRecorder: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var canCaptureVideo = false

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoQueue = DispatchQueue(label: "com.studyTimer.videoQueue")
    private let ciContext = CIContext()

    private static let timelapseFrameRate: Int32 = 10
    private static let fullFrameDuration = 1.0 / 30.0

    // ここから下は videoQueue でのみ触る
    private var mode: RecordingMode = .off
    private var isCapturing = false
    private var interval: Double = 5
    private var sessionStart = Date()
    private var elapsedOffset = 0
    private var style = VideoOverlayStyle(font: .standard, showsWatermark: true)

    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var canvasSize: CGSize = .zero

    private var activeSeconds: Double = 0
    private var lastFramePTS: CMTime?
    private var lastCaptureActiveSeconds: Double?
    private var lastAppendedTime: CMTime?
    private var frameIndex: Int64 = 0
    private var cachedOverlay: (text: HourBlockText, image: CIImage)?

    override init() {
        super.init()
        setupSession()
    }

    deinit {
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func setupSession() {
        session.sessionPreset = .high

        // 内カメラ入力
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            DispatchQueue.main.async {
                self.canCaptureVideo = false
            }
            return
        }
        session.addInput(input)

        if session.canAddOutput(output) {
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: videoQueue)
            output.alwaysDiscardsLateVideoFrames = true
            session.addOutput(output)
        }

        DispatchQueue.main.async {
            self.canCaptureVideo = true
        }

        updateOrientation(isLandscape: true)
    }

    func startSession(previewLayer: AVCaptureVideoPreviewLayer) {
        guard canCaptureVideo else { return }
        self.previewLayer = previewLayer
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }

    func updateOrientation(isLandscape: Bool) {
        let orientation: AVCaptureVideoOrientation = isLandscape ? .landscapeRight : .portrait

        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = orientation
            }
            // プレビューと同じく鏡写しで記録する
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        if let connection = previewLayer?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
    }

    // MARK: - 記録の操作（メインスレッドから呼ぶ）

    func start(mode: RecordingMode, interval: Double, sessionStart: Date, elapsedOffset: Int, style: VideoOverlayStyle) {
        videoQueue.async {
            self.discardWriter()
            self.mode = mode
            self.interval = interval
            self.sessionStart = sessionStart
            self.elapsedOffset = elapsedOffset
            self.style = style
            self.activeSeconds = 0
            self.lastFramePTS = nil
            self.lastCaptureActiveSeconds = nil
            self.lastAppendedTime = nil
            self.frameIndex = 0
            self.cachedOverlay = nil
            self.isCapturing = mode != .off
        }
    }

    func pause() {
        videoQueue.async {
            self.isCapturing = false
            self.lastFramePTS = nil
        }
    }

    func resume() {
        videoQueue.async {
            self.isCapturing = self.mode != .off
        }
    }

    // 書き込みを終えて動画ファイルの URL を返す。何も記録していなければ nil
    func finish(completion: @escaping (URL?) -> Void) {
        videoQueue.async {
            self.isCapturing = false
            guard let writer = self.writer, let input = self.writerInput, let url = self.outputURL, writer.status == .writing else {
                self.discardWriter()
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.writer = nil
            self.writerInput = nil
            self.adaptor = nil
            self.outputURL = nil

            input.markAsFinished()
            writer.finishWriting {
                let succeeded = writer.status == .completed
                if !succeeded {
                    try? FileManager.default.removeItem(at: url)
                }
                DispatchQueue.main.async {
                    completion(succeeded ? url : nil)
                }
            }
        }
    }

    func cancel() {
        videoQueue.async {
            self.isCapturing = false
            self.discardWriter()
        }
    }

    private func discardWriter() {
        if let writer, writer.status == .writing {
            writer.cancelWriting()
        }
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        writer = nil
        writerInput = nil
        adaptor = nil
        outputURL = nil
    }

    // MARK: - フレーム処理（videoQueue）

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isCapturing, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 一時停止していた時間は含めずに、勉強した時間だけを積み上げる
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let lastFramePTS {
            activeSeconds += max(0, CMTimeSubtract(pts, lastFramePTS).seconds)
        }
        lastFramePTS = pts

        switch mode {
        case .timelapse:
            if let lastCaptureActiveSeconds, activeSeconds - lastCaptureActiveSeconds < interval { return }
            lastCaptureActiveSeconds = activeSeconds
            let time = CMTime(value: frameIndex, timescale: Self.timelapseFrameRate)
            if append(pixelBuffer, at: time) {
                frameIndex += 1
            }
        case .full:
            var time = CMTime(seconds: activeSeconds, preferredTimescale: 600)
            if let lastAppendedTime, CMTimeCompare(time, lastAppendedTime) <= 0 {
                time = CMTimeAdd(lastAppendedTime, CMTime(seconds: Self.fullFrameDuration, preferredTimescale: 600))
                activeSeconds = time.seconds
            }
            _ = append(pixelBuffer, at: time)
        case .off:
            break
        }
    }

    @discardableResult
    private func append(_ pixelBuffer: CVPixelBuffer, at time: CMTime) -> Bool {
        if writer == nil {
            setupWriter(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        }

        guard let writer, writer.status == .writing,
              let writerInput, writerInput.isReadyForMoreMediaData,
              let pool = adaptor?.pixelBufferPool else { return false }

        var outputBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)
        guard let outputBuffer else { return false }

        let frame = aspectFill(CIImage(cvPixelBuffer: pixelBuffer), to: canvasSize)
        let composed = overlayImage(elapsedSeconds: elapsedOffset + Int(activeSeconds)).map { $0.composited(over: frame) } ?? frame
        ciContext.render(composed, to: outputBuffer, bounds: CGRect(origin: .zero, size: canvasSize), colorSpace: CGColorSpaceCreateDeviceRGB())

        guard adaptor?.append(outputBuffer, withPresentationTime: time) == true else { return false }
        lastAppendedTime = time
        return true
    }

    private func setupWriter(width: Int, height: Int) {
        // 縦持ちならリール向けの縦長、横持ちなら横長で書き出す
        let isPortrait = height > width
        canvasSize = isPortrait ? CGSize(width: 1080, height: 1920) : CGSize(width: 1920, height: 1080)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("studyreel-\(UUID().uuidString).mov")

        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
            var settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(canvasSize.width),
                AVVideoHeightKey: Int(canvasSize.height)
            ]
            if mode == .full {
                // 長時間になるので容量を抑える
                settings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey: 5_000_000]
            }

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: Int(canvasSize.width),
                    kCVPixelBufferHeightKey as String: Int(canvasSize.height)
                ]
            )

            guard writer.canAdd(input) else { return }
            writer.add(input)
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: .zero)

            self.writer = writer
            self.writerInput = input
            self.adaptor = adaptor
            self.outputURL = url
        } catch {
            print("❌ writer setup error: \(error)")
        }
    }

    private func aspectFill(_ image: CIImage, to size: CGSize) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }
        let scale = max(size.width / extent.width, size.height / extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dx = (size.width - scaled.extent.width) / 2 - scaled.extent.minX
        let dy = (size.height - scaled.extent.height) / 2 - scaled.extent.minY
        return scaled
            .transformed(by: CGAffineTransform(translationX: dx, y: dy))
            .cropped(to: CGRect(origin: .zero, size: size))
    }

    private func overlayImage(elapsedSeconds: Int) -> CIImage? {
        let text = HourBlockText(sessionStart: sessionStart, elapsedSeconds: elapsedSeconds)
        if let cachedOverlay, cachedOverlay.text == text {
            return cachedOverlay.image
        }
        guard let cgImage = VideoOverlayRenderer.makeImage(text: text, style: style, canvasSize: canvasSize) else { return nil }
        let image = CIImage(cgImage: cgImage)
        cachedOverlay = (text, image)
        return image
    }
}
