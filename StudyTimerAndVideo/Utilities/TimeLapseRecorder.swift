import SwiftUI
import AVFoundation

//MARK: - タイムラプス録画クラス
class TimeLapseRecorder: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private var timer: Timer?
    
    // Thread-safe storage
    private let dataQueue = DispatchQueue(label: "com.studyTimer.dataQueue")
    private var _photos: [CGImage] = []
    private var _currentImage: CGImage? = nil
    
    // Reusable context for performance
    private let ciContext = CIContext()
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session.sessionPreset = .high
        
        // 内カメラ入力
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        
        // 出力
        if session.canAddOutput(output) {
            // Use a dedicated serial queue for video processing
            let videoQueue = DispatchQueue(label: "com.studyTimer.videoQueue")
            output.setSampleBufferDelegate(self, queue: videoQueue)
            output.alwaysDiscardsLateVideoFrames = true // Drop frames if processing is slow
            session.addOutput(output)
        }
        
        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .landscapeRight
        }
    }
    
    func startSession(previewLayer: AVCaptureVideoPreviewLayer) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspect
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .landscapeRight
        }
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }
    
    func startCapturing(interval: Double) {
        dataQueue.async {
            self._photos.removeAll()
        }
        startTimer(interval: interval)
    }
    
    func pauseCapturing() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    func resumeCapturing(interval: Double) {
        startTimer(interval: interval)
    }
    
    private func startTimer(interval: Double) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.captureFrame()
            }
        }
    }
    
    private func captureFrame() {
        dataQueue.async {
            if let img = self._currentImage {
                self._photos.append(img)
            }
        }
    }
    
    func stopCapturing() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    // 写真を受け取る (Running on videoQueue)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Use the reused CIContext
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            dataQueue.async {
                self._currentImage = cgImage
            }
        }
    }
    
    // 撮った写真を動画に変換
    func exportToVideo(completion: @escaping (URL?) -> Void) {
        dataQueue.async {
            let photosCopy = self._photos
            
            guard let first = photosCopy.first else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let outputPath = NSTemporaryDirectory() + "timelapse.mov"
            let outputURL = URL(fileURLWithPath: outputPath)
            try? FileManager.default.removeItem(at: outputURL)
            
            do {
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
                let settings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 1280,
                    AVVideoHeightKey: 720
                ]
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
                
                guard writer.canAdd(input) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                writer.add(input)
                
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)
                
                let frameDuration = CMTime(value: 1, timescale: 10)
                var frameTime = CMTime.zero
                
                // Use a separate context for export to avoid thread conflict if capture is still running (though it shouldn't be)
                let exportContext = CIContext()
                
                for cgImage in photosCopy {
                    while !input.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                    
                    var pixelBuffer: CVPixelBuffer?
                    let status = CVPixelBufferCreate(kCFAllocatorDefault, 1280, 720, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
                    
                    if status == kCVReturnSuccess, let buffer = pixelBuffer {
                        // Resize/Draw image to buffer
                        let ciImage = CIImage(cgImage: cgImage)
                        // Simple resize to fit 720p
                        let scale = 720.0 / CGFloat(cgImage.height)
                        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                        
                        exportContext.render(resized, to: buffer)
                        adaptor.append(buffer, withPresentationTime: frameTime)
                        frameTime = CMTimeAdd(frameTime, frameDuration)
                    }
                }
                
                input.markAsFinished()
                writer.finishWriting {
                    DispatchQueue.main.async {
                        completion(outputURL)
                    }
                }
            } catch {
                print("❌ export error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
