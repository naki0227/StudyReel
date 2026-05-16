import SwiftUI
import AVFoundation

struct CameraPreview: View {
    @ObservedObject var recorder: TimeLapseRecorder
    var isLandscape: Bool

    var body: some View {
        ZStack {
            if recorder.canCaptureVideo {
                CameraPreviewLayerView(recorder: recorder, isLandscape: isLandscape)
            } else {
                fallbackPreview
            }
        }
    }

    private var fallbackPreview: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.13, blue: 0.20),
                    Color(red: 0.07, green: 0.19, blue: 0.25),
                    Color(red: 0.03, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 320, height: 320)
                .offset(x: -140, y: -220)

            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 260, height: 260)
                .offset(x: 140, y: 260)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .frame(width: 180, height: 180)
                .blur(radius: 8)
                .offset(x: 120, y: -120)
        }
        .ignoresSafeArea()
    }
}

private struct CameraPreviewLayerView: UIViewRepresentable {
    @ObservedObject var recorder: TimeLapseRecorder
    var isLandscape: Bool

    func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        recorder.startSession(previewLayer: view.previewLayer)
        recorder.updateOrientation(isLandscape: isLandscape)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewView = uiView as? PreviewView else { return }
        recorder.startSession(previewLayer: previewView.previewLayer)
        recorder.updateOrientation(isLandscape: isLandscape)
    }
}

private final class PreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
}
