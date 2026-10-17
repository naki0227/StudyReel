import SwiftUI
import AVFoundation
import Photos

// 録画後、保存する前に動画を見てモザイクの位置を確かめる画面
struct VideoReviewView: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.standard.rawValue
    @AppStorage(FaceHideStyle.storageKey) private var hideStyleRaw = FaceHideStyle.mosaic.rawValue
    @AppStorage(FaceStamp.storageKey) private var stamp = FaceStamp.defaultStamp

    @StateObject private var player: ReviewPlayer
    @State private var result: RecordingResult
    @State private var saveOption: VideoSaveOption = RecordingSettings.autoMosaic ? .hidden : .plain
    @State private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1
    @State private var exportProgress: Double?
    @State private var showDiscardConfirm = false
    @State private var showPaywall = false
    @State private var storedVideoName: String?

    // 写真への保存結果（保存できたら true、保存しなかったら nil、失敗したら false）と、アプリ内に残したサムネイル・動画
    let onFinish: (Bool?, SessionMedia) -> Void

    init(result: RecordingResult, onFinish: @escaping (Bool?, SessionMedia) -> Void) {
        _result = State(initialValue: result)
        _player = StateObject(wrappedValue: ReviewPlayer(url: result.url))
        self.onFinish = onFinish
    }

    private var hideStyle: FaceHideStyle {
        FaceHideStyle.resolved(rawValue: hideStyleRaw, isPro: storeKit.isProUnlocked)
    }

    private var showsFaceBox: Bool {
        saveOption != .plain
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                GeometryReader { geometry in
                    let videoRect = AVMakeRect(aspectRatio: result.canvasSize, insideRect: CGRect(origin: .zero, size: geometry.size))
                    ZStack {
                        PlayerLayerView(player: player.player)
                            .frame(width: videoRect.width, height: videoRect.height)
                            .position(x: videoRect.midX, y: videoRect.midY)

                        if showsFaceBox, let rect = displayedFaceRect(in: videoRect) {
                            faceBox(size: rect.size)
                                .position(x: rect.midX, y: rect.midY)
                                .gesture(boxGesture(videoRect: videoRect))
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }

                if showsFaceBox {
                    Text(L10n.string("ずれていたらドラッグで動かせます。ピンチで大きさも変えられます。"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                playbackControls
                optionsPanel
            }
            .padding(16)
            .disabled(exportProgress != nil)

            if let exportProgress {
                exportOverlay(progress: exportProgress)
            }
        }
        .onAppear { player.play() }
        .onDisappear { player.pause() }
        .alert(L10n.string("動画を保存せずに閉じますか？"), isPresented: $showDiscardConfirm) {
            Button(L10n.string("戻る"), role: .cancel) {}
            Button(L10n.string("保存しない"), role: .destructive) {
                finish(outcome: nil)
            }
        } message: {
            Text(L10n.string("勉強時間の記録は、このあと保存できます。"))
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var header: some View {
        HStack {
            Button(L10n.string("保存しない")) {
                showDiscardConfirm = true
            }
            .foregroundColor(.white.opacity(0.85))
            Spacer()
            Text(L10n.string("動画を確認"))
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(L10n.string("保存")) {
                startExport()
            }
            .font(.headline)
            .foregroundColor(AppPalette.sky)
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                player.togglePlay()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Slider(
                value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                in: 0...max(player.duration, 0.1),
                onEditingChanged: { editing in
                    if editing { player.pause() }
                }
            )
            .tint(AppPalette.sky)
        }
    }

    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(L10n.string("保存する動画"), selection: $saveOption) {
                ForEach(VideoSaveOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if showsFaceBox {
                Picker(L10n.string("隠し方"), selection: Binding(
                    get: { hideStyle },
                    set: { newValue in
                        if newValue.isPro && !storeKit.isProUnlocked {
                            showPaywall = true
                        } else {
                            hideStyleRaw = newValue.rawValue
                        }
                    }
                )) {
                    ForEach(FaceHideStyle.allCases) { style in
                        Text(style.isPro && !storeKit.isProUnlocked ? "\(style.title) (Pro)" : style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                if hideStyle == .stamp {
                    HStack(spacing: 8) {
                        ForEach(FaceStamp.options, id: \.self) { option in
                            Button {
                                stamp = option
                            } label: {
                                Text(option)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(option == stamp ? Color.white.opacity(0.25) : Color.clear)
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    @ViewBuilder
    private func faceBox(size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ZStack {
            if hideStyle == .stamp {
                Text(stamp)
                    .font(.system(size: max(size.width, size.height) * 0.85))
            } else {
                shape.fill(.ultraThinMaterial)
            }
            shape.stroke(Color.white, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
    }

    private func displayedFaceRect(in videoRect: CGRect) -> CGRect? {
        guard var rect = result.track.rect(at: player.currentTime) else { return nil }
        // 操作中の移動・拡大をその場で反映する
        rect = FaceTrack.apply(
            FaceAdjustment(
                offset: CGSize(width: dragOffset.width / videoRect.width, height: dragOffset.height / videoRect.height),
                scale: pinchScale
            ),
            to: rect
        )
        return CGRect(
            x: videoRect.minX + rect.minX * videoRect.width,
            y: videoRect.minY + rect.minY * videoRect.height,
            width: rect.width * videoRect.width,
            height: rect.height * videoRect.height
        )
    }

    // 動かした量は、いま表示している区間（顔を検出し続けている間、または見失っている間）全体に反映する
    private func boxGesture(videoRect: CGRect) -> some Gesture {
        let drag = DragGesture()
            .onChanged { value in
                player.pause()
                dragOffset = value.translation
            }
            .onEnded { value in
                commitAdjustment(
                    offset: CGSize(width: value.translation.width / videoRect.width, height: value.translation.height / videoRect.height),
                    scale: 1
                )
                dragOffset = .zero
            }

        let pinch = MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                commitAdjustment(offset: .zero, scale: value)
            }

        return drag.simultaneously(with: pinch)
    }

    private func commitAdjustment(offset: CGSize, scale: CGFloat) {
        guard let segment = result.track.segment(at: player.currentTime) else { return }
        var adjustment = result.track.adjustments[segment] ?? FaceAdjustment()
        adjustment.offset.width += offset.width
        adjustment.offset.height += offset.height
        adjustment.scale = min(max(adjustment.scale * scale, 0.3), 4)
        result.track.adjustments[segment] = adjustment
    }

    private func exportOverlay(progress: Double) -> some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
                .tint(AppPalette.sky)
                .frame(width: 220)
            Text(L10n.format("書き出し中… %d%%", Int(progress * 100)))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.8))
        )
    }

    // MARK: - 書き出しと保存

    private func startExport() {
        player.pause()
        let overlay = VideoOverlayStyle(
            font: OverlayFont.resolved(rawValue: overlayFontRaw, isPro: storeKit.isProUnlocked),
            showsWatermark: RecordingSettings.showsWatermark(isPro: storeKit.isProUnlocked)
        )
        let base = VideoExportOptions(hidesFaces: true, hideStyle: hideStyle, stamp: stamp, overlay: overlay)

        var jobs: [VideoExportOptions] = []
        if saveOption != .plain { jobs.append(base) }
        if saveOption != .hidden {
            var plain = base
            plain.hidesFaces = false
            jobs.append(plain)
        }

        exportProgress = 0
        runExports(jobs, index: 0, savedAll: true)
    }

    private func runExports(_ jobs: [VideoExportOptions], index: Int, savedAll: Bool) {
        guard index < jobs.count else {
            finish(outcome: savedAll)
            return
        }

        let total = Double(jobs.count)
        VideoExporter.export(
            result: result,
            options: jobs[index],
            progress: { value in
                exportProgress = (Double(index) + value) / total
            },
            completion: { url in
                guard let url else {
                    runExports(jobs, index: index + 1, savedAll: false)
                    return
                }
                // 端末内にも残す設定なら、最初に書き出せた動画（モザイクありを優先）をコピーしておく
                if storedVideoName == nil && MediaStore.keepsVideoInApp {
                    storedVideoName = MediaStore.storeVideo(copying: url)
                }
                // 写真に保存しない設定なら、アプリ内に残せたかどうかを結果にする
                guard RecordingSettings.savesToPhotos else {
                    try? FileManager.default.removeItem(at: url)
                    runExports(jobs, index: index + 1, savedAll: savedAll && storedVideoName != nil)
                    return
                }
                saveToPhotos(url) { success in
                    runExports(jobs, index: index + 1, savedAll: savedAll && success)
                }
            }
        )
    }

    // サムネイルを作ってから素の録画を消し、呼び出し元に返す
    private func finish(outcome: Bool?) {
        MediaStore.makeThumbnail(from: result) { thumbnail in
            try? FileManager.default.removeItem(at: result.url)
            exportProgress = nil
            onFinish(outcome, SessionMedia(thumbnailFileName: thumbnail, videoFileName: storedVideoName))
        }
    }

    private func saveToPhotos(_ url: URL, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, _ in
            try? FileManager.default.removeItem(at: url)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}

// MARK: - 再生

final class ReviewPlayer: ObservableObject {
    let player: AVPlayer
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isPlaying = false

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(url: URL) {
        player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if let itemDuration = self.player.currentItem?.duration.seconds, itemDuration.isFinite {
                self.duration = itemDuration
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func play() {
        if duration > 0, currentTime >= duration - 0.05 {
            seek(to: 0)
        }
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: Double) {
        currentTime = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}
}

private final class PlayerUIView: UIView {
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
}
