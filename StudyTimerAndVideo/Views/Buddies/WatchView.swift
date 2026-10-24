import SwiftData
import SwiftUI

// 見守りの QR（studyreel://watch/join?t=…）から開いたときの中身
struct WatchJoinLink: Identifiable, Equatable {
    let token: String
    var id: String { token }

    init?(url: URL) {
        guard url.scheme == "studyreel", url.host == "watch", url.path == "/join",
              let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "t" })?.value,
              !token.isEmpty else { return nil }
        self.token = token
    }
}

// 保護者・塾に共有（見守り）。見せる人の画面と、見る人（保護者・先生）の画面を1つにまとめる
struct WatchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var watch = WatchCloud.shared
    @ObservedObject private var cloud = BuddyCloud.shared
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]

    @State private var joinLink: WatchJoinLink?
    @State private var stopping: WatchCloud.Sharing?
    @State private var showsSubjects = BuddyProfile.watchShowsSubjects

    init(joinLink: WatchJoinLink? = nil) {
        _joinLink = State(initialValue: joinLink)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch cloud.availability {
                    case .noAccount, .restricted:
                        Text(L10n.string("iCloud にサインインすると使えます"))
                            .font(ReelTheme.sans(13))
                            .foregroundColor(ReelTheme.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    default:
                        if let joinLink {
                            WatchJoinCard(link: joinLink) { self.joinLink = nil }
                        }
                        if !watch.sharings.isEmpty {
                            sharingsCard
                        }
                        WatchFamilyCard()
                        WatchSchoolCard()
                        Text(L10n.string("見せるのは、いま勉強中かどうか、今日・今週の勉強時間（曜日ごと）、4週間の推移、連続日数、最後に勉強した日、ニックネームと番号だけです（教科ごとの時間は、見せる人がオンにしたときだけ）。動画、写真、メモ、記録のタイトル、勉強仲間の中身は見せません。始めるのも止めるのも、見せる人が決めます。"))
                            .font(ReelTheme.sans(11))
                            .foregroundColor(ReelTheme.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(GridPaperBackground().ignoresSafeArea())
            .refreshable { await watch.refresh() }
            .navigationTitle(L10n.string("保護者・塾に共有"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
            }
            .alert(L10n.string("見せるのをやめますか？"), isPresented: Binding(get: { stopping != nil }, set: { if !$0 { stopping = nil } })) {
                Button(L10n.string("やめる"), role: .destructive) {
                    if let stopping { Task { await watch.stopSharing(stopping) } }
                    stopping = nil
                }
                Button(L10n.string("キャンセル"), role: .cancel) { stopping = nil }
            } message: {
                Text(L10n.string("相手には、あなたの勉強状況が見えなくなります。また見せるときは、QR コードを読み直してください。"))
            }
            .alert(L10n.string("お知らせ"), isPresented: Binding(get: { watch.message != nil }, set: { if !$0 { watch.message = nil } })) {
                Button(L10n.string("OK")) { watch.message = nil }
            } message: {
                Text(watch.message ?? "")
            }
        }
        .tint(ReelTheme.accentDeep)
        .task {
            cloud.updateTotals(sessions)
            await cloud.refresh()
            await watch.refresh()
        }
    }

    // MARK: - 自分が見せている相手

    private var sharingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            GoalScript(text: "sharing ✦", size: 14)
            Text(L10n.string("勉強状況を見せている相手"))
                .font(ReelTheme.serif(17))
                .foregroundColor(ReelTheme.ink)
            ForEach(watch.sharings) { sharing in
                HStack(spacing: 12) {
                    Image(systemName: sharing.kind == .family ? "figure.2.and.child.holdinghands" : "building.columns")
                        .foregroundColor(ReelTheme.accentDeep)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sharing.kind == .school ? "\(sharing.schoolName) \(sharing.viewerName)" : sharing.viewerName)
                            .font(ReelTheme.sans(14, weight: .medium))
                            .foregroundColor(ReelTheme.ink)
                        Text(sharing.isAccepted ? L10n.string("見せています") : L10n.string("相手が受け取るのを待っています"))
                            .font(ReelTheme.sans(11))
                            .foregroundColor(sharing.isAccepted ? ReelTheme.accentDeep : ReelTheme.secondary)
                        if !sharing.stamps.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(sharing.stamps) { stamp in
                                    Label(stamp.kind.title, systemImage: stamp.kind.systemImage)
                                        .font(ReelTheme.sans(11))
                                        .foregroundColor(ReelTheme.accentDeep)
                                }
                            }
                        }
                    }
                    Spacer()
                    Button(L10n.string("やめる")) { stopping = sharing }
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ReelTheme.accentSoft.opacity(0.5)))
            }
            Toggle(isOn: $showsSubjects) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("今週の教科ごとの時間も見せる"))
                        .font(ReelTheme.sans(14))
                        .foregroundColor(ReelTheme.ink)
                    Text(L10n.string("教科の名前と時間だけです。オフにすると、次に記録を保存したときに消えます。"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }
            }
            .tint(ReelTheme.accentDeep)
            .onChange(of: showsSubjects) { _, value in
                BuddyProfile.watchShowsSubjects = value
                cloud.profileChanged()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
    }
}

// QR を読んだ人（見せる人）が、だれに何を見せるか確かめて始める
struct WatchJoinCard: View {
    @ObservedObject private var watch = WatchCloud.shared
    private let link: WatchJoinLink
    private let onClose: () -> Void
    @State private var code: WatchCloud.Code?
    @State private var looking = true
    @State private var sending = false
    @State private var profileReady = BuddyProfile.isReady

    init(link: WatchJoinLink, onClose: @escaping () -> Void) {
        self.link = link
        self.onClose = onClose
    }

    var body: some View {
        TapedPaper {
            VStack(alignment: .leading, spacing: 10) {
                GoalScript(text: "share ✦", size: 14)
                if looking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let code {
                    Text(title(code))
                        .font(ReelTheme.serif(18))
                        .foregroundColor(ReelTheme.ink)
                    if watch.isSharing(with: code) {
                        Text(L10n.string("もう見せています。"))
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.secondary)
                        Button(L10n.string("閉じる"), action: onClose)
                            .font(ReelTheme.sans(14))
                    } else if !profileReady {
                        Text(L10n.string("先に、相手に見せる名前とアイコンを決めてください。"))
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.secondary)
                        BuddyProfileEditor(onSave: { profileReady = BuddyProfile.isReady })
                    } else {
                        detail(L10n.string("見せるもの"), L10n.string("いま勉強中かどうか、今日・今週の勉強時間（曜日ごと）、4週間の推移、連続日数、最後に勉強した日。教科ごとの時間は、あとで自分でオンにしたときだけ。名前は「%@ %@」と出ます。"), format: true)
                        detail(L10n.string("見せないもの"), L10n.string("動画、写真、メモ、記録のタイトル、勉強仲間の中身"), format: false)
                        Text(L10n.string("いつでもやめられます。見せている間は、ホームに「共有中」と出ます。"))
                            .font(ReelTheme.sans(11))
                            .foregroundColor(ReelTheme.secondary)
                        HStack {
                            Button(L10n.string("やめる"), action: onClose)
                                .font(ReelTheme.sans(14))
                                .foregroundColor(ReelTheme.secondary)
                            Spacer()
                            Button {
                                sending = true
                                Task {
                                    if await watch.share(with: code) { onClose() }
                                    sending = false
                                }
                            } label: {
                                Text(L10n.string("見せる"))
                                    .font(ReelTheme.sans(14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 26)
                                    .frame(minHeight: 40)
                                    .background(Capsule().fill(ReelTheme.accentDeep))
                            }
                            .disabled(sending)
                            .accessibilityIdentifier("watch.share")
                        }
                    }
                } else {
                    Text(L10n.string("この QR コードは使えなくなっています"))
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                    Button(L10n.string("閉じる"), action: onClose)
                        .font(ReelTheme.sans(14))
                }
            }
        }
        .padding(.top, 8)
        .task {
            code = await watch.lookUp(token: link.token)
            looking = false
        }
    }

    private func title(_ code: WatchCloud.Code) -> String {
        code.kind == .school
            ? L10n.format("「%@ %@」の先生に、勉強時間を見せますか？", code.schoolName, code.name)
            : L10n.format("「%@」に、勉強時間を見せますか？", code.name)
    }

    private func detail(_ heading: String, _ text: String, format: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heading)
                .font(ReelTheme.sans(12, weight: .semibold))
                .foregroundColor(ReelTheme.ink)
            Text(format ? String(format: text, BuddyProfile.nickname, BuddyProfile.displayCode(BuddyProfile.code)) : text)
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)
        }
    }
}

// MARK: - 保護者

struct WatchFamilyCard: View {
    @ObservedObject private var watch = WatchCloud.shared
    @State private var callName = ""
    @State private var creating = false
    @State private var showQR = false
    @State private var confirmEnd = false
    @State private var notifiesStart = BuddyProfile.watchNotifiesStart
    @State private var notifiesWeekly = BuddyProfile.watchNotifiesWeekly

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GoalScript(text: "family ✦", size: 14)
            Text(L10n.string("保護者として見守る"))
                .font(ReelTheme.serif(17))
                .foregroundColor(ReelTheme.ink)
            if let code = watch.familyCode {
                WatchOffersList(code: code)
                if watch.children.isEmpty {
                    Text(L10n.string("お子さんの iPhone のカメラで QR コードを読んでもらい、お子さんが「見せる」を押すと、ここに出ます。"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                }
                ForEach(watch.children) { child in
                    WatchedCard(item: child)
                }
                Button {
                    showQR = true
                } label: {
                    Label(L10n.string("QR コードを見せる"), systemImage: "qrcode")
                        .font(ReelTheme.sans(14, weight: .semibold))
                        .foregroundColor(ReelTheme.accentDeep)
                }
                .accessibilityIdentifier("watch.family.qr")
                Divider()
                Toggle(isOn: $notifiesStart) {
                    Text(L10n.string("今日の勉強を始めたら通知"))
                        .font(ReelTheme.sans(14))
                        .foregroundColor(ReelTheme.ink)
                }
                .onChange(of: notifiesStart) { _, value in BuddyProfile.watchNotifiesStart = value }
                Toggle(isOn: $notifiesWeekly) {
                    Text(L10n.string("日曜の夜に今週の合計を通知"))
                        .font(ReelTheme.sans(14))
                        .foregroundColor(ReelTheme.ink)
                }
                .onChange(of: notifiesWeekly) { _, value in
                    BuddyProfile.watchNotifiesWeekly = value
                }
                Button(L10n.string("見守りを終える")) { confirmEnd = true }
                    .font(ReelTheme.sans(13))
                    .foregroundColor(.red)
                    .sheet(isPresented: $showQR) { WatchQRView(code: code) }
                    .alert(L10n.string("見守りを終えますか？"), isPresented: $confirmEnd) {
                        Button(L10n.string("終える"), role: .destructive) { Task { await watch.deleteCode(code) } }
                        Button(L10n.string("キャンセル"), role: .cancel) {}
                    } message: {
                        Text(L10n.string("お子さんの勉強状況が見えなくなり、今の QR コードも使えなくなります。"))
                    }
            } else {
                Text(L10n.string("お子さんの StudyReel から、勉強時間といま勉強中かどうかを見せてもらえます。QR コードを作って、お子さんに読んでもらってください。見せるかどうかは、お子さんが決めます。"))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
                TextField(L10n.string("お子さんに出る呼び名（例：お母さん）"), text: $callName)
                    .font(ReelTheme.sans(15))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ReelTheme.line.opacity(0.5)))
                    .accessibilityIdentifier("watch.family.name")
                Button {
                    create()
                } label: {
                    Text(L10n.string("QR コードを作る"))
                        .font(ReelTheme.sans(14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
                .disabled(creating)
                .accessibilityIdentifier("watch.family.create")
            }
        }
        .tint(ReelTheme.accentDeep)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
    }

    private func create() {
        let name = String(callName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(BuddyProfile.maxNicknameLength))
        guard !name.isEmpty else {
            watch.message = L10n.string("呼び名を入れてください")
            return
        }
        guard BuddyWordFilter.isAllowed(name) else {
            watch.message = L10n.string("その名前は使えません")
            return
        }
        creating = true
        Task {
            if await watch.createFamilyCode(name: name) != nil {
                showQR = true
                await BuddyNotifier.requestAuthorization()
            }
            creating = false
        }
    }
}

// MARK: - 塾

struct WatchSchoolCard: View {
    @ObservedObject private var watch = WatchCloud.shared
    @State private var schoolCode = ""
    @State private var checking = false
    @State private var showCreate = false
    @State private var className = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GoalScript(text: "school ✦", size: 14)
            Text(L10n.string("塾・教室の先生"))
                .font(ReelTheme.serif(17))
                .foregroundColor(ReelTheme.ink)
            if let school = watch.school, school.isValid {
                HStack {
                    Text(school.name)
                        .font(ReelTheme.sans(14, weight: .semibold))
                        .foregroundColor(ReelTheme.ink)
                    Spacer()
                    // 別の塾のコードに入れ替える（作ったクラスと生徒はそのまま残る）
                    Button(L10n.string("塾コードを変える")) { watch.forgetSchool() }
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                }
                if watch.classes.isEmpty {
                    Text(L10n.string("クラスを作って QR コードを生徒に読んでもらうと、生徒の勉強時間が見られます。生徒どうしはおたがいに見えません。"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                }
                ForEach(watch.classes) { code in
                    NavigationLink {
                        WatchClassView(token: code.token)
                    } label: {
                        classRow(code)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    className = ""
                    showCreate = true
                } label: {
                    Label(L10n.string("クラスを作る"), systemImage: "plus")
                        .font(ReelTheme.sans(14, weight: .semibold))
                        .foregroundColor(ReelTheme.accentDeep)
                }
                .accessibilityIdentifier("watch.school.create")
                .alert(L10n.string("クラスを作る"), isPresented: $showCreate) {
                    TextField(L10n.string("クラスの名前（例：中3 英語）"), text: $className)
                    Button(L10n.string("作る")) { create() }
                    Button(L10n.string("キャンセル"), role: .cancel) {}
                } message: {
                    Text(L10n.format("1クラス%d人まで。生徒の画面に塾の名前と一緒に出ます", school.maxStudents))
                }
            } else {
                if let school = watch.school, !school.isValid {
                    Text(L10n.string("塾コードの期限が切れています。新しいコードを入れてください。"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(.red)
                } else {
                    Text(L10n.string("塾・教室で生徒の勉強時間を見るには、塾コードが必要です。塾コードは Enludus が発行します。"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                }
                HStack(spacing: 10) {
                    TextField(L10n.string("塾コード"), text: $schoolCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(ReelTheme.sans(15))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ReelTheme.line.opacity(0.5)))
                        .accessibilityIdentifier("watch.school.code")
                    Button(L10n.string("確かめる")) {
                        checking = true
                        Task {
                            if await watch.activateSchool(code: schoolCode) { schoolCode = "" }
                            checking = false
                        }
                    }
                    .font(ReelTheme.sans(14, weight: .semibold))
                    .disabled(checking || schoolCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Link(L10n.string("塾コードについて問い合わせる"), destination: URL(string: "https://enludus.com/")!)
                    .font(ReelTheme.sans(12))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
    }

    private func classRow(_ code: WatchCloud.Code) -> some View {
        let students = watch.students(in: code)
        let studying = students.filter(\.member.isStudyingNow).count
        let waiting = watch.offers[code.token]?.count ?? 0
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(code.name)
                    .font(ReelTheme.sans(15, weight: .medium))
                    .foregroundColor(ReelTheme.ink)
                Text(studying > 0 ? L10n.format("%d人が勉強中 · %d人", studying, students.count) : L10n.format("%d人", students.count))
                    .font(ReelTheme.sans(11))
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
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ReelTheme.accentSoft.opacity(0.5)))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func create() {
        let name = String(className.trimmingCharacters(in: .whitespacesAndNewlines).prefix(BuddyProfile.maxNicknameLength))
        guard !name.isEmpty, BuddyWordFilter.isAllowed(name) else { return }
        Task { _ = await watch.createClass(name: name) }
    }
}

// 1つのクラス（先生）。勉強時間の多い順、最近勉強していない人、CSV の書き出し
struct WatchClassView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var watch = WatchCloud.shared
    private let token: String
    @State private var showQR = false
    @State private var confirmClose = false
    @State private var removing: WatchCloud.Watched?
    @State private var stampTarget: WatchCloud.Watched?
    @State private var csvURL: URL?

    init(token: String) {
        self.token = token
    }

    private var code: WatchCloud.Code? { watch.codes.first { $0.token == token } }

    var body: some View {
        ScrollView {
            if let code {
                let students = watch.students(in: code)
                VStack(alignment: .leading, spacing: 16) {
                    WatchOffersList(code: code)
                    if students.isEmpty {
                        Text(L10n.string("右上の QR コードを生徒に読んでもらい、届いた申請を受け取ると、ここに出ます。"))
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.secondary)
                            .padding(.vertical, 20)
                    } else {
                        let quiet = students.filter(\.isQuiet)
                        if !quiet.isEmpty {
                            section(L10n.string("3日以上勉強していない人"), quiet, detail: { lastText($0) })
                        }
                        section(L10n.string("今週の勉強時間"), students.sorted { $0.member.week > $1.member.week }, detail: { buddyDuration($0.member.week) })
                        if let csvURL {
                            ShareLink(item: csvURL) {
                                Label(L10n.string("CSV で書き出す"), systemImage: "square.and.arrow.up")
                                    .font(ReelTheme.sans(14, weight: .semibold))
                                    .foregroundColor(ReelTheme.accentDeep)
                            }
                        }
                    }
                    Text(L10n.format("%d人 / %d人まで。生徒どうしはおたがいに見えません。生徒はいつでも共有をやめられます。", students.count, watch.school?.maxStudents ?? WatchCloud.defaultClassSize))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                    Button(L10n.string("クラスを閉じる")) { confirmClose = true }
                        .font(ReelTheme.sans(13))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(GridPaperBackground().ignoresSafeArea())
        .refreshable { await watch.refresh() }
        .navigationTitle(code?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showQR = true
                } label: {
                    Image(systemName: "qrcode")
                }
                .accessibilityLabel(L10n.string("QR コードを見せる"))
            }
        }
        .sheet(isPresented: $showQR) {
            if let code { WatchQRView(code: code) }
        }
        .sheet(item: $stampTarget) { item in
            WatchStampSheet(item: item)
        }
        .alert(L10n.string("クラスを閉じますか？"), isPresented: $confirmClose) {
            Button(L10n.string("閉じる"), role: .destructive) {
                if let code { Task { await watch.deleteCode(code) } }
            }
            Button(L10n.string("キャンセル"), role: .cancel) {}
        } message: {
            Text(L10n.string("生徒全員の勉強状況が見えなくなり、QR コードも使えなくなります。"))
        }
        .alert(L10n.string("この生徒を外しますか？"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button(L10n.string("外す"), role: .destructive) {
                if let removing { Task { await watch.remove(removing) } }
                removing = nil
            }
            Button(L10n.string("キャンセル"), role: .cancel) { removing = nil }
        } message: {
            Text(L10n.string("生徒の共有も終わります。また見るときは、生徒に QR コードを読み直してもらってください。"))
        }
        .onChange(of: code == nil) { _, gone in
            if gone { dismiss() }
        }
        .task(id: watch.watched) { writeCSV() }
    }

    private func section(_ title: String, _ items: [WatchCloud.Watched], detail: @escaping (WatchCloud.Watched) -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        stampTarget = item
                    } label: {
                        HStack(spacing: 10) {
                            BuddyAvatar(icon: item.member.icon, size: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.member.nickname) \(BuddyProfile.displayCode(item.member.code))")
                                    .font(ReelTheme.sans(14))
                                    .foregroundColor(ReelTheme.ink)
                                Text(item.member.isStudyingNow ? L10n.string("いま勉強中") : L10n.format("%d日連続", item.member.streakDays))
                                    .font(ReelTheme.sans(11))
                                    .foregroundColor(item.member.isStudyingNow ? ReelTheme.accentDeep : ReelTheme.secondary)
                            }
                            Spacer()
                            Text(detail(item))
                                .font(ReelTheme.serif(15))
                                .foregroundColor(ReelTheme.ink)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(L10n.string("外す"), role: .destructive) { removing = item }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
        }
    }

    private func lastText(_ item: WatchCloud.Watched) -> String {
        guard let last = item.member.lastStudiedAt else { return L10n.string("記録なし") }
        return last.formatted(.dateTime.month().day())
    }

    private func writeCSV() {
        guard let code else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(code.name).csv")
        // Excel で文字化けしないように BOM を付ける
        let data = Data([0xEF, 0xBB, 0xBF]) + Data(watch.csv(for: code).utf8)
        csvURL = (try? data.write(to: url)) != nil ? url : nil
    }
}

// 見る人に届いている申し出（受け取る・断る）
struct WatchOffersList: View {
    @ObservedObject private var watch = WatchCloud.shared
    let code: WatchCloud.Code

    var body: some View {
        let offers = watch.offers[code.token] ?? []
        if !offers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("見せたいという申し出"))
                    .font(ReelTheme.sans(12, weight: .semibold))
                    .foregroundColor(ReelTheme.accentDeep)
                ForEach(offers) { offer in
                    HStack(spacing: 10) {
                        BuddyAvatar(icon: offer.icon, size: 30)
                        Text("\(offer.nickname) \(BuddyProfile.displayCode(offer.code))")
                            .font(ReelTheme.sans(14))
                            .foregroundColor(ReelTheme.ink)
                        Spacer()
                        Button(L10n.string("断る")) { Task { await watch.decline(offer) } }
                            .font(ReelTheme.sans(13))
                            .foregroundColor(ReelTheme.secondary)
                        Button {
                            Task { await watch.accept(offer, for: code) }
                        } label: {
                            Text(L10n.string("受け取る"))
                                .font(ReelTheme.sans(13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 32)
                                .background(Capsule().fill(ReelTheme.accentDeep))
                        }
                    }
                }
                Text(L10n.string("名前と番号を、本人に確かめてから受け取ってください。"))
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ReelTheme.accentSoft.opacity(0.6)))
        }
    }
}

// 見ている人1人のカード（保護者）：いま勉強中、今日、今週のグラフ、連続日数、スタンプ
struct WatchedCard: View {
    @ObservedObject private var watch = WatchCloud.shared
    let item: WatchCloud.Watched
    @State private var confirmRemove = false

    private var member: BuddyCloud.Member { item.member }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                BuddyAvatar(icon: member.icon, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.nickname)
                        .font(ReelTheme.serif(18))
                        .foregroundColor(ReelTheme.ink)
                    Text(member.isStudyingNow ? L10n.string("いま勉強中") : lastText)
                        .font(ReelTheme.sans(11, weight: member.isStudyingNow ? .semibold : .regular))
                        .foregroundColor(member.isStudyingNow ? ReelTheme.accentDeep : ReelTheme.secondary)
                }
                Spacer()
                Menu {
                    Button(L10n.string("見守りをやめる"), role: .destructive) { confirmRemove = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(ReelTheme.secondary)
                        .frame(width: 32, height: 32)
                }
            }
            HStack(spacing: 0) {
                figure(L10n.string("今日"), buddyDuration(member.today))
                figure(L10n.string("今週"), buddyDuration(member.week))
                figure(L10n.string("連続"), L10n.format("%d日", member.streakDays))
            }
            WatchWeekBars(seconds: member.weekKey == BuddyTotals.weekKey() ? member.weekDays : [])
            WatchInsights(item: item)
            HStack(spacing: 8) {
                ForEach(WatchCloud.stampKinds) { kind in
                    let enabled = watch.canSend(kind, to: item)
                    Button {
                        Task { await watch.send(kind, to: item) }
                    } label: {
                        Label(kind.title, systemImage: kind.systemImage)
                            .font(ReelTheme.sans(12))
                            .foregroundColor(enabled ? ReelTheme.accentDeep : ReelTheme.secondary.opacity(0.6))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(Capsule().fill(enabled ? ReelTheme.accentSoft : ReelTheme.line.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ReelTheme.accentSoft.opacity(0.35)))
        .alert(L10n.string("見守りをやめますか？"), isPresented: $confirmRemove) {
            Button(L10n.string("やめる"), role: .destructive) { Task { await watch.remove(item) } }
            Button(L10n.string("キャンセル"), role: .cancel) {}
        } message: {
            Text(L10n.format("%@さんの共有も終わります。", member.nickname))
        }
    }

    private var lastText: String {
        guard let last = member.lastStudiedAt else { return L10n.string("まだ記録がありません") }
        return L10n.format("最後に勉強した日：%@", last.formatted(.dateTime.month().day()))
    }

    private func figure(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
            Text(value)
                .font(ReelTheme.serif(16))
                .foregroundColor(ReelTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// 今週の曜日ごとの棒グラフ
struct WatchWeekBars: View {
    let seconds: [Int]

    private var labels: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    var body: some View {
        let values = (0..<7).map { $0 < seconds.count ? seconds[$0] : 0 }
        let top = max(values.max() ?? 0, 3600)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(values[index] > 0 ? ReelTheme.accentDeep : ReelTheme.line)
                        .frame(height: max(3, 54 * CGFloat(values[index]) / CGFloat(top)))
                    Text(labels[index])
                        .font(ReelTheme.sans(10))
                        .foregroundColor(ReelTheme.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 74, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("今週の合計 %@", buddyDuration(values.reduce(0, +))))
    }
}

// 先生が生徒にスタンプを送る
struct WatchStampSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var watch = WatchCloud.shared
    let item: WatchCloud.Watched

    private var current: WatchCloud.Watched { watch.watched.first { $0.id == item.id } ?? item }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                BuddyAvatar(icon: item.member.icon, size: 34)
                Text(L10n.format("%@ にスタンプ", item.member.nickname))
                    .font(ReelTheme.serif(18))
                    .foregroundColor(ReelTheme.ink)
            }
            HStack(spacing: 10) {
                ForEach(WatchCloud.stampKinds) { kind in
                    let enabled = watch.canSend(kind, to: current)
                    Button {
                        Task {
                            await watch.send(kind, to: current)
                            dismiss()
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: kind.systemImage)
                                .font(.system(size: 22))
                            Text(kind.title)
                                .font(ReelTheme.sans(11))
                        }
                        .foregroundColor(enabled ? ReelTheme.accentDeep : ReelTheme.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(enabled ? ReelTheme.accentSoft : ReelTheme.line.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
            Text(L10n.string("同じスタンプは1日1回まで送れます"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
        }
        .padding(20)
        .presentationDetents([.height(240)])
    }
}

// 見守りの QR コード（見る人が見せて、見せる人に読んでもらう）
struct WatchQRView: View {
    @Environment(\.dismiss) private var dismiss
    let code: WatchCloud.Code

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let url = WatchCloud.joinURL(for: code) {
                        if let image = BuddyInviteView.qrImage(url.absoluteString) {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                        }
                        Text(code.kind == .family
                             ? L10n.string("お子さんの iPhone のカメラで読んでもらってください。StudyReel が開き、お子さんが「見せる」を押すと申し出が届きます。")
                             : L10n.string("生徒の iPhone のカメラで読んでもらってください。StudyReel が開き、生徒が「見せる」を押すと申し出が届きます。"))
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.secondary)
                            .multilineTextAlignment(.center)
                        ShareLink(item: url, message: Text(L10n.string("StudyReel で勉強時間を見せてもらうためのリンクです"))) {
                            Label(L10n.string("リンクを送る"), systemImage: "square.and.arrow.up")
                                .font(ReelTheme.sans(15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .frame(minHeight: 46)
                                .background(Capsule().fill(ReelTheme.accentDeep))
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(GridPaperBackground().ignoresSafeArea())
            .navigationTitle(code.kind == .family ? L10n.string("お子さんに読んでもらう") : code.name)
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
}

// ホームの小さな行。見せている間は必ず出す（知らないうちに見られている、をなくす）。見守っている人には様子を出す
struct HomeWatchRow: View {
    @ObservedObject private var watch = WatchCloud.shared
    private let onOpen: () -> Void

    init(onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
    }

    var body: some View {
        VStack(spacing: 6) {
            if !watch.sharings.isEmpty {
                row(systemImage: "eye", text: sharingText, highlighted: false)
                    .accessibilityIdentifier("home.watch.sharing")
            }
            if !watch.watched.isEmpty {
                row(systemImage: "figure.2.and.child.holdinghands", text: watchingText, highlighted: studyingCount > 0)
            }
        }
    }

    private func row(systemImage: String, text: String, highlighted: Bool) -> some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundColor(ReelTheme.accentDeep)
                Text(text)
                    .font(ReelTheme.sans(12))
                    .foregroundColor(highlighted ? ReelTheme.accentDeep : ReelTheme.secondary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ReelTheme.secondary)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var sharingText: String {
        let family = watch.sharings.contains { $0.kind == .family }
        let school = watch.sharings.contains { $0.kind == .school }
        if family && school { return L10n.string("保護者・塾に勉強状況を共有中") }
        return family ? L10n.string("保護者に勉強状況を共有中") : L10n.string("塾に勉強状況を共有中")
    }

    private var studyingCount: Int { watch.watched.filter(\.member.isStudyingNow).count }

    private var watchingText: String {
        if watch.watched.count == 1, let only = watch.watched.first {
            return only.member.isStudyingNow
                ? L10n.format("%@さんが勉強中", only.member.nickname)
                : L10n.format("%@さん：今日 %@", only.member.nickname, buddyDuration(only.member.today))
        }
        return studyingCount > 0 ? L10n.format("見守り：いま%d人が勉強中", studyingCount) : L10n.format("見守り：%d人", watch.watched.count)
    }
}

// 4週間の推移と、今週の教科ごとの時間。保護者は Pro、先生（塾）はそのまま見られる
struct WatchInsights: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    let item: WatchCloud.Watched
    @State private var showPaywall = false

    private var member: BuddyCloud.Member { item.member }
    private var isCurrent: Bool { member.weekKey == BuddyTotals.weekKey() }

    var body: some View {
        if item.kind == .school || storeKit.isProUnlocked {
            VStack(alignment: .leading, spacing: 10) {
                weeks
                subjects
            }
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock")
                        .font(.system(size: 12))
                    Text(L10n.string("教科ごとの時間と4週間の推移は Pro で見られます"))
                        .font(ReelTheme.sans(12))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(ReelTheme.accentDeep)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ReelTheme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("watch.insights.locked")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // 4週間の推移（今週がまだ届いていないときは、前の週の値がずれて見えないように出さない）
    @ViewBuilder
    private var weeks: some View {
        let values = isCurrent && member.pastWeeks.count == 4 ? member.pastWeeks : []
        if !values.isEmpty {
            let top = max(values.max() ?? 0, 3600)
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("4週間の推移"))
                    .font(ReelTheme.sans(11, weight: .semibold))
                    .foregroundColor(ReelTheme.secondary)
                ForEach(0..<4, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text(index == 3 ? L10n.string("今週") : L10n.format("%d週前", 3 - index))
                            .font(ReelTheme.sans(11))
                            .foregroundColor(ReelTheme.secondary)
                            .frame(width: 44, alignment: .leading)
                        GeometryReader { proxy in
                            Capsule()
                                .fill(index == 3 ? ReelTheme.accentDeep : ReelTheme.accent.opacity(0.55))
                                .frame(width: max(4, proxy.size.width * CGFloat(values[index]) / CGFloat(top)))
                        }
                        .frame(height: 8)
                        Text(buddyDuration(values[index]))
                            .font(ReelTheme.sans(11))
                            .foregroundColor(ReelTheme.ink)
                            .monospacedDigit()
                            .frame(width: 76, alignment: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var subjects: some View {
        let rows = isCurrent ? member.subjects.sorted { $0.value > $1.value } : []
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("今週の教科ごとの時間"))
                .font(ReelTheme.sans(11, weight: .semibold))
                .foregroundColor(ReelTheme.secondary)
            if rows.isEmpty {
                Text(item.kind == .family
                     ? L10n.string("お子さんが「教科ごとの時間も見せる」をオンにすると出ます。")
                     : L10n.string("生徒が「教科ごとの時間も見せる」をオンにすると出ます。"))
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
            } else {
                ForEach(rows.prefix(6), id: \.key) { row in
                    HStack {
                        Text(row.key)
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.ink)
                            .lineLimit(1)
                        Spacer()
                        Text(buddyDuration(row.value))
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.ink)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}
