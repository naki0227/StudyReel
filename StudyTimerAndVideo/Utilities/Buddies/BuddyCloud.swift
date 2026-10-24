import CloudKit
import Foundation

// 勉強仲間（グループ）を CloudKit でやり取りする。自前のサーバーは持たない
//
// しくみ（docs/group-spec.md）
// - グループごとに、オーナーの iCloud（private database）に共有ゾーンを1つ作り、ゾーンごと共有する（CKShare）
//   ゾーンの中には「group」（名前・招待トークン）、メンバーごとの「member-<利用者番号>」、スタンプを置く
// - 参加は承認制。招待リンク（studyreel://buddies/join?t=トークン）を開いた人は、公開データベースに参加申請を書く
//   オーナーが許可すると、その人を共有の参加者に足して、公開データベースに「許可」と共有の URL を書く
//   申請した人のアプリは許可を見つけたら、その URL から共有を受け入れて参加する
//   （CloudKit の「アクセス申請」は iOS 26 からなので使わない）
// - 公開データベースの BuddyJoinRequest.token はクエリできるように、CloudKit のコンソールで Queryable にしておく
//   （docs/buddies-setup.md）
@MainActor
final class BuddyCloud: ObservableObject {
    static let shared = BuddyCloud()

    static let containerIdentifier = "iCloud.com.ni.StudyTimerAndVideo"
    static let maxMembers = 20
    // 作れる（オーナーになれる）グループは無料1つ・Pro 5つ。参加できるグループはプランにかかわらず10まで
    static let freeOwnedLimit = 1
    static let proOwnedLimit = 5
    static let joinLimit = 10
    static let dailyStampLimit = 30

    enum Availability: Equatable {
        case unknown, available, noAccount, restricted, failed(String)
    }

    struct Group: Identifiable, Equatable {
        let zoneID: CKRecordZone.ID
        var name: String
        var inviteToken: String
        var isOwner: Bool
        var members: [Member]
        var stamps: [Stamp]
        var photos: [Photo]
        var photosEnabled: Bool
        var participantCount: Int
        var id: String { zoneID.ownerName + "/" + zoneID.zoneName }
    }

    struct Member: Identifiable, Equatable {
        let userRecordName: String
        var nickname: String
        var icon: BuddyIcon
        var code: Int
        var studyingSince: Date?
        var studyingUntil: Date?
        var todaySeconds: Int
        var todayKey: String
        var weekSeconds: Int
        var weekKey: String
        var streakDays: Int
        var hidesRanking: Bool
        // 見守り（保護者・塾）のゾーンにだけ書く：今週の曜日ごとの秒数と、最後に勉強した日時
        var weekDays: [Int] = []
        var lastStudiedAt: Date?
        // 4週間の週ごとの秒数（古い順）と、今週の教科ごとの秒数（本人が見せると決めたときだけ）
        var pastWeeks: [Int] = []
        var subjects: [String: Int] = [:]
        var id: String { userRecordName }

        var isStudyingNow: Bool {
            guard let since = studyingSince, let until = studyingUntil else { return false }
            let now = Date()
            return since <= now && now < until
        }

        // 相手の端末の日付で「今日」の合計が書かれているので、こちらの今日と同じ日のときだけ使う
        var today: Int { todayKey == BuddyTotals.dayKey() ? todaySeconds : 0 }
        var week: Int { weekKey == BuddyTotals.weekKey() ? weekSeconds : 0 }
    }

    struct Stamp: Identifiable, Equatable {
        let recordName: String
        var from: String
        var to: String
        var kind: BuddyStampKind
        var dayKey: String
        var id: String { recordName }
    }

    // 仲間に見せる1コマ。画像は見るときに取ってくる（BuddyPhotos）
    struct Photo: Identifiable, Equatable {
        let recordName: String
        var from: String
        var nickname: String
        var code: Int
        var createdAt: Date
        var expiresAt: Date
        var id: String { recordName }
        var isExpired: Bool { expiresAt <= Date() }
    }

    struct JoinRequest: Identifiable, Equatable {
        let recordName: String
        var token: String
        var requester: String
        var nickname: String
        var icon: BuddyIcon
        var code: Int
        var id: String { recordName }
    }

    // 自分が出して、まだ許可を待っている申請
    struct PendingJoin: Codable, Identifiable, Equatable {
        var requestName: String
        var groupName: String
        var id: String { requestName }
    }

    @Published private(set) var availability: Availability = .unknown
    @Published private(set) var groups: [Group] = []
    @Published private(set) var requests: [String: [JoinRequest]] = [:]   // グループの id → 申請
    @Published private(set) var pendingJoins: [PendingJoin] = []
    @Published private(set) var isLoading = false
    @Published var message: String?
    @Published private(set) var myRecordName: String?
    @Published private(set) var examCounts: [BuddyExam: Int] = [:]
    @Published private(set) var isBannedFromPhotos = false
    @Published private(set) var bannedSenders: Set<String> = []

    // 必要になるまで作らない。署名なしのシミュレーター（UI テスト）では iCloud の権限がなく、作るだけで落ちるため
    private(set) lazy var container = CKContainer(identifier: BuddyCloud.containerIdentifier)
    var privateDB: CKDatabase { container.privateCloudDatabase }
    var sharedDB: CKDatabase { container.sharedCloudDatabase }
    var publicDB: CKDatabase { container.publicCloudDatabase }

    private static let zonePrefix = "buddies-"
    private static let groupRecordName = "group"
    private static let pendingKey = "buddy_pending_joins"
    private static let blockedKey = "buddy_blocked"
    private static let handledKey = "buddy_handled_requests"
    private static let sentStampsKey = "buddy_sent_stamps"
    private static let subscribedKey = "buddy_subscribed"

    // 勉強中の表示（録画を始めたら書き、止めたら消す）
    private var studyingSince: Date?
    private var studyingUntil: Date?
    private var totals = BuddyTotals()
    private var hasLoaded = false

    private init() {
        pendingJoins = (try? JSONDecoder().decode([PendingJoin].self, from: UserDefaults.standard.data(forKey: Self.pendingKey) ?? Data())) ?? []
    }

    var isActive: Bool { !DemoMode.isActive }

    // MARK: - 読み込み

    func refresh() async {
        guard isActive else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available: availability = .available
            case .noAccount: availability = .noAccount; return
            case .restricted: availability = .restricted; return
            default: availability = .failed(L10n.string("iCloud の状態を確かめられませんでした")); return
            }
            if myRecordName == nil {
                myRecordName = try await container.userRecordID().recordName
            }
            await checkPendingJoins()
            var loaded: [Group] = []
            for zone in try await privateDB.allRecordZones() where zone.zoneID.zoneName.hasPrefix(Self.zonePrefix) {
                if let group = try? await loadGroup(zone.zoneID, in: privateDB, isOwner: true) { loaded.append(group) }
            }
            for zone in try await sharedDB.allRecordZones() where zone.zoneID.zoneName.hasPrefix(Self.zonePrefix) {
                if let group = try? await loadGroup(zone.zoneID, in: sharedDB, isOwner: false) { loaded.append(group) }
            }
            groups = loaded.sorted { $0.name < $1.name }
            hasLoaded = true
            await removeExpiredPhotos()
            await checkPhotoBans()
            BuddyNotifier.process(groups: groups, me: myRecordName, blocked: blocked, post: notifiesOnNextRefresh)
            notifiesOnNextRefresh = false
            if !groups.isEmpty { await subscribeIfNeeded() }
            var found: [String: [JoinRequest]] = [:]
            for group in groups where group.isOwner {
                found[group.id] = (try? await fetchRequests(token: group.inviteToken)) ?? []
            }
            requests = found
        } catch {
            message = Self.describe(error)
        }
    }

    // 写真の画像（image）だけは取らない。見るときに1枚ずつ取る
    static let listKeys: [CKRecord.FieldKey] = [
        "name", "inviteToken", "ownerRecordName", "photosEnabled",
        "userRecordName", "nickname", "icon", "code", "studyingSince", "studyingUntil",
        "todaySeconds", "todayKey", "weekSeconds", "weekKey", "streakDays", "hidesRanking",
        "from", "to", "kind", "dayKey", "createdAt", "expiresAt",
        "weekDays", "lastStudiedAt", "pastWeeks", "subjectsWeek", "token", "viewer", "viewerName", "schoolName",
        CKShare.SystemFieldKey.title,
    ]

    private func loadGroup(_ zoneID: CKRecordZone.ID, in db: CKDatabase, isOwner: Bool) async throws -> Group {
        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        var more = true
        while more {
            let changes = try await db.recordZoneChanges(inZoneWith: zoneID, since: token, desiredKeys: Self.listKeys)
            for (_, result) in changes.modificationResultsByID {
                if case .success(let modification) = result { records.append(modification.record) }
            }
            token = changes.changeToken
            more = changes.moreComing
        }
        var groupRecord = records.first { $0.recordID.recordName == Self.groupRecordName }
        if groupRecord == nil {
            // 変更の一覧に出てこなかったときは、直接取りにいく
            groupRecord = try? await db.record(for: CKRecord.ID(recordName: Self.groupRecordName, zoneID: zoneID))
        }
        let share = records.compactMap { $0 as? CKShare }.first
        let members = records.filter { $0.recordType == "BuddyMember" }.map(Self.member)
        let today = BuddyTotals.dayKey()
        let stamps = records.filter { $0.recordType == "BuddyStamp" }.compactMap(Self.stamp).filter { $0.dayKey == today }
        let photos = records.filter { $0.recordType == "BuddyPhoto" }.map(Self.photo).sorted { $0.createdAt > $1.createdAt }
        return Group(
            zoneID: zoneID,
            name: groupRecord?["name"] as? String ?? (share?[CKShare.SystemFieldKey.title] as? String ?? L10n.string("名前のないグループ")),
            inviteToken: groupRecord?["inviteToken"] as? String ?? "",
            isOwner: isOwner,
            members: members,
            stamps: stamps,
            photos: photos,
            photosEnabled: (groupRecord?["photosEnabled"] as? Int ?? 0) == 1,
            participantCount: share?.participants.count ?? members.count
        )
    }

    static func member(_ record: CKRecord) -> Member {
        Member(
            userRecordName: record["userRecordName"] as? String ?? record.recordID.recordName,
            nickname: record["nickname"] as? String ?? "",
            icon: BuddyIcon(rawValue: record["icon"] as? String ?? "") ?? .pencil,
            code: record["code"] as? Int ?? 0,
            studyingSince: record["studyingSince"] as? Date,
            studyingUntil: record["studyingUntil"] as? Date,
            todaySeconds: record["todaySeconds"] as? Int ?? 0,
            todayKey: record["todayKey"] as? String ?? "",
            weekSeconds: record["weekSeconds"] as? Int ?? 0,
            weekKey: record["weekKey"] as? String ?? "",
            streakDays: record["streakDays"] as? Int ?? 0,
            hidesRanking: (record["hidesRanking"] as? Int ?? 0) == 1,
            weekDays: record["weekDays"] as? [Int] ?? [],
            lastStudiedAt: record["lastStudiedAt"] as? Date,
            pastWeeks: record["pastWeeks"] as? [Int] ?? [],
            subjects: (record["subjectsWeek"] as? String).flatMap { try? JSONDecoder().decode([String: Int].self, from: Data($0.utf8)) } ?? [:]
        )
    }

    static func stamp(_ record: CKRecord) -> Stamp? {
        guard let kind = BuddyStampKind(rawValue: record["kind"] as? String ?? "") else { return nil }
        return Stamp(
            recordName: record.recordID.recordName,
            from: record["from"] as? String ?? "",
            to: record["to"] as? String ?? "",
            kind: kind,
            dayKey: record["dayKey"] as? String ?? ""
        )
    }

    private static func photo(_ record: CKRecord) -> Photo {
        let created = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        return Photo(
            recordName: record.recordID.recordName,
            from: record["from"] as? String ?? "",
            nickname: record["nickname"] as? String ?? "",
            code: record["code"] as? Int ?? 0,
            createdAt: created,
            expiresAt: record["expiresAt"] as? Date ?? created.addingTimeInterval(BuddyPhotos.lifetime)
        )
    }

    func database(for group: Group) -> CKDatabase { group.isOwner ? privateDB : sharedDB }

    // MARK: - グループを作る・消す・抜ける

    func createGroup(name: String) async -> Group? {
        guard isActive, let me = myRecordName else { return nil }
        let zone = CKRecordZone(zoneName: Self.zonePrefix + UUID().uuidString)
        do {
            _ = try await privateDB.save(zone)
            let groupRecord = CKRecord(recordType: "BuddyGroup", recordID: CKRecord.ID(recordName: Self.groupRecordName, zoneID: zone.zoneID))
            groupRecord["name"] = name as NSString
            groupRecord["inviteToken"] = Self.newToken() as NSString
            groupRecord["ownerRecordName"] = me as NSString
            let share = CKShare(recordZoneID: zone.zoneID)
            share[CKShare.SystemFieldKey.title] = name as NSString
            // 参加者はオーナーが一人ずつ足す（リンクを知っているだけでは入れない）
            share.publicPermission = .none
            // グループの行と共有は別々に保存する（まとめると片方の失敗で両方入らず、気づけない）
            try await save([groupRecord], in: privateDB)
            try await save([share], in: privateDB)
            try await saveMyMember(in: zone.zoneID, db: privateDB)
            await refresh()
            return groups.first { $0.zoneID == zone.zoneID }
        } catch {
            // 途中で失敗したら、名前のないグループが残らないようにゾーンごと消す
            _ = try? await privateDB.deleteRecordZone(withID: zone.zoneID)
            message = Self.describe(error)
            return nil
        }
    }

    func deleteGroup(_ group: Group) async {
        guard group.isOwner else { return }
        do {
            _ = try await privateDB.deleteRecordZone(withID: group.zoneID)
            groups.removeAll { $0.id == group.id }
        } catch {
            message = Self.describe(error)
        }
    }

    func leave(_ group: Group) async {
        guard !group.isOwner else { return }
        do {
            if let me = myRecordName {
                _ = try? await sharedDB.modifyRecords(saving: [], deleting: [Self.memberID(me, zone: group.zoneID)])
            }
            // 共有データベースのゾーンを消すと、その共有から抜ける
            _ = try await sharedDB.deleteRecordZone(withID: group.zoneID)
            groups.removeAll { $0.id == group.id }
        } catch {
            message = Self.describe(error)
        }
    }

    // 招待リンク（QR）を作り直す。古いリンクからの申請は受け付けなくなる
    func reissueInvite(_ group: Group) async {
        guard group.isOwner else { return }
        do {
            let record = try await privateDB.record(for: CKRecord.ID(recordName: Self.groupRecordName, zoneID: group.zoneID))
            record["inviteToken"] = Self.newToken() as NSString
            try await save([record], in: privateDB, policy: .changedKeys)
            await refresh()
        } catch {
            message = Self.describe(error)
        }
    }

    static func inviteURL(for group: Group) -> URL? {
        var components = URLComponents()
        components.scheme = "studyreel"
        components.host = "buddies"
        components.path = "/join"
        components.queryItems = [URLQueryItem(name: "t", value: group.inviteToken), URLQueryItem(name: "n", value: group.name)]
        return components.url
    }

    // MARK: - 参加申請

    // 招待リンクを開いた人が申請を出す
    func requestJoin(token: String, groupName: String) async -> Bool {
        guard isActive else { return false }
        if myRecordName == nil { await refresh() }
        guard let me = myRecordName, BuddyProfile.isReady else { return false }
        let recordName = "req-\(token)-\(me)"
        let record = CKRecord(recordType: "BuddyJoinRequest", recordID: CKRecord.ID(recordName: recordName))
        record["token"] = token as NSString
        record["requester"] = me as NSString
        record["nickname"] = BuddyProfile.nickname as NSString
        record["icon"] = BuddyProfile.icon.rawValue as NSString
        record["code"] = NSNumber(value: BuddyProfile.code)
        do {
            try await save([record], in: publicDB, policy: .allKeys)
            if !pendingJoins.contains(where: { $0.requestName == recordName }) {
                pendingJoins.append(PendingJoin(requestName: recordName, groupName: groupName))
                savePending()
            }
            return true
        } catch {
            message = Self.describe(error)
            return false
        }
    }

    private func fetchRequests(token: String) async throws -> [JoinRequest] {
        guard !token.isEmpty else { return [] }
        let query = CKQuery(recordType: "BuddyJoinRequest", predicate: NSPredicate(format: "token == %@", token))
        let result = try await publicDB.records(matching: query, resultsLimit: 50)
        let handled = Set(UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? [])
        return result.matchResults.compactMap { _, item in
            guard case .success(let record) = item, !handled.contains(record.recordID.recordName) else { return nil }
            return JoinRequest(
                recordName: record.recordID.recordName,
                token: record["token"] as? String ?? "",
                requester: record["requester"] as? String ?? "",
                nickname: record["nickname"] as? String ?? "",
                icon: BuddyIcon(rawValue: record["icon"] as? String ?? "") ?? .pencil,
                code: record["code"] as? Int ?? 0
            )
        }
    }

    // オーナーが申請を許可する
    func approve(_ request: JoinRequest, in group: Group) async {
        guard group.isOwner else { return }
        guard group.participantCount < Self.maxMembers else {
            message = L10n.format("1つのグループに入れるのは%d人までです", Self.maxMembers)
            return
        }
        do {
            let participant = try await fetchParticipant(userRecordName: request.requester)
            participant.permission = .readWrite
            let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: group.zoneID)
            guard let share = try await privateDB.record(for: shareID) as? CKShare else { return }
            share.addParticipant(participant)
            try await save([share], in: privateDB)
            guard let url = share.url else { return }
            let approval = CKRecord(recordType: "BuddyJoinApproval", recordID: CKRecord.ID(recordName: "ok-" + request.recordName))
            approval["shareURL"] = url.absoluteString as NSString
            try await save([approval], in: publicDB, policy: .allKeys)
            markHandled(request)
            await refresh()
        } catch {
            message = Self.describe(error)
        }
    }

    func deny(_ request: JoinRequest, in group: Group) async {
        let denial = CKRecord(recordType: "BuddyJoinDenial", recordID: CKRecord.ID(recordName: "no-" + request.recordName))
        denial["token"] = request.token as NSString
        _ = try? await publicDB.modifyRecords(saving: [denial], deleting: [], savePolicy: .allKeys)
        markHandled(request)
        requests[group.id]?.removeAll { $0.id == request.id }
    }

    // 申請した人：許可されていたら参加する
    private func checkPendingJoins() async {
        for pending in pendingJoins {
            if let approval = try? await publicDB.record(for: CKRecord.ID(recordName: "ok-" + pending.requestName)),
               let text = approval["shareURL"] as? String, let url = URL(string: text) {
                do {
                    let metadata = try await fetchShareMetadata(url)
                    try await accept(metadata)
                    _ = try? await publicDB.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: pending.requestName)])
                    removePending(pending)
                    try? await saveMyMember(in: metadata.share.recordID.zoneID, db: sharedDB)
                    message = L10n.format("「%@」に参加しました", pending.groupName)
                } catch {
                    message = Self.describe(error)
                }
            } else if (try? await publicDB.record(for: CKRecord.ID(recordName: "no-" + pending.requestName))) != nil {
                _ = try? await publicDB.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: pending.requestName)])
                removePending(pending)
                message = L10n.format("「%@」への参加は見送られました", pending.groupName)
            }
        }
    }

    func cancelPending(_ pending: PendingJoin) async {
        _ = try? await publicDB.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: pending.requestName)])
        removePending(pending)
    }

    // オーナーがメンバーを外す
    func remove(_ member: Member, from group: Group) async {
        guard group.isOwner, member.userRecordName != myRecordName else { return }
        do {
            let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: group.zoneID)
            guard let share = try await privateDB.record(for: shareID) as? CKShare else { return }
            for participant in share.participants where participant.userIdentity.userRecordID?.recordName == member.userRecordName {
                share.removeParticipant(participant)
            }
            try await save([share], deleting: [Self.memberID(member.userRecordName, zone: group.zoneID)], in: privateDB)
            await refresh()
        } catch {
            message = Self.describe(error)
        }
    }

    // MARK: - 自分の状況

    func studyStarted(at start: Date, plannedSeconds: Int?) {
        studyingSince = start
        // タイマーは終わる時刻＋10分、ストップウォッチは最大4時間まで「勉強中」
        studyingUntil = start.addingTimeInterval(TimeInterval((plannedSeconds ?? 4 * 3600) + (plannedSeconds == nil ? 0 : 600)))
        pushMyStatus()
        updatePresence()
    }

    func studyEnded() {
        studyingSince = nil
        studyingUntil = nil
        pushMyStatus()
        updatePresence()
    }

    func updateTotals(_ sessions: [StudySession]) {
        let made = BuddyTotals.make(from: sessions)
        guard made != totals else { return }
        totals = made
        pushMyStatus()
    }

    func profileChanged() { pushMyStatus() }

    private func pushMyStatus() {
        guard isActive, BuddyProfile.isReady else { return }
        Task {
            if !hasLoaded { await refresh() }
            for group in groups {
                try? await saveMyMember(in: group.zoneID, db: database(for: group))
            }
            await WatchCloud.shared.pushStatus()
        }
    }

    private func saveMyMember(in zoneID: CKRecordZone.ID, db: CKDatabase) async throws {
        guard let record = myMemberRecord(in: zoneID, detailed: false) else { return }
        // 自分の行は自分だけが書くので、そのまま上書きする
        try await save([record], in: db, policy: .allKeys)
    }

    // 自分の行。detailed のとき（見守りのゾーン）は、曜日ごとの時間と最後に勉強した日時も書く
    func myMemberRecord(in zoneID: CKRecordZone.ID, detailed: Bool) -> CKRecord? {
        guard let me = myRecordName, BuddyProfile.isReady else { return nil }
        let record = CKRecord(recordType: "BuddyMember", recordID: Self.memberID(me, zone: zoneID))
        record["userRecordName"] = me as NSString
        record["nickname"] = BuddyProfile.nickname as NSString
        record["icon"] = BuddyProfile.icon.rawValue as NSString
        record["code"] = NSNumber(value: BuddyProfile.code)
        if let studyingSince, let studyingUntil {
            record["studyingSince"] = studyingSince as NSDate
            record["studyingUntil"] = studyingUntil as NSDate
        } else {
            record["studyingSince"] = nil
            record["studyingUntil"] = nil
        }
        record["todaySeconds"] = NSNumber(value: totals.todaySeconds)
        record["todayKey"] = BuddyTotals.dayKey() as NSString
        record["weekSeconds"] = NSNumber(value: totals.weekSeconds)
        record["weekKey"] = BuddyTotals.weekKey() as NSString
        record["streakDays"] = NSNumber(value: totals.streakDays)
        record["hidesRanking"] = NSNumber(value: BuddyProfile.hidesRanking ? 1 : 0)
        if detailed {
            record["weekDays"] = totals.weekDays as NSArray
            if let last = totals.lastStudiedAt {
                record["lastStudiedAt"] = last as NSDate
            }
            record["pastWeeks"] = totals.pastWeeks as NSArray
            // 教科の名前は本人が付けたものなので、見せると決めたときだけ書く
            if BuddyProfile.watchShowsSubjects,
               let json = try? JSONEncoder().encode(totals.subjects), let text = String(data: json, encoding: .utf8) {
                record["subjectsWeek"] = text as NSString
            } else {
                record["subjectsWeek"] = nil
            }
        }
        return record
    }

    // MARK: - スタンプ

    func canSend(_ kind: BuddyStampKind, to member: Member, in group: Group) -> Bool {
        guard let me = myRecordName, member.userRecordName != me else { return false }
        let mine = group.stamps.filter { $0.from == me }
        if mine.contains(where: { $0.to == member.userRecordName && $0.kind == kind }) { return false }
        return sentToday < Self.dailyStampLimit
    }

    private var sentToday: Int {
        let saved = UserDefaults.standard.dictionary(forKey: Self.sentStampsKey) as? [String: Int] ?? [:]
        return saved[BuddyTotals.dayKey()] ?? 0
    }

    func send(_ kind: BuddyStampKind, to member: Member, in group: Group) async {
        guard canSend(kind, to: member, in: group), let me = myRecordName else { return }
        let today = BuddyTotals.dayKey()
        // 同じ相手に同じスタンプは1日1回なので、名前を決めておけば二重に送られない
        let name = "stamp-\(today)-\(kind.rawValue)-\(me)-\(member.userRecordName)"
        let record = CKRecord(recordType: "BuddyStamp", recordID: CKRecord.ID(recordName: name, zoneID: group.zoneID))
        record["from"] = me as NSString
        record["to"] = member.userRecordName as NSString
        record["kind"] = kind.rawValue as NSString
        record["dayKey"] = today as NSString
        do {
            try await save([record], in: database(for: group), policy: .allKeys)
            UserDefaults.standard.set([today: sentToday + 1], forKey: Self.sentStampsKey)
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                groups[index].stamps.append(Stamp(recordName: name, from: me, to: member.userRecordName, kind: kind, dayKey: today))
            }
        } catch {
            message = Self.describe(error)
        }
    }

    // MARK: - 資格ごとの人数（公開データベース。名前は書かない）

    // 勉強中で、資格を選んでいるときだけ「presence-<利用者番号>」を置く。止めたら消す
    func updatePresence() {
        guard isActive else { return }
        let exam = BuddyProfile.exam
        let until = studyingUntil
        Task {
            guard let me = await ensureMe() else { return }
            let id = CKRecord.ID(recordName: "presence-" + me)
            if let exam, let until {
                let record = CKRecord(recordType: "BuddyPresence", recordID: id)
                record["exam"] = exam.rawValue as NSString
                record["until"] = until as NSDate
                _ = try? await publicDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            } else {
                _ = try? await publicDB.modifyRecords(saving: [], deleting: [id])
            }
        }
    }

    func refreshExamCounts() async {
        guard isActive else { return }
        let query = CKQuery(recordType: "BuddyPresence", predicate: NSPredicate(format: "until > %@", Date() as NSDate))
        var counts: [BuddyExam: Int] = [:]
        do {
            var page = try await publicDB.records(matching: query, desiredKeys: ["exam"], resultsLimit: 200)
            var pages = 1
            while true {
                for (_, result) in page.matchResults {
                    if case .success(let record) = result, let exam = BuddyExam(rawValue: record["exam"] as? String ?? "") {
                        counts[exam, default: 0] += 1
                    }
                }
                // 多くても 1000人まで数える
                guard let cursor = page.queryCursor, pages < 5 else { break }
                page = try await publicDB.records(continuingMatchFrom: cursor, desiredKeys: ["exam"], resultsLimit: 200)
                pages += 1
            }
            examCounts = counts
        } catch {
            // 数えられなかったときは前の数のまま
        }
    }

    func ensureMe() async -> String? {
        if let myRecordName { return myRecordName }
        guard (try? await container.accountStatus()) == .available,
              let id = try? await container.userRecordID() else { return nil }
        myRecordName = id.recordName
        return id.recordName
    }

    // MARK: - 通知（CloudKit の変化を静かなプッシュで受け取り、端末の中で通知を出す）

    private var notifiesOnNextRefresh = false

    func handlePush() async {
        notifiesOnNextRefresh = true
        await refresh()
        await WatchCloud.shared.refresh(post: true)
    }

    func subscribeIfNeeded() async {
        BuddyNotifier.registerForPush()
        guard !UserDefaults.standard.bool(forKey: Self.subscribedKey) else { return }
        do {
            for (db, id) in [(privateDB, "buddies-private"), (sharedDB, "buddies-shared")] {
                let subscription = CKDatabaseSubscription(subscriptionID: id)
                let info = CKSubscription.NotificationInfo()
                info.shouldSendContentAvailable = true
                subscription.notificationInfo = info
                _ = try await db.modifySubscriptions(saving: [subscription], deleting: [])
            }
            UserDefaults.standard.set(true, forKey: Self.subscribedKey)
        } catch {
            // 次に開いたときにまた試す
        }
    }

    // MARK: - 写真

    // 期限が過ぎた写真を消す。オーナーは全部、ほかの人は自分のものだけ消せる
    private func removeExpiredPhotos() async {
        for group in groups {
            let expired = group.photos.filter { $0.isExpired && (group.isOwner || $0.from == myRecordName) }
            guard !expired.isEmpty else { continue }
            let ids = expired.map { CKRecord.ID(recordName: $0.recordName, zoneID: group.zoneID) }
            _ = try? await database(for: group).modifyRecords(saving: [], deleting: ids)
        }
        BuddyPhotos.clearOldCache()
        for index in groups.indices {
            groups[index].photos.removeAll(where: \.isExpired)
        }
    }

    // 開発者が CloudKit のコンソールで置く「ban-<利用者番号>」があれば、写真を送れない・その人の写真は出さない
    private func checkPhotoBans() async {
        var names = Set(groups.flatMap(\.photos).map(\.from))
        if let me = myRecordName { names.insert(me) }
        guard !names.isEmpty else { return }
        let ids = names.map { CKRecord.ID(recordName: "ban-" + $0) }
        guard let results = try? await publicDB.records(for: ids, desiredKeys: []) else { return }
        var banned = Set<String>()
        for (id, result) in results {
            if case .success = result { banned.insert(String(id.recordName.dropFirst(4))) }
        }
        bannedSenders = banned
        isBannedFromPhotos = myRecordName.map { banned.contains($0) } ?? false
    }

    func hasSentPhotoToday(in group: Group) -> Bool {
        guard let me = myRecordName else { return false }
        return group.photos.contains { $0.from == me && !$0.isExpired && Calendar.current.isDateInToday($0.createdAt) }
    }

    func sendPhoto(_ data: Data, to group: Group) async -> Bool {
        guard group.photosEnabled, BuddyProfile.photosOn, !hasSentPhotoToday(in: group), let me = myRecordName else { return false }
        await checkPhotoBans()
        guard !isBannedFromPhotos else {
            message = L10n.string("写真の機能は使えなくなっています")
            return false
        }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: file) }
        do {
            try data.write(to: file)
            let now = Date()
            let name = "photo-\(BuddyTotals.dayKey(now))-\(me)"
            let record = CKRecord(recordType: "BuddyPhoto", recordID: CKRecord.ID(recordName: name, zoneID: group.zoneID))
            record["from"] = me as NSString
            record["nickname"] = BuddyProfile.nickname as NSString
            record["code"] = NSNumber(value: BuddyProfile.code)
            record["createdAt"] = now as NSDate
            record["expiresAt"] = now.addingTimeInterval(BuddyPhotos.lifetime) as NSDate
            record["image"] = CKAsset(fileURL: file)
            try await save([record], in: database(for: group), policy: .allKeys)
            BuddyPhotos.store(data, for: name)
            await refresh()
            return true
        } catch {
            message = Self.describe(error)
            return false
        }
    }

    // 写真を消す。オーナーはだれの写真でも、ほかの人は自分の写真だけ
    func deletePhoto(_ photo: Photo, in group: Group) async {
        guard group.isOwner || photo.from == myRecordName else { return }
        do {
            try await save([], deleting: [CKRecord.ID(recordName: photo.recordName, zoneID: group.zoneID)], in: database(for: group))
            BuddyPhotos.remove(photo.recordName)
            await refresh()
        } catch {
            message = Self.describe(error)
        }
    }

    // オーナーが、このグループで写真を使うかを決める（初めはオフ）
    func setPhotosEnabled(_ enabled: Bool, in group: Group) async {
        guard group.isOwner else { return }
        do {
            let record = try await privateDB.record(for: CKRecord.ID(recordName: Self.groupRecordName, zoneID: group.zoneID))
            record["photosEnabled"] = NSNumber(value: enabled ? 1 : 0)
            try await save([record], in: privateDB, policy: .changedKeys)
            await refresh()
        } catch {
            message = Self.describe(error)
        }
    }

    // MARK: - 通報（公開データベースに置き、開発者が CloudKit のコンソールで見る。ほかの利用者には見えない設定にする）

    func report(userRecordName: String, nickname: String, code: Int, group: Group, reason: BuddyReportReason, note: String, photo: Photo?, photoData: Data?) async -> Bool {
        guard let me = await ensureMe() else { return false }
        let record = CKRecord(recordType: "BuddyReport", recordID: CKRecord.ID(recordName: "report-" + UUID().uuidString))
        record["reporter"] = me as NSString
        record["target"] = userRecordName as NSString
        record["targetNickname"] = nickname as NSString
        record["targetCode"] = NSNumber(value: code)
        record["groupName"] = group.name as NSString
        record["groupZone"] = "\(group.zoneID.ownerName)/\(group.zoneID.zoneName)" as NSString
        record["reason"] = reason.rawValue as NSString
        record["note"] = String(note.prefix(1000)) as NSString
        record["appVersion"] = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") as NSString
        var file: URL?
        if let photo, let photoData {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            try? photoData.write(to: url)
            file = url
            record["photo"] = CKAsset(fileURL: url)
            record["photoCreatedAt"] = photo.createdAt as NSDate
        }
        defer { if let file { try? FileManager.default.removeItem(at: file) } }
        do {
            try await save([record], in: publicDB, policy: .allKeys)
            return true
        } catch {
            message = Self.describe(error)
            return false
        }
    }

    // MARK: - スクショ用のデモ（-StudyReelDemoScreen buddies）。CloudKit には何も書かない

    func loadDemo() {
        guard DemoMode.isActive else { return }
        let en = Locale.preferredLanguages.first?.hasPrefix("en") == true
        BuddyProfile.nickname = en ? "Yu" : "ゆう"
        BuddyProfile.icon = .pencil
        myRecordName = "demo-me"
        availability = .available
        let now = Date()
        let day = BuddyTotals.dayKey(now)
        let week = BuddyTotals.weekKey(now)
        func member(_ id: String, _ ja: String, _ english: String, _ icon: BuddyIcon, studyingFor minutes: Int?, today: Int, week weekMinutes: Int, streak: Int) -> Member {
            Member(
                userRecordName: id, nickname: en ? english : ja, icon: icon, code: 1000 + abs(id.hashValue % 9000),
                studyingSince: minutes.map { now.addingTimeInterval(TimeInterval(-$0 * 60)) },
                studyingUntil: minutes.map { _ in now.addingTimeInterval(3600) },
                todaySeconds: today * 60, todayKey: day, weekSeconds: weekMinutes * 60, weekKey: week,
                streakDays: streak, hidesRanking: false
            )
        }
        let members = [
            member("demo-me", "ゆう", "Yu", .pencil, studyingFor: nil, today: 95, week: 610, streak: 12),
            member("demo-2", "はると", "Haruto", .flame, studyingFor: 72, today: 152, week: 720, streak: 21),
            member("demo-3", "みお", "Mio", .leaf, studyingFor: 25, today: 64, week: 480, streak: 5),
            member("demo-4", "そうた", "Sota", .star, studyingFor: nil, today: 40, week: 355, streak: 3),
        ]
        func stamp(_ kind: BuddyStampKind, from: String, to: String) -> Stamp {
            Stamp(recordName: "demo-\(kind.rawValue)-\(from)-\(to)", from: from, to: to, kind: kind, dayKey: day)
        }
        groups = [Group(
            zoneID: CKRecordZone.ID(zoneName: Self.zonePrefix + "demo", ownerName: CKCurrentUserDefaultName),
            name: en ? "Exam Buddies" : "受験仲間",
            inviteToken: "demo",
            isOwner: true,
            members: members,
            stamps: [stamp(.ganbare, from: "demo-2", to: "demo-me"), stamp(.sugoi, from: "demo-3", to: "demo-me"),
                     stamp(.otsukare, from: "demo-me", to: "demo-2"), stamp(.issho, from: "demo-4", to: "demo-3")],
            photos: [],
            photosEnabled: false,
            participantCount: members.count
        )]
        examCounts = [.toeic: 23, .eiken: 14, .kyotsu: 41]
        BuddyProfile.exam = .kyotsu
    }

    // MARK: - これから作る機能への反応（開発者がコンソールで数える。名前は送らない）

    // 1人1件（「interest-<機能>-<利用者番号>」）。答えを変えたら上書きする
    func recordInterest(feature: String, wants: Bool, source: String) async -> Bool {
        guard isActive, let me = await ensureMe() else { return false }
        let record = CKRecord(recordType: "BuddyInterest", recordID: CKRecord.ID(recordName: "interest-\(feature)-\(me)"))
        record["feature"] = feature as NSString
        record["answer"] = (wants ? "yes" : "no") as NSString
        record["source"] = source as NSString
        do {
            try await save([record], in: publicDB, policy: .allKeys)
            return true
        } catch {
            message = Self.describe(error)
            return false
        }
    }

    // MARK: - ブロック

    var blocked: Set<String> { Set(UserDefaults.standard.stringArray(forKey: Self.blockedKey) ?? []) }

    func block(_ member: Member) {
        var list = blocked
        list.insert(member.userRecordName)
        UserDefaults.standard.set(Array(list), forKey: Self.blockedKey)
        objectWillChange.send()
    }

    func unblock(_ userRecordName: String) {
        var list = blocked
        list.remove(userRecordName)
        UserDefaults.standard.set(Array(list), forKey: Self.blockedKey)
        objectWillChange.send()
    }

    // MARK: - 小さな道具

    static func memberID(_ userRecordName: String, zone: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "member-" + userRecordName, zoneID: zone)
    }

    static func newToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private func markHandled(_ request: JoinRequest) {
        var handled = UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? []
        handled.append(request.recordName)
        UserDefaults.standard.set(Array(handled.suffix(500)), forKey: Self.handledKey)
    }

    private func savePending() {
        UserDefaults.standard.set(try? JSONEncoder().encode(pendingJoins), forKey: Self.pendingKey)
    }

    private func removePending(_ pending: PendingJoin) {
        pendingJoins.removeAll { $0.requestName == pending.requestName }
        savePending()
    }

    func fetchParticipant(userRecordName: String) async throws -> CKShare.Participant {
        try await withCheckedThrowingContinuation { continuation in
            let info = CKUserIdentity.LookupInfo(userRecordID: CKRecord.ID(recordName: userRecordName))
            let operation = CKFetchShareParticipantsOperation(userIdentityLookupInfos: [info])
            var found: CKShare.Participant?
            operation.perShareParticipantResultBlock = { _, result in
                if case .success(let participant) = result { found = participant }
            }
            operation.fetchShareParticipantsResultBlock = { result in
                switch result {
                case .success:
                    if let found { continuation.resume(returning: found) } else { continuation.resume(throwing: CKError(.unknownItem)) }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    func fetchShareMetadata(_ url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            var found: CKShare.Metadata?
            var failure: Error?
            operation.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success(let metadata): found = metadata
                case .failure(let error): failure = error
                }
            }
            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let found { continuation.resume(returning: found) } else { continuation.resume(throwing: failure ?? CKError(.unknownItem)) }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    func accept(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            var failure: Error?
            operation.perShareResultBlock = { _, result in
                if case .failure(let error) = result { failure = error }
            }
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    if let failure { continuation.resume(throwing: failure) } else { continuation.resume() }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    // modifyRecords は1件ずつの失敗では投げないので、失敗があれば最初のものを投げる（消すときに見つからないのは成功とみなす）
    func save(_ records: [CKRecord], deleting: [CKRecord.ID] = [], in db: CKDatabase, policy: CKModifyRecordsOperation.RecordSavePolicy = .ifServerRecordUnchanged) async throws {
        let result = try await db.modifyRecords(saving: records, deleting: deleting, savePolicy: policy)
        for (_, item) in result.saveResults {
            if case .failure(let error) = item { throw error }
        }
        for (_, item) in result.deleteResults {
            if case .failure(let error) = item, (error as? CKError)?.code != .unknownItem { throw error }
        }
    }

    static func describe(_ error: Error) -> String {
        guard let error = error as? CKError else { return error.localizedDescription }
        switch error.code {
        case .networkUnavailable, .networkFailure: return L10n.string("インターネットにつながっていません")
        case .notAuthenticated: return L10n.string("iCloud にサインインすると使えます")
        case .quotaExceeded: return L10n.string("iCloud の空き容量が足りません")
        case .permissionFailure: return L10n.string("この操作はできません")
        default:
            // 原因を調べられるように、CloudKit が返した説明も出す
            let detail = (error.userInfo[NSLocalizedDescriptionKey] as? String) ?? error.localizedDescription
            return L10n.format("うまくいきませんでした。しばらくしてからもう一度お試しください（コード %d）", error.code.rawValue) + "\n" + detail
        }
    }
}
