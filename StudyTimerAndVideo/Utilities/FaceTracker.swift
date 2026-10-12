import CoreGraphics
import CoreVideo
import Vision

// 端末内の Vision で顔の位置を探す。結果は保存も送信もしない。
// 勉強中は下を向いて顔を見失いやすいので、少しの間は直前の位置を保ち、
// それでも見つからなければ上半身から頭の位置を推定するか、広めの範囲で隠す。
final class FaceTracker {
    private(set) var currentRect: CGRect?   // カメラ映像に対する 0〜1 の座標（左上原点）
    private(set) var segment = 0

    private var isFallback = false
    private var lastFaceRect: CGRect?
    private var lastSeenTime: Double?
    private var lastDetectionTime: Double?

    private let detectionInterval = 0.2
    private let holdDuration = 1.5

    func reset() {
        currentRect = nil
        isFallback = false
        lastFaceRect = nil
        lastSeenTime = nil
        lastDetectionTime = nil
        segment += 1
    }

    // 検出したら true を返す。毎フレームは検出せず、0.2秒おきにする
    @discardableResult
    func process(_ pixelBuffer: CVPixelBuffer, time: Double) -> Bool {
        if let lastDetectionTime, time - lastDetectionTime < detectionInterval { return false }
        lastDetectionTime = time

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let faceRequest = VNDetectFaceRectanglesRequest()
        try? handler.perform([faceRequest])

        if let face = faceRequest.results?.max(by: { Self.area($0.boundingBox) < Self.area($1.boundingBox) }) {
            let rect = Self.expandFace(Self.topLeft(face.boundingBox))
            let smoothed = (!isFallback && currentRect != nil) ? FaceTrack.lerp(currentRect!, rect, 0.6) : rect
            update(rect: smoothed, fallback: false)
            lastFaceRect = rect
            lastSeenTime = time
            return true
        }

        if let lastSeenTime, time - lastSeenTime < holdDuration, currentRect != nil {
            return true
        }

        let bodyRequest = VNDetectHumanRectanglesRequest()
        bodyRequest.upperBodyOnly = true
        try? handler.perform([bodyRequest])

        if let body = bodyRequest.results?.max(by: { Self.area($0.boundingBox) < Self.area($1.boundingBox) }) {
            update(rect: Self.headFromBody(Self.topLeft(body.boundingBox)), fallback: true)
        } else {
            update(rect: Self.wideRect(around: lastFaceRect), fallback: true)
        }
        return true
    }

    // まだ一度も検出していないときに使う範囲
    var rectOrDefault: CGRect {
        currentRect ?? Self.wideRect(around: nil)
    }

    private func update(rect: CGRect, fallback: Bool) {
        if currentRect == nil || fallback != isFallback {
            segment += 1
        }
        isFallback = fallback
        currentRect = rect
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }

    // Vision は左下原点なので左上原点に直す
    private static func topLeft(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }

    // 髪や耳まで隠れるように、顔の枠より広げて少し上にずらす
    private static func expandFace(_ face: CGRect) -> CGRect {
        let width = face.width * 1.5
        let height = face.height * 1.7
        let center = CGPoint(x: face.midX, y: face.midY - face.height * 0.1)
        return FaceTrack.clamp(CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
    }

    // 上半身の枠の上側を頭とみなす
    private static func headFromBody(_ body: CGRect) -> CGRect {
        let width = body.width * 0.75
        let height = body.height * 0.5
        return FaceTrack.clamp(CGRect(x: body.midX - width / 2, y: body.minY - body.height * 0.05, width: width, height: height))
    }

    // 顔が見えないときは広めに隠す。ただし手元までは隠さないよう、下側は顔の少し下で止める
    static func wideRect(around face: CGRect?) -> CGRect {
        guard let face else {
            return CGRect(x: 0.15, y: 0.0, width: 0.7, height: 0.45)
        }
        let width = face.width * 2.0
        let top = face.minY - face.height * 0.4
        let bottom = face.maxY + face.height * 0.4
        return FaceTrack.clamp(CGRect(x: face.midX - width / 2, y: top, width: width, height: bottom - top))
    }
}
