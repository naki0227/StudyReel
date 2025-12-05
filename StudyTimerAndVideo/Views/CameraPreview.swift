import SwiftUI
import AVFoundation

// MARK: - カメラプレビュー
struct CameraPreview: UIViewRepresentable {
    var recorder: TimeLapseRecorder
    
    func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        recorder.startSession(previewLayer: view.previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class PreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
