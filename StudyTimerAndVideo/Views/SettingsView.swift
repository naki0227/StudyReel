import SwiftUI
import SwiftData

// 08 設定。必要な項目だけを、テーマカラー・撮影・モザイク・保存先・学習の順に並べる
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeKit: StoreKitManager
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @ObservedObject var subjectManager: SubjectManager

    @AppStorage(RecordingSettings.intervalKey) private var interval: Double = 5
    @AppStorage(RecordingSettings.cameraKey) private var cameraRaw = CameraPosition.front.rawValue
    @AppStorage(RecordingSettings.qualityKey) private var qualityRaw = VideoQuality.hd1080.rawValue
    @AppStorage(RecordingSettings.showLogoKey) private var showLogo = false
    @AppStorage(RecordingSettings.autoMosaicKey) private var autoMosaic = true
    @AppStorage(RecordingSettings.saveToPhotosKey) private var saveToPhotos = true
    @AppStorage(MediaStore.keepVideoKey) private var keepInApp = true
    @AppStorage(CloudBackup.autoBackupKey) private var autoBackup = true
    @AppStorage(ThemeColor.storageKey) private var themeRaw = ThemeColor.sky.rawValue
    @ObservedObject private var cloudBackup = CloudBackup.shared
    @State private var showRestoreConfirm = false
    @State private var backupMessage: String?

    @State private var quietReminderEnabled = StudyNotificationManager.shared.isQuietReminderEnabled
    @State private var showPaywall = false
    // Pro の色を使っている Pro でない人が、ほかの色に変えようとしたとき
    @State private var pendingTheme: ThemeColor?
    @State private var showSubjects = false
    @State private var showTags = false

    let privacyPolicyURL = URL(string: "https://enludus.com/products/studyreel-privacy")!
    let termsOfServiceURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        // 選んだ色をこの画面にもすぐ反映する
        let theme = ThemeColor.apply(rawValue: themeRaw)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle(L10n.string("テーマカラー"))
                    themeCard(selected: theme)
                    if !storeKit.isProUnlocked {
                        note(theme.isPro
                            ? L10n.string("いまの色はそのまま使えます。ほかの色に変えると、Proに入るまで戻せません。")
                            : L10n.string("空色のほかの色は、Proで選べます。"))
                    }

                    sectionTitle(L10n.string("撮影設定"))
                    card {
                        ReelRow(systemImage: "timer", title: L10n.string("撮影間隔")) {
                            Menu {
                                ForEach(RecordingSettings.intervalOptions, id: \.self) { value in
                                    Button(L10n.format("%d秒", Int(value))) { interval = value }
                                }
                            } label: {
                                valueLabel(L10n.format("%d秒", Int(RecordingSettings.intervalOptions.contains(interval) ? interval : 5)))
                            }
                        }
                        divider
                        ReelRow(systemImage: "textformat", title: L10n.string("ロゴの表示")) {
                            if storeKit.isProUnlocked {
                                Toggle("", isOn: $showLogo).labelsHidden().tint(ReelTheme.accent)
                            } else {
                                Button {
                                    showPaywall = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Text("Pro").font(ReelTheme.sans(11, weight: .semibold)).foregroundColor(ReelTheme.accentDeep)
                                        Toggle("", isOn: .constant(true)).labelsHidden().tint(ReelTheme.accent).disabled(true)
                                    }
                                }
                            }
                        }
                        divider
                        ReelRow(systemImage: "camera", title: L10n.string("カメラ")) {
                            Menu {
                                ForEach(CameraPosition.allCases) { item in
                                    Button(item.title) { cameraRaw = item.rawValue }
                                }
                            } label: {
                                valueLabel((CameraPosition(rawValue: cameraRaw) ?? .front).title)
                            }
                        }
                        divider
                        ReelRow(systemImage: "sparkles.tv", title: L10n.string("画質")) {
                            Menu {
                                ForEach(VideoQuality.allCases) { item in
                                    Button(item.title) { qualityRaw = item.rawValue }
                                }
                            } label: {
                                valueLabel((VideoQuality(rawValue: qualityRaw) ?? .hd1080).title)
                            }
                        }
                        divider
                        NavigationLink {
                            VideoStyleView()
                        } label: {
                            ReelRow(systemImage: "character.cursor.ibeam", title: L10n.string("文字と顔の隠し方")) {
                                chevron
                            }
                        }
                    }

                    sectionTitle(L10n.string("モザイク設定"))
                    card {
                        ReelRow(systemImage: "face.dashed", title: L10n.string("人の顔を自動でモザイク")) {
                            Toggle("", isOn: $autoMosaic).labelsHidden().tint(ReelTheme.accent)
                        }
                    }
                    note(L10n.string("※ 顔の検出は端末内で処理されます"))

                    sectionTitle(L10n.string("保存先"))
                    card {
                        ReelRow(systemImage: "photo.on.rectangle", title: L10n.string("写真フォルダに保存")) {
                            Toggle("", isOn: $saveToPhotos).labelsHidden().tint(ReelTheme.accent)
                                .disabled(saveToPhotos && !keepInApp)
                        }
                        divider
                        ReelRow(systemImage: "internaldrive", title: L10n.string("端末内にも保存")) {
                            Toggle("", isOn: $keepInApp).labelsHidden().tint(ReelTheme.accent)
                                .disabled(keepInApp && !saveToPhotos)
                        }
                    }
                    note(L10n.string("アプリ内に残すと、写真アプリから消しても見返せます（オフラインで閲覧可能）。"))

                    sectionTitle(L10n.string("学習"))
                    card {
                        Button { showSubjects = true } label: {
                            ReelRow(systemImage: "book.closed", title: L10n.string("教科の編集")) { chevron }
                        }
                        divider
                        Button { showTags = true } label: {
                            ReelRow(systemImage: "tag", title: L10n.string("タグの編集")) { chevron }
                        }
                        divider
                        ReelRow(systemImage: "bell", title: L10n.string("勉強リマインダー")) {
                            Toggle("", isOn: $quietReminderEnabled).labelsHidden().tint(ReelTheme.accent)
                        }
                    }
                    if quietReminderEnabled, let next = StudyInsights.preferredReminderDate(for: sessions) {
                        note(L10n.format("次回 %@", next.formatted(date: .abbreviated, time: .shortened)))
                    } else {
                        note(L10n.string("いつも勉強している時間に、1日1回だけお知らせします。"))
                    }

                    sectionTitle(L10n.string("iCloudバックアップ"))
                    backupCard
                    note(backupNote)

                    sectionTitle(L10n.string("StudyReel Pro"))
                    card {
                        Button { showPaywall = true } label: {
                            ReelRow(systemImage: "star", title: storeKit.isProUnlocked ? L10n.string("Proは有効です") : L10n.string("Proを始める")) {
                                chevron
                            }
                        }
                    }

                    sectionTitle(L10n.string("その他"))
                    card {
                        Button {
                            // 閉じてホームに戻ると、ホームの案内から出し直す
                            CoachTour.reset()
                            dismiss()
                        } label: {
                            ReelRow(systemImage: "questionmark.circle", title: L10n.string("使い方をもう一度見る")) { chevron }
                        }
                        divider
                        Link(destination: privacyPolicyURL) {
                            ReelRow(systemImage: "hand.raised", title: L10n.string("プライバシーポリシー")) { chevron }
                        }
                        divider
                        Link(destination: termsOfServiceURL) {
                            ReelRow(systemImage: "doc.text", title: L10n.string("利用規約")) { chevron }
                        }
                        divider
                        NavigationLink(destination: DisclaimerView()) {
                            ReelRow(systemImage: "exclamationmark.circle", title: L10n.string("免責事項")) { chevron }
                        }
                        divider
                        ReelRow(systemImage: "info.circle", title: L10n.string("バージョン")) {
                            valueLabel(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        }
                    }
                    note(L10n.string("長時間の撮影はバッテリーを多く使います。充電しながらの利用がおすすめです。"))
                }
                .padding(16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            // 見出しは左上に置くと iOS 26 で「…」にまとめられるので、上の真ん中に出す
            .navigationTitle(L10n.string("設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }
            .onChange(of: quietReminderEnabled) { _, enabled in
                Task {
                    let resolved = await StudyNotificationManager.shared.setQuietReminderEnabled(enabled, sessions: sessions)
                    await MainActor.run {
                        quietReminderEnabled = resolved
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert(
                L10n.string("色を変えますか？"),
                isPresented: Binding(get: { pendingTheme != nil }, set: { if !$0 { pendingTheme = nil } }),
                presenting: pendingTheme
            ) { color in
                Button(L10n.string("キャンセル"), role: .cancel) {}
                Button(L10n.format("%@にする", color.title)) { themeRaw = color.rawValue }
            } message: { _ in
                Text(L10n.format("いまの「%@」はProの色です。変えると、Proに入るまで戻せません。", theme.title))
            }
            .alert(L10n.string("バックアップから戻しますか？"), isPresented: $showRestoreConfirm) {
                Button(L10n.string("キャンセル"), role: .cancel) {}
                Button(L10n.string("戻す")) { restoreBackup() }
            } message: {
                Text(L10n.string("今ある記録は消さずに、バックアップにだけある記録を足します。"))
            }
            .alert(
                backupMessage ?? "",
                isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })
            ) {
                Button(L10n.string("OK")) {}
            }
            .sheet(isPresented: $showSubjects) {
                SubjectEditView(subjectManager: subjectManager)
            }
            .sheet(isPresented: $showTags) {
                TagManagerView()
            }
        }
    }

    // MARK: - iCloudバックアップ

    private var backupCard: some View {
        card {
            ReelRow(systemImage: "icloud", title: L10n.string("自動でバックアップ")) {
                Toggle("", isOn: $autoBackup).labelsHidden().tint(ReelTheme.accent)
            }
            divider
            Button { backupNow() } label: {
                ReelRow(systemImage: "arrow.up.to.line", title: L10n.string("今すぐバックアップ")) {
                    if cloudBackup.isWorking {
                        ProgressView()
                    } else {
                        chevron
                    }
                }
            }
            .disabled(cloudBackup.isWorking)
            divider
            Button { showRestoreConfirm = true } label: {
                ReelRow(systemImage: "arrow.down.to.line", title: L10n.string("バックアップから戻す")) { chevron }
            }
            .disabled(cloudBackup.isWorking)
        }
    }

    private var backupNote: String {
        if let last = cloudBackup.lastBackupDate {
            return L10n.format("最後のバックアップ %@", last.formatted(date: .abbreviated, time: .shortened))
        }
        return L10n.string("記録と動画をiCloudに残します。ファイルアプリの「StudyReel」フォルダから家族にも共有できます。")
    }

    private func backupNow() {
        Task {
            do {
                try await cloudBackup.backupNow(context: modelContext)
                backupMessage = L10n.string("バックアップしました。")
            } catch {
                backupMessage = error.localizedDescription
            }
        }
    }

    private func restoreBackup() {
        Task {
            do {
                let count = try await cloudBackup.restore(context: modelContext)
                backupMessage = L10n.format("%d件の記録を戻しました。", count)
            } catch {
                backupMessage = error.localizedDescription
            }
        }
    }

    // 8色から選ぶ。Proでない人が空色以外を押したら、Proの案内を出す。
    // Proのときに選んだ色はProが終わっても使えるが、変えると戻せないので先に確かめる
    private func themeCard(selected: ThemeColor) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 14) {
            ForEach(ThemeColor.allCases) { color in
                let locked = color.isPro && !storeKit.isProUnlocked && color != selected
                Button {
                    if color == selected {
                        return
                    } else if locked {
                        showPaywall = true
                    } else if selected.isPro && !storeKit.isProUnlocked {
                        pendingTheme = color
                    } else {
                        themeRaw = color.rawValue
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(color.accent)
                                .frame(width: 36, height: 36)
                            if color == selected {
                                Circle()
                                    .stroke(color.accentDeep, lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(color.accentDeep)
                            } else if locked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(color.accentDeep.opacity(0.8))
                            }
                        }
                        .frame(width: 46, height: 46)
                        Text(color.title)
                            .font(ReelTheme.sans(10))
                            .foregroundColor(color == selected ? ReelTheme.ink : ReelTheme.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(locked ? L10n.format("%@（Pro）", color.title) : color.title)
                .accessibilityAddTraits(color == selected ? .isSelected : [])
                .accessibilityIdentifier("theme.\(color.rawValue)")
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(ReelTheme.sans(12))
            .foregroundColor(ReelTheme.secondary)
            .padding(.top, 14)
            .padding(.leading, 4)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(ReelTheme.sans(11))
            .foregroundColor(ReelTheme.secondary)
            .padding(.horizontal, 4)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
    }

    private var divider: some View {
        Rectangle()
            .fill(ReelTheme.line)
            .frame(height: 1)
            .padding(.leading, 50)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12))
            .foregroundColor(ReelTheme.secondary)
    }

    private func valueLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(ReelTheme.sans(13))
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
        }
        .foregroundColor(ReelTheme.secondary)
    }
}

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string("免責事項"))
                    .font(.title)
                    .bold()
                
                Text(L10n.string("本アプリ「StudyReel」の利用により発生したいかなる損害（データ消失、バッテリー消耗、端末の不具合など）についても、開発者は一切の責任を負いません。\n\n本アプリは、ユーザーの学習を支援することを目的としていますが、その効果を保証するものではありません。\n\n撮影された動画はユーザー自身の責任において管理してください。"))
                .padding(.top)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(L10n.string("免責事項"))
    }
}

