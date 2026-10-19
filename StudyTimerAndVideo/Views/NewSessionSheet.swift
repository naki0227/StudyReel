import SwiftUI

// ホームの「＋」から開く、新しい記録の設定
struct NewSessionSheet: View {
    @Binding var mode: Mode
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    @Binding var materialID: UUID?
    let onStart: () -> Void

    @State private var showsCustom = false

    private let presets = [25, 50, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(L10n.string("新しい記録"))
                .font(ReelTheme.serif(24))
                .foregroundColor(ReelTheme.ink)

            Picker(L10n.string("計測"), selection: $mode) {
                Text(L10n.string("タイマー")).tag(Mode.timer)
                Text(L10n.string("ストップウォッチ")).tag(Mode.stopwatch)
            }
            .pickerStyle(.segmented)

            if mode == .timer {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.string("時間"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)

                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            chip(L10n.format("%d分", preset), isOn: !showsCustom && isPreset(preset)) {
                                showsCustom = false
                                hours = preset / 60
                                minutes = preset % 60
                                seconds = 0
                            }
                        }
                        chip(L10n.string("カスタム"), isOn: showsCustom || !presets.contains(where: isPreset)) {
                            showsCustom = true
                        }
                    }

                    if showsCustom || !presets.contains(where: isPreset) {
                        HStack(spacing: 0) {
                            Picker(L10n.string("時間"), selection: $hours) {
                                ForEach(0..<13) { Text(L10n.format("%d時間", $0)).tag($0) }
                            }
                            Picker(L10n.string("分"), selection: $minutes) {
                                ForEach(0..<60) { Text(L10n.format("%d分", $0)).tag($0) }
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .onAppear { seconds = 0 }
                    }
                }
            } else {
                Text(L10n.string("終わりの時間を決めずに記録します。"))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.secondary)
            }

            MaterialChooserRow(selection: $materialID)

            Spacer(minLength: 0)

            Button(action: onStart) {
                Text(L10n.string("撮影をはじめる"))
                    .font(ReelTheme.sans(15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(ReelTheme.accentDeep))
            }
            .disabled(mode == .timer && hours == 0 && minutes == 0)
        }
        .padding(24)
        .background(ReelTheme.background.ignoresSafeArea())
    }

    private func isPreset(_ preset: Int) -> Bool {
        hours * 60 + minutes == preset && seconds == 0
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ReelTheme.sans(13, weight: isOn ? .medium : .regular))
                .foregroundColor(isOn ? ReelTheme.accentDeep : ReelTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isOn ? ReelTheme.accentSoft : ReelTheme.card)
                )
                .overlay(Capsule().stroke(isOn ? ReelTheme.accent : ReelTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
