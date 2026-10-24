import CoreImage.CIFilterBuiltins
import SwiftUI

// 1つの勉強仲間の画面。いま勉強中の人、今日・今週のランキング、スタンプ、参加申請（オーナー）
struct BuddyGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloud = BuddyCloud.shared

    private let groupID: String
    @State private var period: Period = .today
    @State private var stampTarget: BuddyCloud.Member?
    @State private var showInvite = false
    @State private var confirmLeave = false
    @State private var removing: BuddyCloud.Member?
    @State private var reporting: BuddyReportTarget?
    @State private var showComposer = false
    @State private var viewing: BuddyCloud.Photo?

    init(groupID: String) {
        self.groupID = groupID
    }

    enum Period: String, CaseIterable, Identifiable {
        case today, week
        var id: String { rawValue }
        var title: String { self == .today ? L10n.string("今日") : L10n.string("今週") }
    }

    private var group: BuddyCloud.Group? { cloud.groups.first { $0.id == groupID } }

    var body: some View {
        ScrollView {
            if let group {
                VStack(alignment: .leading, spacing: 16) {
                    if group.isOwner, let requests = cloud.requests[group.id], !requests.isEmpty {
                        requestsCard(requests, group: group)
                    }
                    studyingCard(group)
                    if group.photosEnabled {
                        photosCard(group)
                    }
                    rankingCard(group)
                    footer(group)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(GridPaperBackground().ignoresSafeArea())
        .refreshable { await cloud.refresh() }
        .navigationTitle(group?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if group?.isOwner == true {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInvite = true
                    } label: {
                        Image(systemName: "qrcode")
                    }
                    .accessibilityLabel(L10n.string("招待する"))
                    .accessibilityIdentifier("buddies.invite")
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            if let group { BuddyInviteView(group: group) }
        }
        .sheet(item: $stampTarget) { member in
            if let group { BuddyStampPicker(member: member, group: group) }
        }
        .sheet(item: $reporting) { target in
            BuddyReportSheet(target: target)
        }
        .sheet(isPresented: $showComposer) {
            if let group { BuddyPhotoComposer(group: group) }
        }
        .sheet(item: $viewing) { photo in
            if let group {
                BuddyPhotoViewer(photo: photo, group: group) { data in
                    viewing = nil
                    reporting = BuddyReportTarget(group: group, userRecordName: photo.from, nickname: photo.nickname, code: photo.code, photo: photo, photoData: data)
                }
            }
        }
        .task(id: group?.photosEnabled) {
            if group?.photosEnabled == true { await BuddyPhotos.checkAgeIfNeeded() }
        }
        .alert(group?.isOwner == true ? L10n.string("グループを削除しますか？") : L10n.string("グループを抜けますか？"), isPresented: $confirmLeave) {
            Button(group?.isOwner == true ? L10n.string("削除") : L10n.string("抜ける"), role: .destructive) { leave() }
            Button(L10n.string("キャンセル"), role: .cancel) {}
        } message: {
            Text(group?.isOwner == true ? L10n.string("仲間全員のグループがなくなります。元に戻せません。") : L10n.string("また入るときは、オーナーに申請し直す必要があります。"))
        }
        .alert(L10n.string("この人を外しますか？"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button(L10n.string("外す"), role: .destructive) {
                if let removing, let group { Task { await cloud.remove(removing, from: group) } }
                removing = nil
            }
            Button(L10n.string("キャンセル"), role: .cancel) { removing = nil }
        } message: {
            Text(L10n.string("外した人は、グループの中が見えなくなります。"))
        }
        .onChange(of: group == nil) { _, gone in
            if gone { dismiss() }
        }
    }

    // MARK: - 参加申請（オーナー）

    private func requestsCard(_ requests: [BuddyCloud.JoinRequest], group: BuddyCloud.Group) -> some View {
        TapedPaper(tape: GoalTheme.tapePink) {
            VStack(alignment: .leading, spacing: 10) {
                GoalScript(text: "requests ✦", size: 14)
                Text(L10n.string("番号を確かめてから許可してください"))
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
                ForEach(requests) { request in
                    HStack(spacing: 10) {
                        BuddyAvatar(icon: request.icon, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.nickname)
                                .font(ReelTheme.sans(14, weight: .medium))
                                .foregroundColor(ReelTheme.ink)
                            Text(BuddyProfile.displayCode(request.code))
                                .font(ReelTheme.sans(12))
                                .foregroundColor(ReelTheme.secondary)
                        }
                        Spacer()
                        Button(L10n.string("断る")) {
                            Task { await cloud.deny(request, in: group) }
                        }
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                        Button {
                            Task { await cloud.approve(request, in: group) }
                        } label: {
                            Text(L10n.string("許可"))
                                .font(ReelTheme.sans(13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 34)
                                .background(Capsule().fill(ReelTheme.accentDeep))
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - いま勉強中

    private func visibleMembers(_ group: BuddyCloud.Group) -> [BuddyCloud.Member] {
        let blocked = cloud.blocked
        return group.members.filter { !blocked.contains($0.userRecordName) }
    }

    private func studyingCard(_ group: BuddyCloud.Group) -> some View {
        let studying = visibleMembers(group).filter(\.isStudyingNow)
        return TapedPaper {
            VStack(alignment: .leading, spacing: 10) {
                GoalScript(text: "studying now ✦", size: 14)
                if studying.isEmpty {
                    Text(L10n.string("いま勉強中の仲間はいません"))
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                } else {
                    ForEach(studying) { member in
                        memberRow(member, group: group, detail: elapsedText(member))
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func elapsedText(_ member: BuddyCloud.Member) -> String {
        guard let since = member.studyingSince else { return "" }
        return L10n.format("%@経過", buddyDuration(Int(Date().timeIntervalSince(since))))
    }

    // MARK: - 写真

    private func visiblePhotos(_ group: BuddyCloud.Group) -> [BuddyCloud.Photo] {
        let blocked = cloud.blocked
        return group.photos.filter { !$0.isExpired && !blocked.contains($0.from) && !cloud.bannedSenders.contains($0.from) }
    }

    private func photosCard(_ group: BuddyCloud.Group) -> some View {
        let photos = visiblePhotos(group)
        let canSend = BuddyProfile.photosOn && !cloud.isBannedFromPhotos && !cloud.hasSentPhotoToday(in: group)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                GoalScript(text: "today's moment ✦", size: 14)
                Spacer()
                if canSend {
                    Button {
                        showComposer = true
                    } label: {
                        Label(L10n.string("1コマ出す"), systemImage: "plus")
                            .font(ReelTheme.sans(12, weight: .semibold))
                    }
                    .accessibilityIdentifier("buddies.photo.add")
                }
            }
            if !BuddyProfile.photosOn {
                Text(L10n.string("写真を見せ合わない設定になっています。右上の「自分の表示」から変えられます。"))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
            } else if photos.isEmpty {
                Text(L10n.string("今日の1コマはまだありません。保存したタイムラプスから、出してもいい瞬間を選べます。24時間で消えます。"))
                    .font(ReelTheme.sans(12))
                    .foregroundColor(ReelTheme.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            Button {
                                viewing = photo
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    BuddyPhotoImage(photo: photo, group: group)
                                        .frame(width: 140, height: 105)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    Text(photo.nickname)
                                        .font(ReelTheme.sans(11))
                                        .foregroundColor(ReelTheme.ink)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
    }

    // MARK: - ランキング

    private func rankingCard(_ group: BuddyCloud.Group) -> some View {
        let members = visibleMembers(group).filter { !$0.hidesRanking || $0.userRecordName == cloud.myRecordName }
        let ranked = members.sorted { seconds($0) > seconds($1) }
        return VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $period) {
                ForEach(Period.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            VStack(spacing: 0) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(ReelTheme.serif(16))
                            .foregroundColor(index < 3 ? ReelTheme.accentDeep : ReelTheme.secondary)
                            .frame(width: 22)
                        memberRow(member, group: group, detail: buddyDuration(seconds(member)))
                    }
                    .padding(.vertical, 6)
                    if index < ranked.count - 1 { Divider() }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            Text(L10n.string("仲間の行を押すとスタンプを送れます。長押しでブロック・通報できます。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
        }
    }

    private func seconds(_ member: BuddyCloud.Member) -> Int {
        period == .today ? member.today : member.week
    }

    // MARK: - 1人の行

    private func memberRow(_ member: BuddyCloud.Member, group: BuddyCloud.Group, detail: String) -> some View {
        let isMe = member.userRecordName == cloud.myRecordName
        let received = group.stamps.filter { $0.to == member.userRecordName && !cloud.blocked.contains($0.from) }
        return Button {
            if !isMe { stampTarget = member }
        } label: {
            HStack(spacing: 10) {
                BuddyAvatar(icon: member.icon, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(member.nickname)
                            .font(ReelTheme.sans(14, weight: .medium))
                            .foregroundColor(ReelTheme.ink)
                            .lineLimit(1)
                        if isMe {
                            Text(L10n.string("自分"))
                                .font(ReelTheme.sans(10))
                                .foregroundColor(ReelTheme.secondary)
                        }
                    }
                    if !received.isEmpty {
                        HStack(spacing: 3) {
                            ForEach(Array(Set(received.map(\.kind))).sorted { $0.rawValue < $1.rawValue }) { kind in
                                Image(systemName: kind.systemImage)
                                    .font(.system(size: 10))
                                    .foregroundColor(ReelTheme.accentDeep)
                            }
                            Text("\(received.count)")
                                .font(ReelTheme.sans(10))
                                .foregroundColor(ReelTheme.secondary)
                        }
                    } else if member.streakDays > 1 {
                        Text(L10n.format("%d日連続", member.streakDays))
                            .font(ReelTheme.sans(10))
                            .foregroundColor(ReelTheme.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(detail)
                    .font(ReelTheme.serif(15))
                    .foregroundColor(ReelTheme.ink)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isMe {
                Button(role: .destructive) {
                    cloud.block(member)
                } label: {
                    Label(L10n.string("ブロック"), systemImage: "hand.raised")
                }
                Button {
                    reporting = BuddyReportTarget(group: group, userRecordName: member.userRecordName, nickname: member.nickname, code: member.code, photo: nil, photoData: nil)
                } label: {
                    Label(L10n.string("通報"), systemImage: "exclamationmark.bubble")
                }
                if group.isOwner {
                    Button(role: .destructive) {
                        removing = member
                    } label: {
                        Label(L10n.string("グループから外す"), systemImage: "person.badge.minus")
                    }
                }
            }
        }
    }

    // MARK: - 下

    private func footer(_ group: BuddyCloud.Group) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if group.isOwner {
                Toggle(isOn: Binding(get: { group.photosEnabled }, set: { value in Task { await cloud.setPhotosEnabled(value, in: group) } })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("このグループで写真を使う"))
                            .font(ReelTheme.sans(14))
                            .foregroundColor(ReelTheme.ink)
                        Text(L10n.string("仲間が自分のタイムラプスから選んだ1コマ（顔にモザイク）を見せ合えます。24時間で消えます。知り合いだけのグループでオンにしてください。"))
                            .font(ReelTheme.sans(11))
                            .foregroundColor(ReelTheme.secondary)
                    }
                }
                .tint(ReelTheme.accentDeep)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
            }
            Text(L10n.string("ブロックすると、その人の名前・勉強状況・スタンプがあなたの画面に出なくなります。相手からあなたの勉強状況は見えたままなので、見せたくないときはグループを抜けるか、オーナーに外してもらってください。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
            Button(group.isOwner ? L10n.string("グループを削除") : L10n.string("グループを抜ける"), role: .destructive) {
                confirmLeave = true
            }
            .font(ReelTheme.sans(14))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .padding(.top, 8)
    }

    private func leave() {
        guard let group else { return }
        Task {
            if group.isOwner {
                await cloud.deleteGroup(group)
            } else {
                await cloud.leave(group)
            }
            dismiss()
        }
    }
}

enum BuddyReport {
    // 問い合わせ先（通報はアプリの中から送る）
    static let address = "contact@enludus.com"
}

// スタンプを選ぶ
struct BuddyStampPicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloud = BuddyCloud.shared
    private let member: BuddyCloud.Member
    private let group: BuddyCloud.Group

    init(member: BuddyCloud.Member, group: BuddyCloud.Group) {
        self.member = member
        self.group = group
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                BuddyAvatar(icon: member.icon, size: 34)
                Text(L10n.format("%@ にスタンプ", member.nickname))
                    .font(ReelTheme.serif(18))
                    .foregroundColor(ReelTheme.ink)
                Spacer()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(BuddyStampKind.allCases) { kind in
                    let enabled = cloud.canSend(kind, to: member, in: current)
                    Button {
                        Task {
                            await cloud.send(kind, to: member, in: current)
                            dismiss()
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: kind.systemImage)
                                .font(.system(size: 22))
                            Text(kind.title)
                                .font(ReelTheme.sans(11))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(enabled ? ReelTheme.accentDeep : ReelTheme.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(enabled ? ReelTheme.accentSoft : ReelTheme.line.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
            Text(L10n.string("同じ人に同じスタンプは1日1回まで送れます"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
        }
        .padding(20)
        .presentationDetents([.height(300)])
    }

    private var current: BuddyCloud.Group { cloud.groups.first { $0.id == group.id } ?? group }
}

// 招待の QR コードとリンク（オーナー）
struct BuddyInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloud = BuddyCloud.shared
    private let group: BuddyCloud.Group
    @State private var confirmReissue = false

    init(group: BuddyCloud.Group) {
        self.group = group
    }

    private var current: BuddyCloud.Group { cloud.groups.first { $0.id == group.id } ?? group }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let url = BuddyCloud.inviteURL(for: current) {
                        if let image = Self.qrImage(url.absoluteString) {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                        }
                        Text(L10n.string("iPhone のカメラで読むと StudyReel が開いて、参加の申請ができます。申請はあなたが許可するまで入れません。"))
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.secondary)
                            .multilineTextAlignment(.center)
                        ShareLink(item: url, message: Text(L10n.format("StudyReel の勉強仲間「%@」の招待です", current.name))) {
                            Label(L10n.string("リンクを送る"), systemImage: "square.and.arrow.up")
                                .font(ReelTheme.sans(15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .frame(minHeight: 46)
                                .background(Capsule().fill(ReelTheme.accentDeep))
                        }
                    }
                    Button(L10n.string("招待を作り直す")) { confirmReissue = true }
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                    Text(L10n.format("1つのグループに入れるのは%d人までです（いま %d人）", BuddyCloud.maxMembers, current.participantCount))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(GridPaperBackground().ignoresSafeArea())
            .navigationTitle(L10n.string("招待する"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
            }
            .alert(L10n.string("招待を作り直しますか？"), isPresented: $confirmReissue) {
                Button(L10n.string("作り直す"), role: .destructive) {
                    Task { await cloud.reissueInvite(current) }
                }
                Button(L10n.string("キャンセル"), role: .cancel) {}
            } message: {
                Text(L10n.string("今の QR コードとリンクからは、申請できなくなります。"))
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    static func qrImage(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
