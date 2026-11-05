import FamilyControls
import SwiftUI

// 設定の「撮影中は SNS を開けなくする」。オンにするときにスクリーンタイムの許可を求め、止めるアプリを選んでもらう
struct FocusShieldSettings: View {
    @ObservedObject private var shield = FocusShield.shared
    @AppStorage(FocusShield.enabledKey) private var enabled = false
    @State private var showPicker = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            ReelRow(systemImage: "hand.raised", title: L10n.string("撮影中はSNSを開けなくする")) {
                Toggle("", isOn: Binding(get: { enabled && shield.isAuthorized }, set: setEnabled))
                    .labelsHidden()
                    .tint(ReelTheme.accent)
            }
            if enabled && shield.isAuthorized {
                Rectangle().fill(ReelTheme.line).frame(height: 1).padding(.leading, 50)
                Button { showPicker = true } label: {
                    ReelRow(systemImage: "apps.iphone", title: L10n.string("開けなくするアプリ")) {
                        HStack(spacing: 6) {
                            Text(shield.hasSelection ? L10n.format("%d個", shield.selectionCount) : L10n.string("選ぶ"))
                                .font(ReelTheme.sans(13))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(ReelTheme.secondary)
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
        .familyActivityPicker(isPresented: $showPicker, selection: $shield.selection)
        .onAppear { shield.refreshStatus() }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(L10n.string("OK"), role: .cancel) {}
        }
    }

    private func setEnabled(_ on: Bool) {
        guard on else {
            enabled = false
            return
        }
        Task {
            let approved = shield.isAuthorized ? true : await shield.requestAuthorization()
            enabled = approved
            if approved {
                if !shield.hasSelection { showPicker = true }
            } else {
                message = L10n.string("スクリーンタイムの許可が必要です。iPhone の設定 → スクリーンタイムがオンになっているか確かめてください。")
            }
        }
    }
}
