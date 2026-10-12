import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.standard.rawValue
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var storeKit: StoreKitManager
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]

    @State private var quietReminderEnabled = StudyNotificationManager.shared.isQuietReminderEnabled
    @State private var showPaywall = false
    
    // 実際のURLやテキストに合わせて変更してください
    let privacyPolicyURL = URL(string: "https://enludus.com/products/studyreel-privacy")!
    let termsOfServiceURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(L10n.string("アプリについて"))) {
                    HStack {
                        Text(L10n.string("バージョン"))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text(L10n.string("通知"))) {
                    Toggle(L10n.string("勉強リマインダー"), isOn: $quietReminderEnabled)
                        .onChange(of: quietReminderEnabled) { _, enabled in
                            Task {
                                let resolved = await StudyNotificationManager.shared.setQuietReminderEnabled(enabled, sessions: sessions)
                                await MainActor.run {
                                    quietReminderEnabled = resolved
                                }
                            }
                        }

                    Text(L10n.string("いつも勉強している時間に、1日1回だけお知らせします。"))
                        .font(.caption)
                        .foregroundColor(.gray)

                    if quietReminderEnabled, let nextReminderDate = StudyInsights.preferredReminderDate(for: sessions) {
                        HStack {
                            Text(L10n.string("次回予定"))
                            Spacer()
                            Text(nextReminderDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section(header: Text(L10n.string("動画"))) {
                    NavigationLink {
                        VideoStyleView()
                    } label: {
                        HStack {
                            Text(L10n.string("文字のフォント"))
                            Spacer()
                            Text(OverlayFont.resolved(rawValue: overlayFontRaw, isPro: storeKit.isProUnlocked).displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text(L10n.string("StudyReel Pro"))) {
                    HStack {
                        Text(L10n.string("Proの状態"))
                        Spacer()
                        Text(storeKit.isProUnlocked ? L10n.string("有効") : L10n.string("未加入"))
                            .foregroundColor(storeKit.isProUnlocked ? .green : .secondary)
                    }

                    Button(storeKit.isProUnlocked ? L10n.string("Proを見る") : L10n.string("Proを始める")) {
                        showPaywall = true
                    }
                }
                
                Section(header: Text(L10n.string("法的情報"))) {
                    Link(L10n.string("プライバシーポリシー"), destination: privacyPolicyURL)
                    Link(L10n.string("利用規約"), destination: termsOfServiceURL)
                    
                    NavigationLink(destination: DisclaimerView()) {
                        Text(L10n.string("免責事項"))
                    }
                }
                
                Section(header: Text(L10n.string("注意事項"))) {
                    Text(L10n.string("撮影した映像は端末内にだけ保存され、外部には送信されません。"))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(L10n.string("長時間の撮影はバッテリーを多く使います。充電しながらの利用がおすすめです。"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle(L10n.string("設定・情報"))
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("閉じる")) {
                        dismiss()
                    }
                }
            }
        }
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

#Preview {
    SettingsView()
        .environmentObject(StoreKitManager())
}
