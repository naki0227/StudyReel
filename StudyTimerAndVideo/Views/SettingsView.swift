import SwiftUI
import SwiftData

// 08 設定。必要な項目だけを、撮影・モザイク・保存先・学習の順に並べる
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
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

    @State private var quietReminderEnabled = StudyNotificationManager.shared.isQuietReminderEnabled
    @State private var showPaywall = false
    @State private var showSubjects = false
    @State private var showTags = false

    let privacyPolicyURL = URL(string: "https://enludus.com/products/studyreel-privacy")!
    let termsOfServiceURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(L10n.string("設定"))
                        .font(ReelTheme.serif(24))
                        .foregroundColor(ReelTheme.ink)
                }
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
            .sheet(isPresented: $showSubjects) {
                SubjectEditView(subjectManager: subjectManager)
            }
            .sheet(isPresented: $showTags) {
                TagManagerView()
            }
        }
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

