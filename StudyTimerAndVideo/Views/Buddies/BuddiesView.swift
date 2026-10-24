import SwiftData
import SwiftUI

// 招待リンク（studyreel://buddies/join?t=…&n=…）から開いたときの中身
struct BuddyJoinLink: Identifiable, Equatable {
    let token: String
    let groupName: String
    var id: String { token }

    init?(url: URL) {
        guard url.scheme == "studyreel", url.host == "buddies", url.path == "/join",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let token = items.first(where: { $0.name == "t" })?.value, !token.isEmpty else { return nil }
        self.token = token
        self.groupName = items.first(where: { $0.name == "n" })?.value ?? ""
    }
}

// 勉強仲間の一覧。プロフィール、参加申請、グループを作る
struct BuddiesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeKit: StoreKitManager
    @ObservedObject private var cloud = BuddyCloud.shared
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]

    @State private var joinLink: BuddyJoinLink?
    @State private var showProfile = false
    @State private var showCreate = false
    @State private var showPaywall = false
    @State private var newGroupName = ""
    @State private var sentJoin = false

    init(joinLink: BuddyJoinLink? = nil) {
        _joinLink = State(initialValue: joinLink)
    }

    private var ownedLimit: Int { storeKit.isProUnlocked ? BuddyCloud.proOwnedLimit : BuddyCloud.freeOwnedLimit }
    private var ownedCount: Int { cloud.groups.filter(\.isOwner).count }
    // 参加の申請中も、参加できる数に数える
    private var joinedCount: Int { cloud.groups.filter { !$0.isOwner }.count + cloud.pendingJoins.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch cloud.availability {
                    case .noAccount, .restricted:
                        notice(L10n.string("iCloud にサインインすると、勉強仲間を使えます。設定アプリの一番上から iCloud にサインインしてください。"))
                    case .failed(let text):
                        notice(text)
                    default:
                        content
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(GridPaperBackground().ignoresSafeArea())
            .refreshable {
                await cloud.refresh()
                await cloud.refreshExamCounts()
            }
            .navigationTitle(L10n.string("勉強仲間"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
                if BuddyProfile.isReady, cloud.availability == .available {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showProfile = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel(L10n.string("自分の表示"))
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                BuddyProfileView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert(L10n.string("グループを作る"), isPresented: $showCreate) {
                TextField(L10n.string("グループの名前"), text: $newGroupName)
                Button(L10n.string("作る")) { create() }
                Button(L10n.string("キャンセル"), role: .cancel) {}
            } message: {
                Text(L10n.format("%d文字まで。仲間にだけ見えます", BuddyProfile.maxNicknameLength))
            }
            .alert(L10n.string("お知らせ"), isPresented: Binding(get: { cloud.message != nil }, set: { if !$0 { cloud.message = nil } })) {
                Button(L10n.string("OK")) { cloud.message = nil }
            } message: {
                Text(cloud.message ?? "")
            }
        }
        .tint(ReelTheme.accentDeep)
        .task {
            cloud.updateTotals(sessions)
            await cloud.refresh()
            if !cloud.groups.isEmpty || !cloud.pendingJoins.isEmpty { await BuddyNotifier.requestAuthorization() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !BuddyProfile.isReady {
            BuddyProfileEditor(onSave: { Task { await cloud.refresh() } })
        } else {
            if let joinLink {
                joinCard(joinLink)
            }
            ForEach(cloud.pendingJoins) { pending in
                pendingRow(pending)
            }
            if cloud.groups.isEmpty && cloud.pendingJoins.isEmpty && joinLink == nil {
                emptyState
            }
            ForEach(cloud.groups) { group in
                NavigationLink {
                    BuddyGroupView(groupID: group.id)
                } label: {
                    groupRow(group)
                }
                .buttonStyle(.plain)
            }
            if !cloud.groups.isEmpty || !cloud.pendingJoins.isEmpty {
                createButton
            }
            BuddyExamCard()
            ParentShareTeaser(source: "buddies")
            Text(L10n.string("勉強仲間に見えるのは、ニックネーム、アイコン、いま勉強中かどうか、今日と今週の勉強時間、連続日数だけです。動画やメモは見えません。写真は、オーナーがオンにしたグループで、自分で選んだ1コマ（顔にモザイク）だけを見せられます。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
                .padding(.top, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            GoalScript(text: "study buddies ✦", size: 18)
            Text(L10n.string("友達や知り合いと勉強仲間になると、いま勉強中の人や、今日・今週の勉強時間が見えます。スタンプで応援もできます。"))
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.secondary)
                .multilineTextAlignment(.center)
            createButton
            Text(L10n.string("仲間に入るときは、オーナーから QR コードか招待リンクをもらってください。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }

    private var createButton: some View {
        Button {
            if ownedCount >= ownedLimit {
                // 無料で2つ目を作ろうとしたときに Pro を案内する
                if storeKit.isProUnlocked {
                    cloud.message = L10n.format("作れるグループは%d個までです", ownedLimit)
                } else {
                    showPaywall = true
                }
            } else {
                newGroupName = ""
                showCreate = true
            }
        } label: {
            Label(L10n.string("グループを作る"), systemImage: "plus")
                .font(ReelTheme.sans(15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .frame(minHeight: 46)
                .background(Capsule().fill(ReelTheme.accentDeep))
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("buddies.create")
    }

    private func groupRow(_ group: BuddyCloud.Group) -> some View {
        let blocked = cloud.blocked
        let visible = group.members.filter { !blocked.contains($0.userRecordName) }
        let studying = visible.filter(\.isStudyingNow).count
        let waiting = cloud.requests[group.id]?.count ?? 0
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(ReelTheme.serif(18))
                    .foregroundColor(ReelTheme.ink)
                Text(studying > 0 ? L10n.format("%d人が勉強中 · %d人", studying, visible.count) : L10n.format("%d人", visible.count))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(studying > 0 ? ReelTheme.accentDeep : ReelTheme.secondary)
            }
            Spacer()
            if waiting > 0 {
                Text(L10n.format("申請 %d", waiting))
                    .font(ReelTheme.sans(11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(ReelTheme.accentDeep))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ReelTheme.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func joinCard(_ link: BuddyJoinLink) -> some View {
        TapedPaper {
            VStack(alignment: .leading, spacing: 10) {
                GoalScript(text: "join ✦", size: 14)
                Text(link.groupName.isEmpty ? L10n.string("勉強仲間に参加を申請します") : L10n.format("「%@」に参加を申請します", link.groupName))
                    .font(ReelTheme.serif(18))
                    .foregroundColor(ReelTheme.ink)
                Text(L10n.format("オーナーには「%@ %@」と出ます。オーナーが許可すると参加できます。", BuddyProfile.nickname, BuddyProfile.displayCode(BuddyProfile.code)))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
                HStack {
                    Button(L10n.string("やめる")) { joinLink = nil }
                        .font(ReelTheme.sans(14))
                        .foregroundColor(ReelTheme.secondary)
                    Spacer()
                    Button {
                        requestJoin(link)
                    } label: {
                        Text(L10n.string("申請する"))
                            .font(ReelTheme.sans(14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .frame(minHeight: 40)
                            .background(Capsule().fill(ReelTheme.accentDeep))
                    }
                    .disabled(sentJoin)
                    .accessibilityIdentifier("buddies.join")
                }
            }
        }
        .padding(.top, 8)
    }

    private func pendingRow(_ pending: BuddyCloud.PendingJoin) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "hourglass")
                .foregroundColor(ReelTheme.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(pending.groupName.isEmpty ? L10n.string("参加の申請中") : pending.groupName)
                    .font(ReelTheme.sans(14, weight: .medium))
                    .foregroundColor(ReelTheme.ink)
                Text(L10n.string("オーナーの許可を待っています"))
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
            }
            Spacer()
            Button(L10n.string("取り消す")) {
                Task { await cloud.cancelPending(pending) }
            }
            .font(ReelTheme.sans(12))
            .foregroundColor(ReelTheme.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(ReelTheme.sans(13))
            .foregroundColor(ReelTheme.secondary)
            .multilineTextAlignment(.center)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
    }

    private func create() {
        let name = String(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(BuddyProfile.maxNicknameLength))
        guard !name.isEmpty else { return }
        guard BuddyWordFilter.isAllowed(name) else {
            cloud.message = L10n.string("その名前は使えません")
            return
        }
        Task { _ = await cloud.createGroup(name: name) }
    }

    private func requestJoin(_ link: BuddyJoinLink) {
        guard joinedCount < BuddyCloud.joinLimit else {
            cloud.message = L10n.format("参加できるグループは%d個までです", BuddyCloud.joinLimit)
            return
        }
        sentJoin = true
        Task {
            if await cloud.requestJoin(token: link.token, groupName: link.groupName) {
                joinLink = nil
            }
            sentJoin = false
        }
    }
}

// ニックネームとアイコンを決める（はじめて開いたときと、あとから変えるとき）
struct BuddyProfileEditor: View {
    private let onSave: () -> Void
    @State private var nickname = BuddyProfile.nickname
    @State private var icon = BuddyProfile.icon
    @State private var hidesRanking = BuddyProfile.hidesRanking
    @State private var error: String?

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GoalScript(text: "your name ✦", size: 15)
            Text(L10n.string("仲間に見せる名前とアイコン"))
                .font(ReelTheme.serif(20))
                .foregroundColor(ReelTheme.ink)
            Text(L10n.string("本名や iCloud の名前は使われません。あとから変えられます。"))
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)

            TextField(L10n.string("ニックネーム"), text: $nickname)
                .font(ReelTheme.sans(16))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
                .accessibilityIdentifier("buddies.nickname")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                ForEach(BuddyIcon.allCases) { item in
                    Button {
                        icon = item
                    } label: {
                        BuddyAvatar(icon: item, size: 34)
                            .overlay(Circle().strokeBorder(item == icon ? ReelTheme.accentDeep : .clear, lineWidth: 2).padding(-3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.rawValue)
                }
            }
            .padding(.vertical, 6)

            HStack {
                Text(L10n.string("あなたの番号"))
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.secondary)
                Spacer()
                Text(BuddyProfile.displayCode(BuddyProfile.code))
                    .font(ReelTheme.serif(18))
                    .foregroundColor(ReelTheme.ink)
            }
            Text(L10n.string("参加を申請すると、オーナーには名前とこの番号が出ます。LINE などで番号を伝えておくと安心です。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)

            Toggle(isOn: $hidesRanking) {
                Text(L10n.string("ランキングに出ない"))
                    .font(ReelTheme.sans(14))
                    .foregroundColor(ReelTheme.ink)
            }
            .tint(ReelTheme.accentDeep)

            if let error {
                Text(error)
                    .font(ReelTheme.sans(12))
                    .foregroundColor(.red)
            }

            Button {
                save()
            } label: {
                Text(L10n.string("保存"))
                    .font(ReelTheme.sans(15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Capsule().fill(ReelTheme.accentDeep))
            }
            .accessibilityIdentifier("buddies.profile.save")
        }
        .padding(.top, 8)
    }

    private func save() {
        let name = String(nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(BuddyProfile.maxNicknameLength))
        guard !name.isEmpty else {
            error = L10n.string("ニックネームを入れてください")
            return
        }
        guard BuddyWordFilter.isAllowed(name) else {
            error = L10n.string("その名前は使えません")
            return
        }
        BuddyProfile.nickname = name
        BuddyProfile.icon = icon
        BuddyProfile.hidesRanking = hidesRanking
        error = nil
        BuddyCloud.shared.profileChanged()
        onSave()
    }
}

// プロフィールをあとから変える画面。ブロックした人の一覧もここ
struct BuddyProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloud = BuddyCloud.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BuddyProfileEditor(onSave: { dismiss() })
                    BuddySettingsCard()
                    if !cloud.blocked.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("ブロックした人"))
                                .font(ReelTheme.sans(12))
                                .foregroundColor(ReelTheme.secondary)
                            ForEach(Array(cloud.blocked).sorted(), id: \.self) { name in
                                HStack {
                                    Text(displayName(name))
                                        .font(ReelTheme.sans(14))
                                        .foregroundColor(ReelTheme.ink)
                                    Spacer()
                                    Button(L10n.string("解除")) { cloud.unblock(name) }
                                        .font(ReelTheme.sans(13))
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(GridPaperBackground().ignoresSafeArea())
            .navigationTitle(L10n.string("自分の表示"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private func displayName(_ userRecordName: String) -> String {
        for group in cloud.groups {
            if let member = group.members.first(where: { $0.userRecordName == userRecordName }) {
                return "\(member.nickname) \(BuddyProfile.displayCode(member.code))"
            }
        }
        return L10n.string("グループにいない人")
    }
}

// 丸いアイコン
struct BuddyAvatar: View {
    let icon: BuddyIcon
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: icon.systemImage)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundColor(ReelTheme.accentDeep)
            .frame(width: size, height: size)
            .background(Circle().fill(ReelTheme.accentSoft))
    }
}

// 写真と通知の設定
struct BuddySettingsCard: View {
    @State private var photosOn = BuddyProfile.photosOn
    @State private var stamps = BuddyProfile.notifiesStamps
    @State private var studying = BuddyProfile.notifiesStudying

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $photosOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("写真を見せ合う"))
                        .font(ReelTheme.sans(14))
                        .foregroundColor(ReelTheme.ink)
                    Text(BuddyProfile.isUnder18
                         ? L10n.string("18歳未満の人は、初めはオフになっています。オンにする前に、おうちの人と相談してください。")
                         : L10n.string("オフにすると、仲間の写真が出ず、自分も出せません。"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }
            }
            .onChange(of: photosOn) { _, value in BuddyProfile.photosOn = value }
            Divider()
            Toggle(isOn: $stamps) {
                Text(L10n.string("スタンプが届いたら通知"))
                    .font(ReelTheme.sans(14))
                    .foregroundColor(ReelTheme.ink)
            }
            .onChange(of: stamps) { _, value in BuddyProfile.notifiesStamps = value }
            Toggle(isOn: $studying) {
                Text(L10n.string("仲間が勉強を始めたら通知"))
                    .font(ReelTheme.sans(14))
                    .foregroundColor(ReelTheme.ink)
            }
            .onChange(of: studying) { _, value in BuddyProfile.notifiesStudying = value }
        }
        .tint(ReelTheme.accentDeep)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
    }
}

// 資格ごとの、いま勉強中の人数。名前やアイコンは出さない
struct BuddyExamCard: View {
    @ObservedObject private var cloud = BuddyCloud.shared
    @State private var exam = BuddyProfile.exam

    private var rows: [(BuddyExam, Int)] {
        BuddyExam.allCases
            .map { ($0, cloud.examCounts[$0] ?? 0) }
            .filter { $0.1 > 0 || $0.0 == exam }
            .sorted { $0.1 == $1.1 ? $0.0 == exam : $0.1 > $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GoalScript(text: "exams ✦", size: 14)
            Text(L10n.string("資格ごとの、いま勉強中の人数"))
                .font(ReelTheme.serif(17))
                .foregroundColor(ReelTheme.ink)
            Menu {
                Button(L10n.string("数えない")) { choose(nil) }
                ForEach(BuddyExam.allCases) { item in
                    Button(item.title) { choose(item) }
                }
            } label: {
                HStack {
                    Text(L10n.string("自分を数える資格"))
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                    Spacer()
                    Text(exam?.title ?? L10n.string("数えない"))
                        .font(ReelTheme.sans(14, weight: .medium))
                        .foregroundColor(ReelTheme.accentDeep)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }
            .accessibilityIdentifier("buddies.exam")
            if rows.isEmpty {
                Text(L10n.string("いま勉強中の人はいません"))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
            } else {
                ForEach(rows, id: \.0) { row in
                    let (item, count) = row
                    HStack {
                        Text(item.title)
                            .font(ReelTheme.sans(14, weight: item == exam ? .semibold : .regular))
                            .foregroundColor(ReelTheme.ink)
                        Spacer()
                        Text(L10n.format("いま %d人", count))
                            .font(ReelTheme.serif(15))
                            .foregroundColor(count > 0 ? ReelTheme.accentDeep : ReelTheme.secondary)
                            .monospacedDigit()
                    }
                }
            }
            Text(L10n.string("資格を選ぶと、勉強中だけ人数に数えられます。名前やアイコンは、だれにも出ません。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
        .task { await cloud.refreshExamCounts() }
    }

    private func choose(_ item: BuddyExam?) {
        exam = item
        BuddyProfile.exam = item
        cloud.updatePresence()
        Task { await cloud.refreshExamCounts() }
    }
}
