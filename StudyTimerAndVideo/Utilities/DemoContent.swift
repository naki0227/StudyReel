import AVFoundation
import SwiftData
import SwiftUI
import UIKit

// 紹介動画やスクショを撮るためのデモ表示。起動引数に -StudyReelDemo を付けたときだけ動く。
// カメラのないシミュレータでも、机で勉強している絵（イラスト）を映像の代わりに使う
enum DemoMode {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-StudyReelDemo")
    }

    // 初回の案内（スポットライト）も撮るときは -StudyReelDemoTour
    static var showsTour: Bool {
        ProcessInfo.processInfo.arguments.contains("-StudyReelDemoTour")
    }

    static var showsOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-StudyReelDemoOnboarding")
    }

    // スクショ用に、起動したらすぐ開く画面（-StudyReelDemoScreen share / materials）
    static var screen: String? { value(after: "-StudyReelDemoScreen") }

    // 目標と過去問のデモも入れる（-StudyReelDemoGoal）。ストアのスクショには出さない
    static var showsGoal: Bool {
        isActive && ProcessInfo.processInfo.arguments.contains("-StudyReelDemoGoal")
    }

    // 確認画面で最初に開く道具（-StudyReelDemoTool mosaic など）
    static var reviewTool: String? { value(after: "-StudyReelDemoTool") }

    // 撮影の向き（-StudyReelDemoOrientation landscape）。書かなければ縦向き
    static var orientation: CaptureOrientation {
        value(after: "-StudyReelDemoOrientation").flatMap(CaptureOrientation.init(rawValue:)) ?? .portrait
    }

    private static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard isActive, let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

// 机で勉強している人のイラスト。t（0〜1）でペンや窓の光が少しずつ動く
enum DemoArt {
    struct Palette {
        let wallTop: UIColor
        let wallBottom: UIColor
        let shirt: UIColor
        let light: UIColor
    }

    static let palettes: [Palette] = [
        Palette(wallTop: UIColor(red: 0.86, green: 0.89, blue: 0.92, alpha: 1), wallBottom: UIColor(red: 0.64, green: 0.69, blue: 0.74, alpha: 1), shirt: UIColor(red: 0.20, green: 0.24, blue: 0.29, alpha: 1), light: UIColor(red: 1.0, green: 0.97, blue: 0.90, alpha: 1)),
        Palette(wallTop: UIColor(red: 0.93, green: 0.88, blue: 0.82, alpha: 1), wallBottom: UIColor(red: 0.72, green: 0.64, blue: 0.56, alpha: 1), shirt: UIColor(red: 0.36, green: 0.42, blue: 0.55, alpha: 1), light: UIColor(red: 1.0, green: 0.92, blue: 0.78, alpha: 1)),
        Palette(wallTop: UIColor(red: 0.84, green: 0.90, blue: 0.95, alpha: 1), wallBottom: UIColor(red: 0.58, green: 0.68, blue: 0.80, alpha: 1), shirt: UIColor(red: 0.85, green: 0.86, blue: 0.88, alpha: 1), light: UIColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 1)),
        Palette(wallTop: UIColor(red: 0.88, green: 0.90, blue: 0.86, alpha: 1), wallBottom: UIColor(red: 0.62, green: 0.66, blue: 0.60, alpha: 1), shirt: UIColor(red: 0.55, green: 0.33, blue: 0.30, alpha: 1), light: UIColor(red: 1.0, green: 0.96, blue: 0.86, alpha: 1))
    ]

    // 顔のあたり（0〜1、左上原点）。モザイクの位置にも使う
    static func faceRect(for size: CGSize) -> CGRect {
        let w = size.width, h = size.height
        let base = min(w, h)
        let cx = w * 0.5, cy = h * 0.40
        let fw = base * 0.22, fh = base * 0.28
        return CGRect(x: (cx - fw / 2) / w, y: (cy - fh / 2) / h, width: fw / w, height: fh / h)
    }

    static func image(size: CGSize, palette: Palette, t: Double, mosaic: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(in: context.cgContext, size: size, palette: palette, t: t)
            if mosaic {
                pixelate(context: context.cgContext, size: size)
            }
        }
    }

    private static func draw(in ctx: CGContext, size: CGSize, palette p: Palette, t: Double) {
        let w = size.width, h = size.height
        let base = min(w, h)

        // 壁
        let colors = [p.wallTop.cgColor, p.wallBottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: h), options: [])
        }

        // 窓と差し込む光（少しずつ動く）
        let window = CGRect(x: w * 0.68, y: h * 0.08, width: w * 0.22, height: h * 0.36)
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
        ctx.fill(window)
        ctx.setFillColor(p.light.withAlphaComponent(0.85).cgColor)
        ctx.fill(window.insetBy(dx: window.width * 0.06, dy: window.height * 0.05))
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.10 + 0.06 * sin(t * .pi * 2)).cgColor)
        ctx.move(to: CGPoint(x: window.minX, y: window.maxY))
        ctx.addLine(to: CGPoint(x: window.maxX, y: window.maxY))
        ctx.addLine(to: CGPoint(x: w * (0.55 - 0.05 * t), y: h))
        ctx.addLine(to: CGPoint(x: w * (0.25 - 0.05 * t), y: h))
        ctx.closePath()
        ctx.fillPath()

        // 本棚
        let shelf = CGRect(x: w * 0.06, y: h * 0.30, width: w * 0.16, height: h * 0.34)
        ctx.setFillColor(UIColor(red: 0.55, green: 0.45, blue: 0.36, alpha: 1).cgColor)
        ctx.fill(shelf)
        let bookColors: [UIColor] = [.systemTeal, .systemOrange, .systemIndigo, .systemGreen, .systemPink]
        for row in 0..<2 {
            var x = shelf.minX + shelf.width * 0.06
            for index in 0..<5 {
                let bw = shelf.width * (0.13 + 0.02 * Double(index % 2))
                let bh = shelf.height * (0.34 - 0.04 * Double(index % 3))
                let y = shelf.minY + shelf.height * (0.46 * Double(row) + 0.44) - bh
                ctx.setFillColor(bookColors[(index + row) % bookColors.count].withAlphaComponent(0.75).cgColor)
                ctx.fill(CGRect(x: x, y: y, width: bw, height: bh))
                x += bw + shelf.width * 0.03
            }
        }

        // 体と頭
        let face = faceRect(for: size)
        let faceFrame = CGRect(x: face.minX * w, y: face.minY * h, width: face.width * w, height: face.height * h)
        // 首は短く、肩は広めに（机の下に隠れるので下はそのまま）
        ctx.setFillColor(UIColor(red: 0.80, green: 0.64, blue: 0.53, alpha: 1).cgColor)
        ctx.fill(CGRect(x: w * 0.5 - base * 0.045, y: faceFrame.maxY - faceFrame.height * 0.12, width: base * 0.09, height: base * 0.08))
        ctx.setFillColor(p.shirt.cgColor)
        let shoulders = CGRect(x: w * 0.5 - base * 0.36, y: faceFrame.maxY + base * 0.03, width: base * 0.72, height: base * 0.9)
        ctx.addPath(UIBezierPath(roundedRect: shoulders, cornerRadius: base * 0.22).cgPath)
        ctx.fillPath()
        ctx.setFillColor(UIColor(red: 0.80, green: 0.64, blue: 0.53, alpha: 1).cgColor)
        ctx.fillEllipse(in: faceFrame.insetBy(dx: faceFrame.width * 0.05, dy: faceFrame.height * 0.04))
        ctx.setFillColor(UIColor(red: 0.20, green: 0.15, blue: 0.12, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: faceFrame.minX, y: faceFrame.minY - faceFrame.height * 0.06, width: faceFrame.width, height: faceFrame.height * 0.48))

        // 机とノート
        ctx.setFillColor(UIColor(red: 0.93, green: 0.89, blue: 0.82, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: h * 0.80, width: w, height: h * 0.20))
        let note = CGRect(x: w * 0.5 - base * 0.30, y: h * 0.81, width: base * 0.60, height: h * 0.15)
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(note)
        ctx.setFillColor(UIColor(red: 0.62, green: 0.68, blue: 0.74, alpha: 1).cgColor)
        let lines = Int(2 + t * 5)
        for line in 0..<lines {
            let length = note.width * (line == lines - 1 ? 0.3 + 0.4 * (t * 5).truncatingRemainder(dividingBy: 1) : 0.75)
            ctx.fill(CGRect(x: note.minX + note.width * 0.08, y: note.minY + note.height * (0.16 + 0.12 * Double(line)), width: length, height: max(1, h * 0.004)))
        }

        // ペン（書いている手の動き）
        let penX = note.minX + note.width * (0.2 + 0.5 * abs(sin(t * .pi * 6)))
        ctx.saveGState()
        ctx.translateBy(x: penX, y: note.minY + note.height * 0.5)
        ctx.rotate(by: -0.6)
        ctx.setFillColor(UIColor(red: 0.24, green: 0.29, blue: 0.34, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: base * 0.16, height: base * 0.015))
        ctx.restoreGState()

        // マグカップ
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
        ctx.fill(CGRect(x: w * 0.80, y: h * 0.74, width: base * 0.09, height: base * 0.11))
    }

    private static func pixelate(context ctx: CGContext, size: CGSize) {
        guard let snapshot = ctx.makeImage() else { return }
        let face = faceRect(for: size)
        let rect = CGRect(x: face.minX * size.width, y: face.minY * size.height, width: face.width * size.width, height: face.height * size.height)
            .insetBy(dx: -size.width * 0.02, dy: -size.height * 0.02)
        let block = max(6, min(size.width, size.height) * 0.03)
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.clip()
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                let sample = CGRect(x: x + block / 2, y: y + block / 2, width: 1, height: 1)
                if let pixel = snapshot.cropping(to: sample) {
                    ctx.draw(pixel, in: CGRect(x: x, y: y, width: block, height: block))
                }
                x += block
            }
            y += block
        }
        ctx.restoreGState()
    }

    // 教材の表紙
    static func cover(title: String, color: UIColor) -> UIImage {
        let size = CGSize(width: 300, height: 420)
        return UIGraphicsImageRenderer(size: size).image { context in
            let ctx = context.cgContext
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            ctx.fill(CGRect(x: 0, y: size.height * 0.72, width: size.width, height: size.height * 0.08))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let text = NSAttributedString(string: title, attributes: [
                .font: UIFont.systemFont(ofSize: 40, weight: .heavy),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ])
            text.draw(in: CGRect(x: 20, y: size.height * 0.24, width: size.width - 40, height: size.height * 0.5))
        }
    }

    // 短い動画（タイムラプス風）を書き出す。顔にはモザイクをかけた状態で作る
    static func writeVideo(to url: URL, palette: Palette, size: CGSize = CGSize(width: 540, height: 960), frames: Int = 40, mosaic: Bool) -> Bool {
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return false }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        guard writer.canAdd(input) else { return false }
        writer.add(input)
        guard writer.startWriting() else { return false }
        writer.startSession(atSourceTime: .zero)

        for index in 0..<frames {
            while !input.isReadyForMoreMediaData { usleep(2000) }
            let image = Self.image(size: size, palette: palette, t: Double(index) / Double(frames), mosaic: mosaic)
            guard let pool = adaptor.pixelBufferPool, let cgImage = image.cgImage else { continue }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
            guard let buffer else { continue }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) {
                context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: 10))
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()
        return writer.status == .completed
    }
}

// 録画画面でカメラ映像の代わりに出すイラスト
struct DemoCameraView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 20) / 20
            GeometryReader { geometry in
                Image(uiImage: DemoArt.image(size: CGSize(width: geometry.size.width / 2, height: geometry.size.height / 2), palette: DemoArt.palettes[0], t: t))
                    .resizable()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

// デモ用の記録・教材・動画を用意する
@MainActor
enum DemoSeeder {
    // 画面が出る前に、案内や保存先の設定をデモ用にしておく
    static func applyDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(!DemoMode.showsOnboarding, forKey: OnboardingView.storageKey)
        defaults.set(!DemoMode.showsTour, forKey: CoachTour.homeKey)
        defaults.set(true, forKey: CoachTour.recordingKey)
        defaults.set(false, forKey: RecordingSettings.saveToPhotosKey)
        defaults.set(true, forKey: MediaStore.keepVideoKey)
        defaults.set(DemoMode.orientation.rawValue, forKey: CaptureOrientation.storageKey)
        defaults.set(true, forKey: "debug_preview_seeded_v1")
    }

    static func prepare(context: ModelContext) {
        applyDefaults()
        let defaults = UserDefaults.standard
        // 目標のデモは、ほかのデモの記録がもう入っていても足す。目標なしで起動したら、前の目標と過去問は消す
        if !DemoMode.showsGoal {
            try? context.delete(model: StudyGoal.self)
            try? context.delete(model: PastPaperResult.self)
            try? context.save()
        } else if (try? context.fetchCount(FetchDescriptor<StudyGoal>())) ?? 0 == 0 {
            let materialID = (try? context.fetch(FetchDescriptor<StudyMaterial>()))?.first?.id
            insertGoalDemo(context: context, today: Calendar.current.startOfDay(for: Date()), materialID: materialID)
            try? context.save()
        }
        guard (try? context.fetchCount(FetchDescriptor<StudySession>())) ?? 0 == 0 else { return }

        let subjects = ["数学", "英語", "物理", "国語"]
        defaults.set(subjects, forKey: "subjects")

        let materials = [
            StudyMaterial(name: "青チャート 数学I+A", subject: "数学", coverFileName: MediaStore.storeImage(DemoArt.cover(title: "青チャート\n数学I+A", color: UIColor(red: 0.18, green: 0.37, blue: 0.66, alpha: 1)))),
            StudyMaterial(name: "ターゲット1900", subject: "英語", coverFileName: MediaStore.storeImage(DemoArt.cover(title: "ターゲット\n1900", color: UIColor(red: 0.85, green: 0.27, blue: 0.23, alpha: 1)))),
            StudyMaterial(name: "物理のエッセンス", subject: "物理", coverFileName: MediaStore.storeImage(DemoArt.cover(title: "物理の\nエッセンス", color: UIColor(red: 0.24, green: 0.60, blue: 0.49, alpha: 1)))),
            StudyMaterial(name: "古文単語315", subject: "国語", coverFileName: MediaStore.storeImage(DemoArt.cover(title: "古文単語\n315", color: UIColor(red: 0.79, green: 0.60, blue: 0.23, alpha: 1))))
        ]
        for material in materials {
            context.insert(material)
        }
        MaterialSelection.lastID = materials[0].id

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let plan: [(day: Int, hour: Int, minutes: Int, material: Int, title: String)] = [
            (0, 9, 95, 0, "朝の数学"),
            (0, 14, 50, 1, "図書館で英単語"),
            (1, 20, 80, 2, "物理の問題演習"),
            (2, 10, 120, 0, "数学の復習"),
            (3, 19, 45, 3, "古文単語"),
            (4, 16, 70, 1, "英語長文"),
            (5, 9, 110, 0, "週末の数学"),
            (6, 21, 40, 2, "物理の公式")
        ]

        for (index, item) in plan.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: -item.day, to: today),
                  let date = calendar.date(bySettingHour: item.hour, minute: 0, second: 0, of: day) else { continue }
            let palette = DemoArt.palettes[index % DemoArt.palettes.count]
            let thumbnail = MediaStore.storeImage(DemoArt.image(size: CGSize(width: 720, height: 1280), palette: palette, t: 0.6, mosaic: true))
            var videoName: String?
            if index < 6 {
                let url = MediaStore.directory.appendingPathComponent("demo-\(index).mov")
                if DemoArt.writeVideo(to: url, palette: palette, mosaic: true) {
                    videoName = url.lastPathComponent
                }
            }
            context.insert(StudySession(
                date: date,
                duration: item.minutes * 60,
                subject: materials[item.material].subject,
                recordedAt: date,
                title: item.title,
                thumbnailFileName: thumbnail,
                videoFileName: videoName,
                materialID: materials[item.material].id
            ))
        }

        context.insert(DailyGoal(date: today, targetDuration: 3 * 60 * 60))
        if DemoMode.showsGoal, (try? context.fetchCount(FetchDescriptor<StudyGoal>())) ?? 0 == 0 {
            insertGoalDemo(context: context, today: today, materialID: materials[1].id)
        }
        try? context.save()
    }

    // TOEIC 800点を目指して、公式問題集を何回か解いた例
    private static func insertGoalDemo(context: ModelContext, today: Date, materialID: UUID?) {
        let calendar = Calendar.current
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }
        context.insert(StudyGoal(
            title: L10n.string("TOEIC 800点"),
            deadline: day(56),
            targetScore: 800,
            maxScore: 990,
            targetHours: 300,
            materialIDs: materialID.map { [$0] } ?? [],
            note: L10n.string("毎朝1時間、寝る前に単語30分。"),
            createdAt: day(-12)
        ))
        let parts = [L10n.string("リスニング"), L10n.string("リーディング")]
        let results: [(String, Int, Int, Int, Int)] = [
            ("Test 1", -56, 610, 330, 280), ("Test 2", -42, 640, 345, 295), ("Test 3", -35, 630, 340, 290),
            ("Test 1", -21, 685, 365, 320), ("Test 2", -14, 700, 370, 330), ("Test 1", -1, 715, 380, 335)
        ]
        for (name, offset, score, listening, reading) in results {
            context.insert(PastPaperResult(
                paperName: L10n.format("公式問題集10 %@", name),
                date: day(offset),
                score: score,
                maxScore: 990,
                durationSeconds: 2 * 3600,
                memo: offset == -1 ? L10n.string("Part 7 で時間切れ → 次は1問1分で解く！") : "",
                parts: [ScorePart(name: parts[0], score: listening, maxScore: 495), ScorePart(name: parts[1], score: reading, maxScore: 495)]
            ))
        }
    }

    // 録画を止めたとき、確認画面に渡すデモの動画
    static func recordingResult(sessionStart: Date) -> RecordingResult? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-recording.mov")
        // 撮影の向きに合わせる（横向きなら横長の動画）
        let size = DemoMode.orientation.isLandscape ? CGSize(width: 1280, height: 720) : CGSize(width: 720, height: 1280)
        guard DemoArt.writeVideo(to: url, palette: DemoArt.palettes[0], size: size, frames: 80, mosaic: false) else { return nil }
        let face = DemoArt.faceRect(for: size).insetBy(dx: -0.04, dy: -0.03)
        var track = FaceTrack()
        track.samples = (0..<80).map { index in
            FaceSample(time: Double(index) / 10, elapsed: Double(index * 30), rect: face, segment: 0)
        }
        return RecordingResult(url: url, canvasSize: size, sessionStart: sessionStart, track: track)
    }
}
