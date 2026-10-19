import AVKit
import Photos
import SwiftData
import SwiftUI

// 1週間ぶんの動画を、BGM付きの短いVlogにまとめる画面
struct WeeklyVlogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.defaultFont.rawValue
    @Query(sort: \StudySession.date) private var sessions: [StudySession]

    @State private var week: WeeklyVlogWeek = .thisWeek
    @State private var orientation: WeeklyVlogOrientation = .portrait
    @State private var bgm: BGMTrack = .lofiStudy
    @State private var progress: Double?
    @State private var makeTask: Task<Void, Never>?
    @State private var outputURL: URL?
    @State private var player: AVPlayer?
    @State private var showPaywall = false
    @State private var message: String?

    private var weekSessions: [StudySession] {
        guard let interval = week.interval() else { return [] }
        return sessions.filter { interval.contains($0.date) && MediaStore.videoURL(named: $0.videoFileName) != nil }
    }

    private var totalStudy: Int {
        weekSessions.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker(L10n.string("週"), selection: $week) {
                        ForEach(WeeklyVlogWeek.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if weekSessions.isEmpty {
                        emptyState
                    } else if let outputURL, let player {
                        result(url: outputURL, player: player)
                    } else {
                        summary
                        settings
                        makeButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("1週間のVlog"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert(message ?? "", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button(L10n.string("OK"), role: .cancel) {}
            }
            .onChange(of: week) { resetOutput() }
            .onChange(of: orientation) { resetOutput() }
            .onChange(of: bgm) { resetOutput() }
            .onDisappear {
                makeTask?.cancel()
                resetOutput()
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    // MARK: - 作る前

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(week.headline)
                    .font(ReelTheme.serif(22))
                    .foregroundColor(ReelTheme.ink)
                Spacer()
                Text(L10n.format("%d本 · 合計 %@", weekSessions.count, WeeklyVlogMaker.durationText(totalStudy)))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(weekSessions) { session in
                        SessionThumbnail(fileName: session.thumbnailFileName, subject: session.subject)
                            .frame(width: 96, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private var settings: some View {
        ReelCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("向き"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                    Picker(L10n.string("向き"), selection: $orientation) {
                        ForEach(WeeklyVlogOrientation.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("BGM"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(BGMTrack.allCases) { track in
                                bgmChip(track)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func bgmChip(_ track: BGMTrack) -> some View {
        let locked = track.isPro && !storeKit.isProUnlocked
        let selected = bgm == track
        return Button {
            if locked {
                showPaywall = true
            } else {
                bgm = track
            }
        } label: {
            HStack(spacing: 4) {
                Text(track.title)
                if locked {
                    Text("PRO")
                        .font(.system(size: 9, weight: .heavy))
                        .opacity(0.7)
                }
            }
            .font(ReelTheme.sans(13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundColor(selected ? .white : ReelTheme.ink)
            .background(Capsule().fill(selected ? ReelTheme.accentDeep : ReelTheme.accentSoft))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var makeButton: some View {
        if let progress {
            VStack(spacing: 10) {
                ProgressView(value: progress)
                    .tint(ReelTheme.accentDeep)
                HStack {
                    Text(L10n.string("Vlogを作っています"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                    Spacer()
                    Button(L10n.string("キャンセル")) {
                        makeTask?.cancel()
                    }
                    .font(ReelTheme.sans(13))
                }
            }
            .padding(.top, 6)
        } else {
            Button {
                make()
            } label: {
                Text(L10n.string("Vlogを作る"))
                    .font(ReelTheme.sans(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(ReelTheme.accentDeep))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(ReelTheme.accent)
            Text(L10n.string("この週の動画はまだありません"))
                .font(ReelTheme.serif(18))
                .foregroundColor(ReelTheme.ink)
            Text(L10n.string("録画した動画をアプリ内に残しておくと、ここで1本にまとめられます。"))
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - できたあと

    private func result(url: URL, player: AVPlayer) -> some View {
        VStack(spacing: 14) {
            VideoPlayer(player: player)
                .aspectRatio(orientation == .portrait ? 9 / 16 : 16 / 9, contentMode: .fit)
                .frame(maxHeight: 520)
                .clipShape(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous))
                .frame(maxWidth: .infinity)
                .onAppear { player.play() }

            ShareLink(item: url) {
                Label(L10n.string("共有する"), systemImage: "square.and.arrow.up")
                    .font(ReelTheme.sans(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(ReelTheme.accentDeep))
            }

            HStack(spacing: 10) {
                Button {
                    saveToPhotos(url)
                } label: {
                    Label(L10n.string("写真に保存"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(ReelTheme.accentSoft))
                }
                Button {
                    resetOutput()
                } label: {
                    Label(L10n.string("作り直す"), systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(ReelTheme.accentSoft))
                }
            }
            .font(ReelTheme.sans(14, weight: .medium))
            .foregroundColor(ReelTheme.accentDeep)
            .buttonStyle(.plain)
        }
    }

    // MARK: - 動作

    private func make() {
        let clips = WeeklyVlogMaker.clips(from: sessions, in: week)
        guard !clips.isEmpty else { return }
        let isPro = storeKit.isProUnlocked
        let options = WeeklyVlogOptions(
            orientation: orientation,
            bgm: bgm.isPro && !isPro ? .none : bgm,
            font: OverlayFont.resolved(rawValue: overlayFontRaw, isPro: isPro),
            showsWatermark: RecordingSettings.showsWatermark(isPro: isPro),
            headline: week.headline
        )

        progress = 0
        UIApplication.shared.isIdleTimerDisabled = true
        makeTask = Task.detached(priority: .userInitiated) {
            do {
                let url = try await WeeklyVlogMaker.make(clips: clips, options: options) { value in
                    Task { @MainActor in
                        if progress != nil { progress = value }
                    }
                }
                await MainActor.run {
                    UIApplication.shared.isIdleTimerDisabled = false
                    progress = nil
                    if Task.isCancelled {
                        try? FileManager.default.removeItem(at: url)
                        return
                    }
                    outputURL = url
                    player = AVPlayer(url: url)
                }
            } catch {
                let cancelled = error is CancellationError
                await MainActor.run {
                    UIApplication.shared.isIdleTimerDisabled = false
                    progress = nil
                    if !cancelled {
                        message = L10n.string("Vlogを作れませんでした。空き容量を確認してください。")
                    }
                }
            }
        }
    }

    private func resetOutput() {
        player?.pause()
        player = nil
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        outputURL = nil
    }

    private func saveToPhotos(_ url: URL) {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                message = L10n.string("設定アプリで写真への追加を許可してください。")
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
                message = L10n.string("写真に保存しました。")
            } catch {
                message = L10n.string("写真に保存できませんでした。")
            }
        }
    }
}
