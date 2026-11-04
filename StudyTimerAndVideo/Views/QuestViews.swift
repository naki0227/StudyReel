import SwiftUI
import SwiftData

// ホームのクエスト。いまの段のクエストを並べ、「やってみる」でその画面を開く
struct HomeQuestCard: View {
    @Query private var goals: [DailyGoal]
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @Query private var materials: [StudyMaterial]
    @ObservedObject private var backup = CloudBackup.shared
    @ObservedObject private var buddies = BuddyCloud.shared
    // 交換したら残りのジェムを描き直す
    @AppStorage(Rewards.storageKey) private var unlockedRaw = ""
    @AppStorage("quest_card_collapsed") private var isCollapsed = false
    // 共有や Vlog を開いたら描き直す
    @AppStorage(QuestBook.eventsKey) private var eventsRaw = ""

    let onAction: (QuestAction) -> Void
    let onShop: () -> Void

    private var studyDays: Set<Date> {
        Set(sessions.map { Calendar.current.startOfDay(for: $0.date) })
    }

    private var tiers: [[Quest]] {
        _ = eventsRaw
        return QuestBook.tiers(QuestState(
            hasBackup: backup.lastBackupDate != nil,
            iCloudAvailable: CloudBackup.isAvailable,
            hasDailyGoal: !goals.isEmpty,
            materialCount: materials.count,
            sessionCount: sessions.count,
            hasVideo: sessions.contains { $0.videoFileName != nil },
            streak: StudyStreak.count(days: studyDays),
            studyDayCount: studyDays.count,
            hasBuddies: !buddies.groups.isEmpty
        ))
    }

    private var gems: Int {
        _ = unlockedRaw
        return max(0, QuestBook.earnedGems(tiers, studyDayCount: studyDays.count) - Rewards.spentGems())
    }

    var body: some View {
        let allTiers = tiers
        let current = QuestBook.currentTier(allTiers)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 13))
                    .foregroundColor(ReelTheme.accentDeep)
                if let current {
                    let doneCount = current.quests.filter(\.isDone).count
                    Text(current.index == 0 ? L10n.string("はじめの5つ") : L10n.format("クエスト %d", current.index + 1))
                        .font(ReelTheme.sans(14, weight: .semibold))
                        .foregroundColor(ReelTheme.ink)
                    Text("\(doneCount)/\(current.quests.count)")
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                        .monospacedDigit()
                } else {
                    Text(L10n.string("クエストはすべてクリア"))
                        .font(ReelTheme.sans(14, weight: .semibold))
                        .foregroundColor(ReelTheme.ink)
                }
                Spacer()
                Button(action: onShop) {
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill").font(.system(size: 10))
                        Text("\(gems)").monospacedDigit()
                        Text(L10n.string("交換所"))
                    }
                    .font(ReelTheme.sans(12, weight: .semibold))
                    .foregroundColor(ReelTheme.accentDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(ReelTheme.accentSoft))
                }
                .buttonStyle(.plain)
                if current != nil {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { isCollapsed.toggle() }
                    } label: {
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ReelTheme.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isCollapsed ? L10n.string("開く") : L10n.string("たたむ"))
                }
            }

            if let current, !isCollapsed {
                ForEach(current.quests) { quest in
                    QuestRow(quest: quest) {
                        if let action = quest.action { onAction(action) }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        .onAppear { QuestBook.remember(allTiers) }
        .onChange(of: tiers) { _, newValue in QuestBook.remember(newValue) }
    }
}

private struct QuestRow: View {
    let quest: Quest
    let onStart: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: quest.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(quest.isDone ? ReelTheme.accentDeep : ReelTheme.line)
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title)
                    .font(ReelTheme.sans(13, weight: .medium))
                    .foregroundColor(quest.isDone ? ReelTheme.secondary : ReelTheme.ink)
                    .strikethrough(quest.isDone)
                if !quest.isDone {
                    Text(quest.detail)
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if quest.isDone {
                Text("+\(quest.gems)")
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
                    .monospacedDigit()
            } else if quest.action != nil {
                Button(action: onStart) {
                    Text(L10n.string("やってみる"))
                        .font(ReelTheme.sans(12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// 交換所。テーマの色・顔のスタンプ・動画のフォントと交換できる
struct RewardShopView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeKit: StoreKitManager
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @Query private var goals: [DailyGoal]
    @Query private var materials: [StudyMaterial]
    @ObservedObject private var backup = CloudBackup.shared
    @ObservedObject private var buddies = BuddyCloud.shared
    @AppStorage(Rewards.storageKey) private var unlockedRaw = ""
    @State private var confirming: Reward?

    private var studyDays: Set<Date> {
        Set(sessions.map { Calendar.current.startOfDay(for: $0.date) })
    }

    private var gems: Int {
        _ = unlockedRaw
        let tiers = QuestBook.tiers(QuestState(
            hasBackup: backup.lastBackupDate != nil,
            iCloudAvailable: CloudBackup.isAvailable,
            hasDailyGoal: !goals.isEmpty,
            materialCount: materials.count,
            sessionCount: sessions.count,
            hasVideo: sessions.contains { $0.videoFileName != nil },
            streak: StudyStreak.count(days: studyDays),
            studyDayCount: studyDays.count,
            hasBuddies: !buddies.groups.isEmpty
        ))
        return max(0, QuestBook.earnedGems(tiers, studyDayCount: studyDays.count) - Rewards.spentGems())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "diamond.fill").foregroundColor(ReelTheme.accentDeep)
                        Text(L10n.format("ジェム %d", gems))
                            .font(ReelTheme.sans(17, weight: .semibold))
                            .monospacedDigit()
                    }
                } footer: {
                    Text(storeKit.isProUnlocked
                        ? L10n.string("Pro のあいだは全部使えます。交換したものは、Pro が終わっても使えます。")
                        : L10n.format("クエストをクリアしたり、勉強した日1日ごとに%dジェムもらえます。交換したものは、ずっと使えます。", QuestBook.gemsPerStudyDay))
                }

                section(L10n.string("テーマの色"), kind: .theme)
                section(L10n.string("顔の隠し方"), kind: .hideStyle)
                section(L10n.string("動画の文字のフォント"), kind: .font)
            }
            .navigationTitle(L10n.string("交換所"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                }
            }
            .alert(
                confirming.map { L10n.format("%@と交換しますか？", $0.title) } ?? "",
                isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                presenting: confirming
            ) { reward in
                Button(L10n.format("%dジェムで交換", reward.cost)) {
                    Rewards.unlock(reward.id)
                    unlockedRaw = UserDefaults.standard.string(forKey: Rewards.storageKey) ?? ""
                }
                Button(L10n.string("やめる"), role: .cancel) {}
            }
        }
    }

    private func section(_ title: String, kind: Reward.Kind) -> some View {
        Section(header: Text(title)) {
            ForEach(Rewards.catalog.filter { $0.kind == kind }) { reward in
                let owned = Rewards.isUnlocked(reward.id)
                HStack {
                    Text(reward.title)
                        .font(ReelTheme.sans(14))
                    Spacer()
                    if owned {
                        Label(L10n.string("交換ずみ"), systemImage: "checkmark")
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.secondary)
                    } else {
                        Button {
                            confirming = reward
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "diamond.fill").font(.system(size: 9))
                                Text("\(reward.cost)").monospacedDigit()
                            }
                            .font(ReelTheme.sans(12, weight: .semibold))
                            .foregroundColor(gems >= reward.cost ? .white : ReelTheme.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(gems >= reward.cost ? ReelTheme.accentDeep : ReelTheme.line))
                        }
                        .buttonStyle(.plain)
                        .disabled(gems < reward.cost)
                    }
                }
            }
        }
    }
}
