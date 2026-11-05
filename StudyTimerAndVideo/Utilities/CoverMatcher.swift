import UIKit
import Vision

// カメラに見せた本の表紙が、登録してある教材のどれかを端末の中だけで当てる。
// 1. 表紙の文字を読み、教材の名前と比べる（いちばん当たりやすい）
// 2. 文字で決まらなければ、登録した表紙の画像と見た目の近さを比べる
enum CoverMatcher {
    struct Candidate {
        let id: UUID
        let name: String
        let cover: UIImage?
    }

    static func match(_ photo: UIImage, in candidates: [Candidate]) async -> UUID? {
        guard !candidates.isEmpty else { return nil }
        let lines = await CoverTextReader.candidates(in: photo)
        if let byText = bestByText(lines: lines, candidates: candidates) {
            return byText
        }
        return await Task.detached(priority: .userInitiated) {
            bestByLook(photo: photo, candidates: candidates)
        }.value
    }

    // MARK: - 文字

    static func bestByText(lines: [String], candidates: [Candidate]) -> UUID? {
        let read = lines.map(normalize).filter { $0.count >= 2 }
        guard !read.isEmpty else { return nil }
        var best: (id: UUID, score: Double)?
        var second = 0.0
        for candidate in candidates {
            let name = normalize(candidate.name)
            guard name.count >= 2 else { continue }
            let score = read.map { similarity($0, name) }.max() ?? 0
            if let current = best {
                if score > current.score {
                    second = current.score
                    best = (candidate.id, score)
                } else {
                    second = max(second, score)
                }
            } else {
                best = (candidate.id, score)
            }
        }
        // はっきり当たっていて、ほかの教材と取り違えにくいときだけ
        guard let best, best.score >= 0.5, best.score - second >= 0.15 else { return nil }
        return best.id
    }

    static func normalize(_ text: String) -> String {
        text.applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .lowercased()
            .filter { !$0.isWhitespace && !$0.isPunctuation && !$0.isSymbol } ?? text
    }

    // 片方がもう片方を含めば 1。そうでなければ2文字ずつの重なり具合
    static func similarity(_ a: String, _ b: String) -> Double {
        if a.count >= 3 && b.contains(a) { return min(1, Double(a.count) / Double(max(b.count, 1)) + 0.5) }
        if b.count >= 3 && a.contains(b) { return 1 }
        let left = bigrams(a), right = bigrams(b)
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }

    private static func bigrams(_ text: String) -> Set<String> {
        let chars = Array(text)
        guard chars.count >= 2 else { return [] }
        return Set((0..<(chars.count - 1)).map { String(chars[$0...($0 + 1)]) })
    }

    // MARK: - 見た目

    private static func bestByLook(photo: UIImage, candidates: [Candidate]) -> UUID? {
        guard let target = featurePrint(photo) else { return nil }
        var distances: [(UUID, Float)] = []
        for candidate in candidates {
            guard let cover = candidate.cover, let print = featurePrint(cover) else { continue }
            var distance: Float = 0
            guard (try? target.computeDistance(&distance, to: print)) != nil else { continue }
            distances.append((candidate.id, distance))
        }
        let sorted = distances.sorted { $0.1 < $1.1 }
        guard let best = sorted.first else { return nil }
        // 2冊以上あるときは、2番目よりはっきり近いときだけ選ぶ
        if sorted.count >= 2, best.1 > sorted[1].1 * 0.8 { return nil }
        return best.0
    }

    private static func featurePrint(_ image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation(image.imageOrientation))
        guard (try? handler.perform([request])) != nil else { return nil }
        return request.results?.first
    }

    private static func orientation(_ value: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch value {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
