import SwiftUI
import SwiftData

// 今日の目標時間
struct GoalSettingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var goals: [DailyGoal]

    @State private var hours: Int = 1
    @State private var minutes: Int = 0

    private let presets = [1, 2, 3, 4]

    var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var currentGoal: DailyGoal? {
        goals.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Text(L10n.string("今日の目標"))
                    .font(ReelTheme.serif(24))
                    .foregroundColor(ReelTheme.ink)

                Text(hours > 0 ? "\(hours)h \(String(format: "%02d", minutes))m" : "\(minutes)m")
                    .font(ReelTheme.serif(44))
                    .foregroundColor(ReelTheme.ink)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        let isOn = hours == preset && minutes == 0
                        Button {
                            hours = preset
                            minutes = 0
                        } label: {
                            Text(L10n.format("%d時間", preset))
                                .font(ReelTheme.sans(13, weight: isOn ? .medium : .regular))
                                .foregroundColor(isOn ? ReelTheme.accentDeep : ReelTheme.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(isOn ? ReelTheme.accentSoft : ReelTheme.card))
                                .overlay(Capsule().stroke(isOn ? ReelTheme.accent : ReelTheme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 0) {
                    Picker(L10n.string("時間"), selection: $hours) {
                        ForEach(0..<24) { Text(L10n.format("%d時間", $0)).tag($0) }
                    }
                    Picker(L10n.string("分"), selection: $minutes) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text(L10n.format("%d分", $0)).tag($0) }
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 130)
                .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))

                Spacer(minLength: 0)

                Button {
                    saveGoal()
                    dismiss()
                } label: {
                    Text(L10n.string("保存"))
                        .font(ReelTheme.sans(15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
            }
            .padding(24)
            .background(ReelTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.secondary)
                }
            }
            .onAppear {
                if let goal = currentGoal {
                    hours = goal.targetDuration / 3600
                    // 5分刻みに合わせる
                    minutes = ((goal.targetDuration % 3600) / 60) / 5 * 5
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func saveGoal() {
        let totalSeconds = hours * 3600 + minutes * 60

        if let goal = currentGoal {
            goal.targetDuration = totalSeconds
        } else {
            modelContext.insert(DailyGoal(date: today, targetDuration: totalSeconds))
        }
    }
}
