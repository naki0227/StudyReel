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
    static let freeGroupLimit = 1
    static let proGroupLimit = 5
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

    private let container = CKContainer(identifier: BuddyCloud.containerIdentifier)
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    private static let zonePrefix = "buddies-"
    private static let groupRecordName = "group"
    private static let pendingKey = "buddy_pending_joins"
    private static let blockedKey = "buddy_blocked"
    private static let handledKey = "buddy_handled_requests"
    private static let sentStampsKey = "buddy_sent_stamps"

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
            var found: [String: [JoinRequest]] = [:]
            for group in groups where group.isOwner {
                found[group.id] = (try? await fetchRequests(token: group.inviteToken)) ?? []
            }
            requests = found
        } catch {
            message = Self.describe(error)
        }
    }

    private func loadGroup(_ zoneID: CKRecordZone.ID, in db: CKDatabase, isOwner: Bool) async throws -> Group {
        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        var more = true
        while more {
            let changes = try await db.recordZoneChanges(inZoneWith: zoneID, since: token)
            for (_, result) in changes.modificationResultsByID {
                if case .success(let modification) = result { records.append(modification.record) }
            }
            token = changes.changeToken
            more = changes.moreComing
        }
        let groupRecord = records.first { $0.recordID.recordName == Self.groupRecordName }
        let share = records.compactMap { $0 as? CKShare }.first
        let members = records.filter { $0.recordType == "BuddyMember" }.map(Self.member)
        let today = BuddyTotals.dayKey()
        let stamps = records.filter { $0.recordType == "BuddyStamp" }.compactMap(Self.stamp).filter { $0.dayKey == today }
        return Group(
            zoneID: zoneID,
            name: groupRecord?["name"] as? String ?? (share?[CKShare.SystemFieldKey.title] as? String ?? ""),
            inviteToken: groupRecord?["inviteToken"] as? String ?? "",
            isOwner: isOwner,
            members: members,
            stamps: stamps,
            participantCount: share?.participants.count ?? members.count
        )
    }

    private static func member(_ record: CKRecord) -> Member {
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
            hidesRanking: (record["hidesRanking"] as? Int ?? 0) == 1
        )
    }

    private static func stamp(_ record: CKRecord) -> Stamp? {
        guard let kind = BuddyStampKind(rawValue: record["kind"] as? String ?? "") else { return nil }
        return Stamp(
            recordName: record.recordID.recordName,
            from: record["from"] as? String ?? "",
            to: record["to"] as? String ?? "",
            kind: kind,
            dayKey: record["dayKey"] as? String ?? ""
        )
    }

    private func database(for group: Group) -> CKDatabase { group.isOwner ? privateDB : sharedDB }

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
            _ = try await privateDB.modifyRecords(saving: [groupRecord, share], deleting: [])
            try await saveMyMember(in: zone.zoneID, db: privateDB)
            await refresh()
            return groups.first { $0.zoneID == zone.zoneID }
        } catch {
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
            _ = try await privateDB.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
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
            _ = try await publicDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
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
            _ = try await privateDB.modifyRecords(saving: [share], deleting: [])
            guard let url = share.url else { return }
            let approval = CKRecord(recordType: "BuddyJoinApproval", recordID: CKRecord.ID(recordName: "ok-" + request.recordName))
            approval["shareURL"] = url.absoluteString as NSString
            _ = try await publicDB.modifyRecords(saving: [approval], deleting: [], savePolicy: .allKeys)
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
            _ = try await privateDB.modifyRecords(saving: [share], deleting: [Self.memberID(member.userRecordName, zone: group.zoneID)])
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
    }

    func studyEnded() {
        studyingSince = nil
        studyingUntil = nil
        pushMyStatus()
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
        }
    }

    private func saveMyMember(in zoneID: CKRecordZone.ID, db: CKDatabase) async throws {
        guard let me = myRecordName, BuddyProfile.isReady else { return }
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
        // 自分の行は自分だけが書くので、そのまま上書きする
        _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
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
            _ = try await database(for: group).modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            UserDefaults.standard.set([today: sentToday + 1], forKey: Self.sentStampsKey)
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                groups[index].stamps.append(Stamp(recordName: name, from: me, to: member.userRecordName, kind: kind, dayKey: today))
            }
        } catch {
            message = Self.describe(error)
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

    private static func memberID(_ userRecordName: String, zone: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "member-" + userRecordName, zoneID: zone)
    }

    private static func newToken() -> String {
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

    private func fetchParticipant(userRecordName: String) async throws -> CKShare.Participant {
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

    private func fetchShareMetadata(_ url: URL) async throws -> CKShare.Metadata {
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

    private func accept(_ metadata: CKShare.Metadata) async throws {
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

    static func describe(_ error: Error) -> String {
        guard let error = error as? CKError else { return error.localizedDescription }
        switch error.code {
        case .networkUnavailable, .networkFailure: return L10n.string("インターネットにつながっていません")
        case .notAuthenticated: return L10n.string("iCloud にサインインすると使えます")
        case .quotaExceeded: return L10n.string("iCloud の空き容量が足りません")
        case .permissionFailure: return L10n.string("この操作はできません")
        default: return L10n.string("うまくいきませんでした。しばらくしてからもう一度お試しください")
        }
    }
}
