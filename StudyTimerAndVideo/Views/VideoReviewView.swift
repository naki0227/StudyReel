import SwiftUI
import AVFoundation
import Photos

// 03 プレビュー。録画後に動画を見ながら、カット・フィルター・モザイク・BGM を決めて保存する
struct VideoReviewView: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.defaultFont.rawValue
    @AppStorage(FaceHideStyle.storageKey) private var hideStyleRaw = FaceHideStyle.mosaic.rawValue
    @AppStorage(FaceStamp.storageKey) private var stamp = FaceStamp.defaultStamp

    @StateObject private var player: ReviewPlayer
    @State private var result: RecordingResult
    @State private var tool: EditTool = DemoMode.reviewTool.flatMap(EditTool.init(rawValue:)) ?? .cut
    @State private var saveOption: VideoSaveOption = RecordingSettings.autoMosaic ? .hidden : .plain
    @State private var filter: VideoFilter = .none
    @State private var bgm: BGMTrack = .none
    @State private var filmstrip: [UIImage] = []
    @State private var filterPreviews: [VideoFilter: UIImage] = [:]
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

    private var overlayStyle: VideoOverlayStyle {
        VideoOverlayStyle(
            font: OverlayFont.resolved(rawValue: overlayFontRaw, isPro: storeKit.isProUnlocked),
            showsWatermark: RecordingSettings.showsWatermark(isPro: storeKit.isProUnlocked)
        )
    }

    // プレビューに使う見た目。保存したときと同じになる
    private var previewOptions: VideoExportOptions {
        VideoExportOptions(
            hidesFaces: showsFaceBox,
            hideStyle: hideStyle,
            stamp: stamp,
            overlay: overlayStyle,
            filter: filter
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ZStack {
                ReelTheme.background.ignoresSafeArea()

                VStack(spacing: 12) {
                    header
                    if isLandscape {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 10) {
                                videoArea
                                playbackControls
                            }
                            ScrollView {
                                toolPanel
                            }
                            .frame(width: min(360, geometry.size.width * 0.4))
                        }
                    } else {
                        videoArea
                            .frame(maxHeight: geometry.size.height * 0.42)
                        playbackControls
                        ScrollView {
                            toolPanel
                        }
                    }
                }
                .padding(16)
                .disabled(exportProgress != nil)

                if let exportProgress {
                    exportOverlay(progress: exportProgress)
                }
            }
        }
        .onAppear {
            player.applyLook(result: result, options: previewOptions)
            player.play()
            loadPreviews()
        }
        .onDisappear { player.stopAll() }
        .onChange(of: filter) { refreshLook() }
        .onChange(of: saveOption) { refreshLook() }
        .onChange(of: hideStyleRaw) { refreshLook() }
        .onChange(of: stamp) { refreshLook() }
        .onChange(of: bgm) { player.setBGM(bgm) }
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

    // MARK: - Header and video

    private var header: some View {
        HStack {
            Button(L10n.string("保存しない")) {
                showDiscardConfirm = true
            }
            .foregroundColor(ReelTheme.secondary)
            Spacer()
            Text(L10n.string("プレビュー"))
                .font(ReelTheme.serif(18))
                .foregroundColor(ReelTheme.ink)
            Spacer()
            Button(L10n.string("保存")) {
                startExport()
            }
            .font(ReelTheme.sans(15, weight: .semibold))
            .foregroundColor(ReelTheme.accentDeep)
        }
    }

    private var videoArea: some View {
        GeometryReader { geometry in
            let videoRect = AVMakeRect(aspectRatio: result.canvasSize, insideRect: CGRect(origin: .zero, size: geometry.size))
            ZStack {
                PlayerLayerView(player: player.player)
                    .frame(width: videoRect.width, height: videoRect.height)
                    .clipShape(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous))
                    .position(x: videoRect.midX, y: videoRect.midY)

                // モザイクを編集しているときだけ、動かせる枠を出す
                if tool == .mosaic, showsFaceBox, let rect = displayedFaceRect(in: videoRect) {
                    Ellipse()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .background(Ellipse().fill(Color.white.opacity(0.001)))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .gesture(boxGesture(videoRect: videoRect))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var playbackControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    player.togglePlay()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15))
                        .foregroundColor(ReelTheme.ink)
                        .frame(width: 32, height: 32)
                }

                Slider(
                    value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                    in: player.trimStart...max(player.trimEnd, player.trimStart + 0.1),
                    onEditingChanged: { editing in
                        if editing { player.pause() }
                    }
                )
                .tint(ReelTheme.accentDeep)

                Text(timeText(player.trimEnd - player.trimStart))
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
                    .monospacedDigit()
            }

            filmstripView(height: 34)
        }
    }

    // MARK: - Tools

    enum EditTool: String, CaseIterable, Identifiable {
        case cut, filter, mosaic, music

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cut: return L10n.string("カット")
            case .filter: return L10n.string("フィルター")
            case .mosaic: return L10n.string("モザイク")
            case .music: return L10n.string("音楽")
            }
        }

        var icon: String {
            switch self {
            case .cut: return "scissors"
            case .filter: return "camera.filters"
            case .mosaic: return "face.dashed"
            case .music: return "music.note"
            }
        }
    }

    private var toolPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ForEach(EditTool.allCases) { item in
                    Button {
                        tool = item
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .light))
                            Text(item.title)
                                .font(ReelTheme.sans(10))
                        }
                        .foregroundColor(tool == item ? ReelTheme.accentDeep : ReelTheme.secondary)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("review.tool.\(item.rawValue)")
                }
            }
            .padding(.vertical, 6)

            switch tool {
            case .cut: cutPanel
            case .filter: filterPanel
            case .mosaic: mosaicPanel
            case .music: musicPanel
            }
        }
    }

    private var cutPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("使う範囲を選びます"))
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)
            TrimBar(
                duration: player.duration,
                start: Binding(get: { player.trimStart }, set: { player.setTrim(start: $0, end: player.trimEnd) }),
                end: Binding(get: { player.trimEnd }, set: { player.setTrim(start: player.trimStart, end: $0) }),
                frames: filmstrip
            )
            .frame(height: 52)
            HStack {
                Text(timeText(player.trimStart))
                Spacer()
                Text(timeText(player.trimEnd))
            }
            .font(ReelTheme.sans(11))
            .foregroundColor(ReelTheme.secondary)
            .monospacedDigit()
        }
    }

    private var filterPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(VideoFilter.allCases) { item in
                    Button {
                        filter = item
                    } label: {
                        VStack(spacing: 6) {
                            Group {
                                if let image = filterPreviews[item] {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else {
                                    ReelTheme.accentSoft
                                }
                            }
                            .frame(width: 64, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(filter == item ? ReelTheme.accentDeep : Color.clear, lineWidth: 2)
                            )
                            Text(item.title)
                                .font(ReelTheme.sans(11))
                                .foregroundColor(filter == item ? ReelTheme.accentDeep : ReelTheme.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var mosaicPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // モザイクはいつでもオン・オフでき、場面ごとに外すこともできる
            Toggle(isOn: Binding(
                get: { saveOption != .plain },
                set: { saveOption = $0 ? .hidden : .plain }
            )) {
                Text(L10n.string("顔にモザイク"))
                    .font(ReelTheme.sans(14))
                    .foregroundColor(ReelTheme.ink)
            }
            .tint(ReelTheme.accent)

            if showsFaceBox {
                Toggle(isOn: Binding(
                    get: { !isCurrentSegmentDisabled },
                    set: { setCurrentSegment(enabled: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("この場面にもモザイク"))
                            .font(ReelTheme.sans(14))
                            .foregroundColor(ReelTheme.ink)
                        Text(L10n.string("再生している場面だけ、モザイクを外せます"))
                            .font(ReelTheme.sans(11))
                            .foregroundColor(ReelTheme.secondary)
                    }
                }
                .tint(ReelTheme.accent)

                Toggle(isOn: Binding(
                    get: { saveOption == .both },
                    set: { saveOption = $0 ? .both : .hidden }
                )) {
                    Text(L10n.string("モザイクなしの動画も保存"))
                        .font(ReelTheme.sans(14))
                        .foregroundColor(ReelTheme.ink)
                }
                .tint(ReelTheme.accent)

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
                                            .fill(option == stamp ? ReelTheme.accentSoft : Color.clear)
                                    )
                            }
                        }
                    }
                }

                Text(L10n.string("ずれていたらドラッグで動かせます。ピンチで大きさも変えられます。"))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
            }
        }
    }

    private var musicPanel: some View {
        VStack(spacing: 0) {
            ForEach(BGMTrack.allCases) { track in
                Button {
                    if track.isPro && !storeKit.isProUnlocked {
                        showPaywall = true
                    } else {
                        bgm = track
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: track == .none ? "speaker.slash" : "play.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ReelTheme.secondary)
                            .frame(width: 20)
                        Text(track.title)
                            .font(ReelTheme.sans(14))
                            .foregroundColor(ReelTheme.ink)
                        Spacer()
                        if track.isPro && !storeKit.isProUnlocked {
                            Text("Pro")
                                .font(ReelTheme.sans(11, weight: .semibold))
                                .foregroundColor(ReelTheme.accentDeep)
                        } else if bgm == track {
                            Image(systemName: "checkmark")
                                .foregroundColor(ReelTheme.accentDeep)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if track != BGMTrack.allCases.last {
                    Rectangle().fill(ReelTheme.line).frame(height: 1).padding(.leading, 46)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
    }

    private func filmstripView(height: CGFloat) -> some View {
        HStack(spacing: 0) {
            // 画像の大きさで列の幅が広がらないよう、枠を先に決めてから画像を重ねる
            ForEach(Array(filmstrip.enumerated()), id: \.offset) { _, image in
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .overlay(Image(uiImage: image).resizable().scaledToFill())
                    .clipped()
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .opacity(filmstrip.isEmpty ? 0 : 1)
    }

    // MARK: - Helpers

    private func refreshLook() {
        player.applyLook(result: result, options: previewOptions)
    }

    private func loadPreviews() {
        let url = result.url
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: url)
            let duration = asset.duration.seconds
            guard duration.isFinite, duration > 0 else { return }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.maximumSize = CGSize(width: 240, height: 240)

            var frames: [UIImage] = []
            for index in 0..<8 {
                let time = CMTime(seconds: duration * (Double(index) + 0.5) / 8, preferredTimescale: 600)
                if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                    frames.append(UIImage(cgImage: image))
                }
            }

            // フィルターの見本は真ん中の1コマから作る
            var previews: [VideoFilter: UIImage] = [:]
            if let middle = try? generator.copyCGImage(at: CMTime(seconds: duration / 2, preferredTimescale: 600), actualTime: nil) {
                let context = CIContext()
                let source = CIImage(cgImage: middle)
                for item in VideoFilter.allCases {
                    if let output = context.createCGImage(item.apply(to: source), from: source.extent) {
                        previews[item] = UIImage(cgImage: output)
                    }
                }
            }

            DispatchQueue.main.async {
                filmstrip = frames
                filterPreviews = previews
            }
        }
    }

    private func timeText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
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

    private var isCurrentSegmentDisabled: Bool {
        guard let segment = result.track.segment(at: player.currentTime) else { return false }
        return result.track.disabledSegments.contains(segment)
    }

    private func setCurrentSegment(enabled: Bool) {
        guard let segment = result.track.segment(at: player.currentTime) else { return }
        if enabled {
            result.track.disabledSegments.remove(segment)
        } else {
            result.track.disabledSegments.insert(segment)
        }
        refreshLook()
    }

    private func commitAdjustment(offset: CGSize, scale: CGFloat) {
        guard let segment = result.track.segment(at: player.currentTime) else { return }
        var adjustment = result.track.adjustments[segment] ?? FaceAdjustment()
        adjustment.offset.width += offset.width
        adjustment.offset.height += offset.height
        adjustment.scale = min(max(adjustment.scale * scale, 0.3), 4)
        result.track.adjustments[segment] = adjustment
        refreshLook()
    }

    private func exportOverlay(progress: Double) -> some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
                .tint(ReelTheme.accentDeep)
                .frame(width: 220)
            Text(L10n.format("書き出し中… %d%%", Int(progress * 100)))
                .font(ReelTheme.sans(13, weight: .medium))
                .foregroundColor(ReelTheme.ink)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ReelTheme.card)
                .shadow(color: .black.opacity(0.08), radius: 20)
        )
    }

    // MARK: - 書き出しと保存

    private func startExport() {
        player.pause()
        var base = previewOptions
        base.hidesFaces = true
        base.bgm = bgm
        base.trim = player.trimStart...player.trimEnd

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
        player.stopAll()
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

// MARK: - カットの範囲を選ぶバー

private struct TrimBar: View {
    let duration: Double
    @Binding var start: Double
    @Binding var end: Double
    let frames: [UIImage]

    private let handleWidth: CGFloat = 14
    private let minimumLength = 1.0

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width - handleWidth * 2, 1)
            let safeDuration = max(duration, 0.1)
            let startX = CGFloat(start / safeDuration) * width
            let endX = CGFloat(end / safeDuration) * width

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(Array(frames.enumerated()), id: \.offset) { _, image in
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: geometry.size.height)
                            .overlay(Image(uiImage: image).resizable().scaledToFill())
                            .clipped()
                    }
                }
                .padding(.horizontal, handleWidth)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(ReelTheme.accentSoft)

                // 使わない部分は白くかぶせる
                Rectangle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: startX + handleWidth)
                Rectangle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: width - endX + handleWidth)
                    .offset(x: endX + handleWidth)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(ReelTheme.accentDeep, lineWidth: 2)
                    .frame(width: endX - startX + handleWidth * 2)
                    .offset(x: startX)

                handle
                    .offset(x: startX)
                    .gesture(DragGesture(coordinateSpace: .named("trim")).onChanged { value in
                        let seconds = Double((value.location.x - handleWidth / 2) / width) * safeDuration
                        start = min(max(0, seconds), end - minimumLength)
                    })
                handle
                    .offset(x: endX + handleWidth)
                    .gesture(DragGesture(coordinateSpace: .named("trim")).onChanged { value in
                        let seconds = Double((value.location.x - handleWidth * 1.5) / width) * safeDuration
                        end = max(min(safeDuration, seconds), start + minimumLength)
                    })
            }
            .coordinateSpace(name: "trim")
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(ReelTheme.accentDeep)
            .frame(width: handleWidth)
            .overlay(
                Capsule().fill(Color.white).frame(width: 2, height: 16)
            )
            .contentShape(Rectangle().inset(by: -10))
    }
}

// MARK: - 再生

final class ReviewPlayer: ObservableObject {
    let player: AVPlayer
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var trimStart: Double = 0
    @Published private(set) var trimEnd: Double = 0

    private var timeObserver: Any?
    private var audioPlayer: AVAudioPlayer?
    private let asset: AVURLAsset

    init(url: URL) {
        asset = AVURLAsset(url: url)
        player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        player.actionAtItemEnd = .pause

        let seconds = asset.duration.seconds
        if seconds.isFinite, seconds > 0 {
            duration = seconds
            trimEnd = seconds
        }

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            // カットした範囲の終わりまで来たら止める
            if self.isPlaying, time.seconds >= self.trimEnd - 0.02 {
                self.pause()
                self.seek(to: self.trimStart)
            }
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    // フィルター・モザイク・時刻の文字を、保存したときと同じようにプレビューへ反映する
    func applyLook(result: RecordingResult, options: VideoExportOptions) {
        let renderer = VideoExporter.FrameRenderer(result: result, options: options)
        let composition = AVVideoComposition(asset: asset) { request in
            let image = renderer.render(request.sourceImage, at: request.compositionTime.seconds)
            request.finish(with: image, context: nil)
        }
        player.currentItem?.videoComposition = composition
    }

    func setBGM(_ track: BGMTrack) {
        audioPlayer?.stop()
        audioPlayer = nil
        guard let url = track.url, let audio = try? AVAudioPlayer(contentsOf: url) else { return }
        audio.numberOfLoops = -1
        audio.volume = BGMRenderer.volume
        audio.prepareToPlay()
        audioPlayer = audio
        syncAudio()
        if isPlaying { audio.play() }
    }

    func setTrim(start: Double, end: Double) {
        trimStart = start
        trimEnd = end
        if currentTime < start || currentTime > end {
            seek(to: start)
        }
    }

    func play() {
        if currentTime < trimStart || currentTime >= trimEnd - 0.05 {
            seek(to: trimStart)
        }
        player.play()
        syncAudio()
        audioPlayer?.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        audioPlayer?.pause()
        isPlaying = false
    }

    func stopAll() {
        pause()
        audioPlayer?.stop()
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: Double) {
        currentTime = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        syncAudio()
    }

    // BGM は、カットした範囲の頭から鳴り始めるように位置を合わせる
    private func syncAudio() {
        guard let audio = audioPlayer, audio.duration > 0 else { return }
        let offset = max(0, currentTime - trimStart)
        audio.currentTime = offset.truncatingRemainder(dividingBy: audio.duration)
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
