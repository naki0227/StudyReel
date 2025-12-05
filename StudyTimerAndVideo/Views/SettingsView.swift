import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // 実際のURLやテキストに合わせて変更してください
    let privacyPolicyURL = URL(string: "https://garrulous-court-1b7.notion.site/2bea705256988039b6fdd92ffb57a410")!
    let termsOfServiceURL = URL(string: "https://garrulous-court-1b7.notion.site/2bea705256988039b6fdd92ffb57a410")!
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("アプリについて")) {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("法的情報")) {
                    Link("プライバシーポリシー", destination: privacyPolicyURL)
                    Link("利用規約", destination: termsOfServiceURL)
                    
                    NavigationLink(destination: DisclaimerView()) {
                        Text("免責事項")
                    }
                }
                
                Section(header: Text("注意事項")) {
                    Text("・本アプリは学習中の様子を撮影しますが、映像は端末内にのみ保存され、外部サーバーへ送信されることはありません。")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("・長時間の撮影はバッテリーを消費します。充電しながらの使用を推奨します。")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("設定・情報")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
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
                Text("免責事項")
                    .font(.title)
                    .bold()
                
                Text("""
本アプリ「StudyLapse」の利用により発生したいかなる損害（データ消失、バッテリー消耗、端末の不具合など）についても、開発者は一切の責任を負いません。

本アプリは、ユーザーの学習を支援することを目的としていますが、その効果を保証するものではありません。

撮影された動画はユーザー自身の責任において管理してください。
""")
                .padding(.top)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("免責事項")
    }
}

#Preview {
    SettingsView()
}
