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

    // テーマカラー（-StudyReelDemoTheme mint など）。書かなければ空色
    static var theme: String? { value(after: "-StudyReelDemoTheme") }

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

// 机で勉強している人の写真（朝・昼・夜・伸び）。顔のあたりはモザイクの位置にも使う
enum DemoArt {
    struct Scene {
        let photo: String
        // 顔のあたり（0〜1、左上原点、写真に対して）
        let face: CGRect
    }

    static let scenes: [Scene] = [
        Scene(photo: "demo-morning", face: CGRect(x: 0.282, y: 0.372, width: 0.434, height: 0.264)),
        Scene(photo: "demo-noon", face: CGRect(x: 0.272, y: 0.369, width: 0.41, height: 0.271)),
        Scene(photo: "demo-night", face: CGRect(x: 0.278, y: 0.389, width: 0.413, height: 0.262)),
        Scene(photo: "demo-stretch", face: CGRect(x: 0.058, y: 0.13, width: 0.364, height: 0.27))
    ]

    // 朝から夜まで。タイムラプスの動画に使う（顔の位置がほぼ同じ3枚）
    static let day: [Scene] = Array(scenes.prefix(3))

    private static var cache: [String: UIImage] = [:]
    private static let lock = NSLock()

    private static func photo(_ name: String) -> UIImage? {
        lock.lock(); defer { lock.unlock() }
        if let image = cache[name] { return image }
        let url = Bundle.main.url(forResource: name, withExtension: "jpg")
            ?? Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Resources/Demo")
        guard let url, let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache[name] = image
        return image
    }

    // 写真を size いっぱいに（はみ出す分は切る）置いたときの枠
    private static func fillRect(photo: CGSize, in size: CGSize) -> CGRect {
        let scale = max(size.width / photo.width, size.height / photo.height)
        let w = photo.width * scale, h = photo.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    // 顔のあたり（0〜1、左上原点、size に対して）
    static func faceRect(for size: CGSize, scene: Scene = scenes[0]) -> CGRect {
        let photoSize = photo(scene.photo)?.size ?? CGSize(width: 720, height: 1280)
        let r = fillRect(photo: photoSize, in: size)
        let f = scene.face
        return CGRect(x: (r.minX + f.minX * r.width) / size.width, y: (r.minY + f.minY * r.height) / size.height,
                      width: f.width * r.width / size.width, height: f.height * r.height / size.height)
    }

    static func image(size: CGSize, scene: Scene, mosaic: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            if let image = photo(scene.photo) {
                image.draw(in: fillRect(photo: image.size, in: size))
            } else {
                UIColor(red: 0.64, green: 0.69, blue: 0.74, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            if mosaic {
                pixelate(context: context.cgContext, size: size, face: faceRect(for: size, scene: scene))
            }
        }
    }

    private static func pixelate(context ctx: CGContext, size: CGSize, face: CGRect) {
        guard let snapshot = ctx.makeImage() else { return }
        let rect = CGRect(x: face.minX * size.width, y: face.minY * size.height, width: face.width * size.width, height: face.height * size.height)
        let block = max(6, min(size.width, size.height) * 0.04)
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

    // 何コマ目にどの写真を出すか（写真を順に切り替える）
    static func scene(at index: Int, frames: Int, of scenes: [Scene]) -> Scene {
        scenes[min(scenes.count - 1, index * scenes.count / max(1, frames))]
    }

    // 短い動画（タイムラプス風）を書き出す。写真を順に切り替える
    static func writeVideo(to url: URL, scenes: [Scene], size: CGSize = CGSize(width: 540, height: 960), frames: Int = 40, mosaic: Bool) -> Bool {
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
            let image = Self.image(size: size, scene: scene(at: index, frames: frames, of: scenes), mosaic: mosaic)
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

// 録画画面でカメラ映像の代わりに出す写真
struct DemoCameraView: View {
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: DemoArt.image(size: CGSize(width: geometry.size.width, height: geometry.size.height), scene: DemoArt.scenes[0]))
                .resizable()
                .frame(width: geometry.size.width, height: geometry.size.height)
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
        defaults.set(DemoMode.theme ?? ThemeColor.sky.rawValue, forKey: ThemeColor.storageKey)
        defaults.set(true, forKey: "debug_preview_seeded_v1")
    }

    static func prepare(context: ModelContext) {
        applyDefaults()
        let defaults = UserDefaults.standard
        // 目標と過去問は起動のたびに消して、目標のデモ（-StudyReelDemoGoal）なら入れ直す。
        // 前のテストで作った目標が残っていても、毎回同じ状態から始まる
        try? context.delete(model: StudyGoal.self)
        try? context.delete(model: PastPaperResult.self)
        if DemoMode.showsGoal {
            let materialID = (try? context.fetch(FetchDescriptor<StudyMaterial>()))?.first?.id
            insertGoalDemo(context: context, today: Calendar.current.startOfDay(for: Date()), materialID: materialID)
        }
        try? context.save()
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
            let scene = DemoArt.scenes[index % DemoArt.scenes.count]
            let thumbnail = MediaStore.storeImage(DemoArt.image(size: CGSize(width: 720, height: 1280), scene: scene, mosaic: true))
            var videoName: String?
            if index < 6 {
                let url = MediaStore.directory.appendingPathComponent("demo-\(index).mov")
                if DemoArt.writeVideo(to: url, scenes: DemoArt.day, mosaic: true) {
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
        guard DemoArt.writeVideo(to: url, scenes: DemoArt.day, size: size, frames: 80, mosaic: false) else { return nil }
        var track = FaceTrack()
        track.samples = (0..<80).map { index in
            let face = DemoArt.faceRect(for: size, scene: DemoArt.scene(at: index, frames: 80, of: DemoArt.day))
            return FaceSample(time: Double(index) / 10, elapsed: Double(index * 30), rect: face, segment: 0)
        }
        return RecordingResult(url: url, canvasSize: size, sessionStart: sessionStart, track: track)
    }
}
