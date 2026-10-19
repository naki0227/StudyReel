import SwiftUI
import AVFoundation
import CoreImage

enum RecordingMode: String, CaseIterable, Identifiable {
    case timelapse
    case full
    case off

    // 最後に選んだ撮り方を次回も使う
    static let storageKey = "recording_mode"

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
// カメラのフレームをそのまま動画ファイルに書き込み、同時に顔の位置を記録する。
// 文字・透かし・モザイクは、確認画面のあとに VideoExporter で合成する。
// タイムラプスは一定間隔ごとに1枚、全部録画はすべてのフレームを書き込む。
class TimeLapseRecorder: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var canCaptureVideo = false
    // 電話や別アプリの画面分割などでカメラが止められている間 true
    @Published private(set) var isInterrupted = false

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
    private var elapsedOffset: Double = 0
    private var captureLandscape = true
    private var isFrontCamera = true
    private let faceTracker = FaceTracker()
    private var track = FaceTrack()
    private var lastSampleTime: Double?

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
    private var lastRecoverySave = Date.distantPast

    override init() {
        super.init()
        setupSession()
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: AVCaptureSession.wasInterruptedNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: AVCaptureSession.interruptionEndedNotification, object: session)
    }

    @objc private func sessionWasInterrupted() {
        DispatchQueue.main.async {
            self.isInterrupted = true
        }
    }

    @objc private func sessionInterruptionEnded() {
        DispatchQueue.main.async {
            self.isInterrupted = false
        }
    }

    deinit {
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func setupSession() {
        // 紹介動画用のデモ表示ではカメラを使わない（許可のダイアログも出さない）
        if DemoMode.isActive {
            DispatchQueue.main.async {
                self.canCaptureVideo = false
            }
            return
        }
        session.sessionPreset = .high

        // 設定で選んだカメラ（既定は前面）
        let position = RecordingSettings.camera.avPosition
        isFrontCamera = position == .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
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
            // 前面カメラはプレビューと同じく鏡写しで記録する
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isFrontCamera
            }
        }

        if let connection = previewLayer?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
    }

    // MARK: - 記録の操作（メインスレッドから呼ぶ）

    func start(mode: RecordingMode, interval: Double, sessionStart: Date, elapsedOffset: Int, isLandscape: Bool) {
        // 画面の回転が終わる前に最初のフレームが来ても、選んだ向きで記録する
        updateOrientation(isLandscape: isLandscape)
        videoQueue.async {
            self.captureLandscape = isLandscape
            self.discardWriter()
            self.mode = mode
            self.interval = interval
            self.sessionStart = sessionStart
            self.elapsedOffset = Double(elapsedOffset)
            self.activeSeconds = 0
            self.lastFramePTS = nil
            self.lastCaptureActiveSeconds = nil
            self.lastAppendedTime = nil
            self.lastSampleTime = nil
            self.frameIndex = 0
            self.track = FaceTrack(isRealTime: mode == .full)
            self.faceTracker.reset()
            self.isCapturing = mode != .off
        }
    }

    func pause() {
        videoQueue.async {
            self.isCapturing = false
            self.lastFramePTS = nil
        }
    }

    // elapsedNow を渡すと、撮れていなかった間の勉強時間も動画の文字に反映する（アプリを離れていたときなど）
    func resume(elapsedNow: Int? = nil) {
        videoQueue.async {
            if let elapsedNow {
                self.elapsedOffset = max(0, Double(elapsedNow) - self.activeSeconds)
            }
            self.lastFramePTS = nil
            self.isCapturing = self.mode != .off
        }
    }

    // 書き込みを終えて、確認画面に渡す結果を返す。何も記録していなければ nil
    func finish(completion: @escaping (RecordingResult?) -> Void) {
        videoQueue.async {
            self.isCapturing = false
            guard let writer = self.writer, let input = self.writerInput, let url = self.outputURL, writer.status == .writing else {
                self.discardWriter()
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let result = RecordingResult(url: url, canvasSize: self.canvasSize, sessionStart: self.sessionStart, track: self.track)
            SessionRecovery.clearRecording()

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
                    completion(succeeded ? result : nil)
                }
            }
        }
    }

    func cancel() {
        videoQueue.async {
            self.isCapturing = false
            self.discardWriter()
            SessionRecovery.clearRecording()
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
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        guard isCapturing else { return }

        // 録画中は画面に出さず、顔の位置だけ記録しておく（確認画面と書き出しで使う）
        faceTracker.process(pixelBuffer, time: pts.seconds)

        // 一時停止していた時間は含めずに、勉強した時間だけを積み上げる
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
                recordSample(pixelBuffer, videoTime: time.seconds)
            }
        case .full:
            var time = CMTime(seconds: activeSeconds, preferredTimescale: 600)
            if let lastAppendedTime, CMTimeCompare(time, lastAppendedTime) <= 0 {
                time = CMTimeAdd(lastAppendedTime, CMTime(seconds: Self.fullFrameDuration, preferredTimescale: 600))
                activeSeconds = time.seconds
            }
            if append(pixelBuffer, at: time) {
                // 全部録画は 0.2 秒おきに記録して、間は確認画面と書き出しで補間する
                if lastSampleTime == nil || time.seconds - (lastSampleTime ?? 0) >= 0.2 {
                    recordSample(pixelBuffer, videoTime: time.seconds)
                }
            }
        case .off:
            break
        }
    }

    @discardableResult
    private func append(_ pixelBuffer: CVPixelBuffer, at time: CMTime) -> Bool {
        if writer == nil {
            setupWriter()
        }

        guard let writer, writer.status == .writing,
              let writerInput, writerInput.isReadyForMoreMediaData,
              let pool = adaptor?.pixelBufferPool else { return false }

        var outputBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)
        guard let outputBuffer else { return false }

        let frame = aspectFill(CIImage(cvPixelBuffer: pixelBuffer), to: canvasSize)
        ciContext.render(frame, to: outputBuffer, bounds: CGRect(origin: .zero, size: canvasSize), colorSpace: CGColorSpaceCreateDeviceRGB())

        guard adaptor?.append(outputBuffer, withPresentationTime: time) == true else { return false }
        lastAppendedTime = time
        return true
    }

    private func setupWriter() {
        // 縦持ちならリール向けの縦長、横持ちなら横長で書き出す
        let size = RecordingSettings.quality.landscapeSize
        canvasSize = captureLandscape ? size : CGSize(width: size.height, height: size.width)

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

            // 10秒ごとに区切って書くと、途中でアプリが終了してもそこまでは再生できるファイルになる
            writer.movieFragmentInterval = CMTime(seconds: 10, preferredTimescale: 600)

            guard writer.canAdd(input) else { return }
            writer.add(input)
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: .zero)

            self.writer = writer
            self.writerInput = input
            self.adaptor = adaptor
            self.outputURL = url
            self.lastRecoverySave = .distantPast
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

    private func recordSample(_ pixelBuffer: CVPixelBuffer, videoTime: Double) {
        let bufferRect = faceTracker.rectOrDefault
        let rect = canvasRect(
            fromBufferRect: bufferRect,
            bufferSize: CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        )
        track.samples.append(FaceSample(
            time: videoTime,
            elapsed: elapsedOffset + activeSeconds,
            rect: rect,
            segment: faceTracker.segment
        ))
        lastSampleTime = videoTime

        // アプリが落ちても書きかけの動画を拾えるよう、30秒おきに控えを残す
        if Date().timeIntervalSince(lastRecoverySave) >= 30 {
            saveRecoveryInfo()
        }
    }

    private func saveRecoveryInfo() {
        guard let outputURL else { return }
        lastRecoverySave = Date()
        SessionRecovery.saveRecording(RecordingRecoveryInfo(
            videoPath: outputURL.path,
            canvasWidth: canvasSize.width,
            canvasHeight: canvasSize.height,
            sessionStart: sessionStart,
            isRealTime: track.isRealTime,
            samples: track.samples
        ))
    }

    // カメラ映像の座標を、aspectFill で切り抜いた動画の座標に直す
    private func canvasRect(fromBufferRect rect: CGRect, bufferSize: CGSize) -> CGRect {
        guard bufferSize.width > 0, bufferSize.height > 0, canvasSize.width > 0 else { return rect }
        let scale = max(canvasSize.width / bufferSize.width, canvasSize.height / bufferSize.height)
        let dx = (canvasSize.width - bufferSize.width * scale) / 2
        let dy = (canvasSize.height - bufferSize.height * scale) / 2
        return FaceTrack.clamp(CGRect(
            x: (rect.minX * bufferSize.width * scale + dx) / canvasSize.width,
            y: (rect.minY * bufferSize.height * scale + dy) / canvasSize.height,
            width: rect.width * bufferSize.width * scale / canvasSize.width,
            height: rect.height * bufferSize.height * scale / canvasSize.height
        ))
    }
}
