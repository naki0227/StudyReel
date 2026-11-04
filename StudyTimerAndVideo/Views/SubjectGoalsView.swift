import SwiftUI

// 教科ごとの1週間の目標時間（Pro）。目標は端末に置く（JSON を1つの文字で持つ）
enum SubjectGoals {
    static let storageKey = "subject_weekly_goals"

    static func decode(_ raw: String) -> [String: Int] {
        guard let data = raw.data(using: .utf8),
              let value = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return value
    }

    static func encode(_ goals: [String: Int]) -> String {
        guard let data = try? JSONEncoder().encode(goals.filter { $0.value > 0 }) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

// 統計の画面に出す「教科ごとの今週の目標」
struct SubjectGoalsSection: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(SubjectGoals.storageKey) private var goalsRaw = ""
    @State private var showEditor = false

    let subjects: [String]
    let sessions: [StudySession]
    var onPro: () -> Void

    private var weekSeconds: [String: Int] {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return [:] }
        var totals: [String: Int] = [:]
        for session in sessions where week.contains(session.date) {
            totals[session.subject, default: 0] += session.duration
        }
        return totals
    }

    var body: some View {
        let goals = SubjectGoals.decode(goalsRaw)
        let totals = weekSeconds
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.string("教科ごとの今週の目標"))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.ink)
                Spacer()
                if storeKit.isProUnlocked {
                    Button(L10n.string("目標を決める")) { showEditor = true }
                        .font(ReelTheme.sans(12, weight: .medium))
                        .foregroundColor(ReelTheme.accentDeep)
                } else {
                    Text("Pro")
                        .font(ReelTheme.sans(11, weight: .semibold))
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }

            if !storeKit.isProUnlocked {
                Button(action: onPro) {
                    Text(L10n.string("「数学 週5時間」のように、教科ごとに目標を決めて進み具合を見られます。"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            } else if goals.isEmpty {
                Text(L10n.string("まだ目標がありません。"))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
            } else {
                ForEach(subjects.filter { goals[$0] != nil }, id: \.self) { subject in
                    let goal = goals[subject] ?? 0
                    let done = totals[subject] ?? 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(subject).font(ReelTheme.sans(13)).foregroundColor(ReelTheme.ink)
                            Spacer()
                            Text("\(Self.text(done)) / \(Self.text(goal * 60))")
                                .font(ReelTheme.sans(12))
                                .foregroundColor(done >= goal * 60 ? ReelTheme.accentDeep : ReelTheme.secondary)
                                .monospacedDigit()
                        }
                        ProgressView(value: min(Double(done) / Double(max(goal * 60, 1)), 1))
                            .tint(ReelTheme.accentDeep)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            SubjectGoalsEditor(subjects: subjects, goalsRaw: $goalsRaw)
        }
    }

    static func text(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 60 { return L10n.format("%d分", minutes) }
        return minutes % 60 == 0 ? L10n.format("%d時間", minutes / 60) : L10n.format("%d時間%d分", minutes / 60, minutes % 60)
    }
}

private struct SubjectGoalsEditor: View {
    @Environment(\.dismiss) private var dismiss
    let subjects: [String]
    @Binding var goalsRaw: String
    @State private var goals: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text(L10n.string("30分ずつ変えられます。0にすると目標を消します。"))) {
                    ForEach(subjects, id: \.self) { subject in
                        Stepper(value: Binding(get: { goals[subject] ?? 0 }, set: { goals[subject] = $0 }), in: 0...3000, step: 30) {
                            HStack {
                                Text(subject)
                                Spacer()
                                Text((goals[subject] ?? 0) == 0 ? L10n.string("なし") : SubjectGoalsSection.text((goals[subject] ?? 0) * 60))
                                    .foregroundColor(ReelTheme.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.string("1週間の目標"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("保存")) {
                        goalsRaw = SubjectGoals.encode(goals)
                        dismiss()
                    }
                }
            }
            .onAppear { goals = SubjectGoals.decode(goalsRaw) }
        }
    }
}
