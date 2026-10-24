import CloudKit
import Foundation

// 見守り：自分の勉強状況を、保護者や塾の先生に見せる（docs/family-and-school.md）。自前のサーバーは持たない
//
// しくみ
// - 見る人（保護者・先生）は「見守りコード」を作る。公開データベースの BuddyWatchCode（watch-<トークン>）に、種類・名前・見る人の利用者番号を置き、
//   QR（studyreel://watch/join?t=トークン）にして、見せる人に読んでもらう
// - 見せる人（子・生徒）が QR を読んで「見せる」を押すと、自分の iCloud にゾーン（watch-…）を作り、見る人だけを参加者にして共有する
//   ゾーンの中は「watch」（だれに見せているか）と自分の「member-…」、見る人からのスタンプ
//   見る人が受け取れるように、公開データベースに申し出（BuddyWatchOffer、offer-<トークン>-<自分>）と共有の URL を書く
// - 見る人が「受け取る」を押すと共有に入る。断る・外すときは BuddyJoinDenial（no-offer-…）を書き、見せる人のアプリがゾーンを消す
// - 始めるのも止めるのも見せる人。見せる人1人・見る人1人ごとにゾーンが分かれるので、生徒どうし・保護者どうしは見えない
// - 塾のクラスを作るには、開発者が発行する塾コード（公開データベースの BuddySchoolCode、school-<コード>）が要る
@MainActor
final class WatchCloud: ObservableObject {
    static let shared = WatchCloud()

    static let zonePrefix = "watch-"
    static let maxClasses = 10
    static let defaultClassSize = 50
    // 見る人が送れるスタンプ
    static let stampKinds: [BuddyStampKind] = [.ganbare, .otsukare, .sugoi]

    enum Kind: String {
        case family, school
    }

    // 自分が見る人として作ったコード（保護者は1つ、先生はクラスごとに1つ）
    struct Code: Identifiable, Equatable {
        let token: String
        var kind: Kind
        var name: String
        var schoolName: String
        var viewer: String
        var id: String { token }
    }

    // 自分が見せている相手
    struct Sharing: Identifiable, Equatable {
        let zoneID: CKRecordZone.ID
        var kind: Kind
        var token: String
        var viewer: String
        var viewerName: String
        var schoolName: String
        var isAccepted: Bool
        var stamps: [BuddyCloud.Stamp]
        var id: String { zoneID.zoneName }
    }

    // 自分が見ている人
    struct Watched: Identifiable, Equatable {
        let zoneID: CKRecordZone.ID
        var kind: Kind
        var token: String
        var member: BuddyCloud.Member
        var stamps: [BuddyCloud.Stamp]
        var id: String { zoneID.ownerName + "/" + zoneID.zoneName }

        // 3日より前から勉強していない（または一度も記録がない）
        var isQuiet: Bool {
            guard let last = member.lastStudiedAt else { return true }
            return Date().timeIntervalSince(last) > 3 * 24 * 3600
        }
    }

    // 見せたいという申し出（見る人が受け取るか決める）
    struct Offer: Identifiable, Equatable {
        let recordName: String
        var token: String
        var sharer: String
        var nickname: String
        var icon: BuddyIcon
        var code: Int
        var shareURL: String
        var zone: String
        var id: String { recordName }
    }

    // 塾コードで分かる塾の情報
    struct School: Codable, Equatable {
        var code: String
        var name: String
        var maxStudents: Int
        var expiresAt: Date?
        var isValid: Bool { expiresAt.map { $0 > Date() } ?? true }
    }

    @Published private(set) var codes: [Code] = []
    @Published private(set) var sharings: [Sharing] = []
    @Published private(set) var watched: [Watched] = []
    @Published private(set) var offers: [String: [Offer]] = [:]   // トークン → 申し出
    @Published private(set) var school: School?
    @Published private(set) var isLoading = false
    @Published var message: String?

    private var cloud: BuddyCloud { BuddyCloud.shared }
    private var hasLoaded = false
    private static let watchRecordName = "watch"
    private static let handledKey = "watch_handled_offers"
    private static let schoolKey = "watch_school"

    private init() {
        school = (try? JSONDecoder().decode(School.self, from: UserDefaults.standard.data(forKey: Self.schoolKey) ?? Data()))
    }

    var isSharingWithFamily: Bool { sharings.contains { $0.kind == .family } }
    var familyCode: Code? { codes.first { $0.kind == .family } }
    var classes: [Code] { codes.filter { $0.kind == .school }.sorted { $0.name < $1.name } }

    func students(in code: Code) -> [Watched] {
        watched.filter { $0.token == code.token }
    }

    var children: [Watched] {
        watched.filter { $0.kind == .family }
    }

    // MARK: - 読み込み

    func refresh(post: Bool = false) async {
        guard cloud.isActive, let me = await cloud.ensureMe() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            codes = try await fetchMyCodes(me)
            sharings = try await loadSharings(me)
            var loaded: [Watched] = []
            for zone in try await cloud.sharedDB.allRecordZones() where zone.zoneID.zoneName.hasPrefix(Self.zonePrefix) {
                if let item = try? await loadWatched(zone.zoneID) { loaded.append(item) }
            }
            watched = loaded.sorted { $0.member.nickname < $1.member.nickname }
            var found: [String: [Offer]] = [:]
            let handled = Set(UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? [])
            for code in codes {
                let inside = Set(watched.filter { $0.token == code.token }.map(\.member.userRecordName))
                found[code.token] = ((try? await fetchOffers(token: code.token)) ?? [])
                    .filter { !handled.contains($0.recordName) && !inside.contains($0.sharer) }
            }
            offers = found
            if school != nil { await checkSchool() }
            hasLoaded = true
            BuddyNotifier.processWatch(sharings: sharings, watched: watched, me: me, post: post)
            if !sharings.isEmpty || !watched.isEmpty { await cloud.subscribeIfNeeded() }
        } catch {
            message = BuddyCloud.describe(error)
        }
    }

    private func fetchMyCodes(_ me: String) async throws -> [Code] {
        let query = CKQuery(recordType: "BuddyWatchCode", predicate: NSPredicate(format: "viewer == %@", me))
        let result = try await cloud.publicDB.records(matching: query, resultsLimit: 50)
        return result.matchResults.compactMap { _, item in
            guard case .success(let record) = item else { return nil }
            return Self.code(record)
        }
    }

    private static func code(_ record: CKRecord) -> Code? {
        guard let kind = Kind(rawValue: record["kind"] as? String ?? "") else { return nil }
        return Code(
            token: String(record.recordID.recordName.dropFirst("watch-".count)),
            kind: kind,
            name: record["name"] as? String ?? "",
            schoolName: record["schoolName"] as? String ?? "",
            viewer: record["viewer"] as? String ?? ""
        )
    }

    // 自分が見せているゾーン。断られた・外されたものは消す。受け取ってもらえたら申し出を片づける
    private func loadSharings(_ me: String) async throws -> [Sharing] {
        var loaded: [Sharing] = []
        for zone in try await cloud.privateDB.allRecordZones() where zone.zoneID.zoneName.hasPrefix(Self.zonePrefix) {
            let records = try await zoneRecords(zone.zoneID, in: cloud.privateDB)
            guard let watch = records.first(where: { $0.recordID.recordName == Self.watchRecordName }),
                  let kind = Kind(rawValue: watch["kind"] as? String ?? "") else {
                // 作りかけで残ったゾーン
                _ = try? await cloud.privateDB.deleteRecordZone(withID: zone.zoneID)
                continue
            }
            let token = watch["token"] as? String ?? ""
            let viewerName = watch["viewerName"] as? String ?? ""
            let offerName = Self.offerName(token: token, sharer: me)
            // 断り・外しは、このゾーンあてのものだけ見る（前に外されたあと、また見せ始めたときのため）
            if let denial = try? await cloud.publicDB.record(for: CKRecord.ID(recordName: "no-" + offerName)),
               denial["zone"] as? String == zone.zoneID.zoneName {
                _ = try? await cloud.privateDB.deleteRecordZone(withID: zone.zoneID)
                _ = try? await cloud.publicDB.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: offerName)])
                message = L10n.format("%@さんへの共有は終わりました", viewerName)
                continue
            }
            let share = records.compactMap { $0 as? CKShare }.first
            let accepted = share?.participants.contains { $0.role != .owner && $0.acceptanceStatus == .accepted } ?? false
            if accepted {
                _ = try? await cloud.publicDB.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: offerName)])
            }
            let today = BuddyTotals.dayKey()
            loaded.append(Sharing(
                zoneID: zone.zoneID,
                kind: kind,
                token: token,
                viewer: watch["viewer"] as? String ?? "",
                viewerName: viewerName,
                schoolName: watch["schoolName"] as? String ?? "",
                isAccepted: accepted,
                stamps: records.filter { $0.recordType == "BuddyStamp" }.compactMap(BuddyCloud.stamp).filter { $0.dayKey == today }
            ))
        }
        return loaded.sorted { $0.viewerName < $1.viewerName }
    }

    private func loadWatched(_ zoneID: CKRecordZone.ID) async throws -> Watched? {
        let records = try await zoneRecords(zoneID, in: cloud.sharedDB)
        guard let watch = records.first(where: { $0.recordID.recordName == Self.watchRecordName }),
              let kind = Kind(rawValue: watch["kind"] as? String ?? ""),
              let member = records.first(where: { $0.recordType == "BuddyMember" }).map(BuddyCloud.member) else { return nil }
        let today = BuddyTotals.dayKey()
        return Watched(
            zoneID: zoneID,
            kind: kind,
            token: watch["token"] as? String ?? "",
            member: member,
            stamps: records.filter { $0.recordType == "BuddyStamp" }.compactMap(BuddyCloud.stamp).filter { $0.dayKey == today }
        )
    }

    private func zoneRecords(_ zoneID: CKRecordZone.ID, in db: CKDatabase) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        var more = true
        while more {
            let changes = try await db.recordZoneChanges(inZoneWith: zoneID, since: token, desiredKeys: BuddyCloud.listKeys)
            for (_, result) in changes.modificationResultsByID {
                if case .success(let modification) = result { records.append(modification.record) }
            }
            token = changes.changeToken
            more = changes.moreComing
        }
        return records
    }

    private func fetchOffers(token: String) async throws -> [Offer] {
        let query = CKQuery(recordType: "BuddyWatchOffer", predicate: NSPredicate(format: "token == %@", token))
        let result = try await cloud.publicDB.records(matching: query, resultsLimit: 100)
        return result.matchResults.compactMap { _, item in
            guard case .success(let record) = item else { return nil }
            return Offer(
                recordName: record.recordID.recordName,
                token: record["token"] as? String ?? "",
                sharer: record["sharer"] as? String ?? "",
                nickname: record["nickname"] as? String ?? "",
                icon: BuddyIcon(rawValue: record["icon"] as? String ?? "") ?? .pencil,
                code: record["code"] as? Int ?? 0,
                shareURL: record["shareURL"] as? String ?? "",
                zone: record["zone"] as? String ?? ""
            )
        }
    }

    // MARK: - 見る人：コードを作る・消す

    // 保護者のコード。name は見せる人の画面に出る呼び名（例：お母さん）
    func createFamilyCode(name: String) async -> Code? {
        if let familyCode { return familyCode }
        return await createCode(kind: .family, name: name, schoolName: "")
    }

    // 先生のクラス。塾コードが有効なときだけ作れる
    func createClass(name: String) async -> Code? {
        await checkSchool()
        guard let school, school.isValid else {
            message = L10n.string("塾コードを確かめられませんでした")
            return nil
        }
        guard classes.count < Self.maxClasses else {
            message = L10n.format("作れるクラスは%d個までです", Self.maxClasses)
            return nil
        }
        return await createCode(kind: .school, name: name, schoolName: school.name)
    }

    private func createCode(kind: Kind, name: String, schoolName: String) async -> Code? {
        guard let me = await cloud.ensureMe() else { return nil }
        let token = BuddyCloud.newToken()
        let record = CKRecord(recordType: "BuddyWatchCode", recordID: CKRecord.ID(recordName: "watch-" + token))
        record["kind"] = kind.rawValue as NSString
        record["name"] = name as NSString
        record["schoolName"] = schoolName as NSString
        record["viewer"] = me as NSString
        do {
            try await cloud.save([record], in: cloud.publicDB, policy: .allKeys)
            let code = Code(token: token, kind: kind, name: name, schoolName: schoolName, viewer: me)
            codes.append(code)
            return code
        } catch {
            message = BuddyCloud.describe(error)
            return nil
        }
    }

    // コードを消す。もう見ている人の共有も終える
    func deleteCode(_ code: Code) async {
        for item in watched where item.token == code.token {
            await remove(item)
        }
        do {
            try await cloud.save([], deleting: [CKRecord.ID(recordName: "watch-" + code.token)], in: cloud.publicDB)
            codes.removeAll { $0.token == code.token }
            offers[code.token] = nil
        } catch {
            message = BuddyCloud.describe(error)
        }
    }

    static func joinURL(for code: Code) -> URL? {
        var components = URLComponents()
        components.scheme = "studyreel"
        components.host = "watch"
        components.path = "/join"
        components.queryItems = [URLQueryItem(name: "t", value: code.token)]
        return components.url
    }

    // MARK: - 見せる人：共有を始める・やめる

    // QR のトークンから、だれに見せるのかを調べる
    func lookUp(token: String) async -> Code? {
        guard cloud.isActive else { return nil }
        do {
            let record = try await cloud.publicDB.record(for: CKRecord.ID(recordName: "watch-" + token))
            return Self.code(record)
        } catch {
            message = (error as? CKError)?.code == .unknownItem
                ? L10n.string("この QR コードは使えなくなっています")
                : BuddyCloud.describe(error)
            return nil
        }
    }

    func isSharing(with code: Code) -> Bool {
        sharings.contains { $0.token == code.token }
    }

    func share(with code: Code) async -> Bool {
        guard let me = await cloud.ensureMe(), BuddyProfile.isReady else { return false }
        guard code.viewer != me else {
            message = L10n.string("自分のコードには見せられません")
            return false
        }
        guard !isSharing(with: code) else { return true }
        let zone = CKRecordZone(zoneName: Self.zonePrefix + UUID().uuidString)
        do {
            _ = try await cloud.privateDB.save(zone)
            let watch = CKRecord(recordType: "BuddyWatch", recordID: CKRecord.ID(recordName: Self.watchRecordName, zoneID: zone.zoneID))
            watch["kind"] = code.kind.rawValue as NSString
            watch["token"] = code.token as NSString
            watch["viewer"] = code.viewer as NSString
            watch["viewerName"] = code.name as NSString
            watch["schoolName"] = code.schoolName as NSString
            try await cloud.save([watch], in: cloud.privateDB)
            // 見る人だけを参加者にする（スタンプを書けるように読み書き）
            let participant = try await cloud.fetchParticipant(userRecordName: code.viewer)
            participant.permission = .readWrite
            let share = CKShare(recordZoneID: zone.zoneID)
            share[CKShare.SystemFieldKey.title] = BuddyProfile.nickname as NSString
            share.publicPermission = .none
            share.addParticipant(participant)
            try await cloud.save([share], in: cloud.privateDB)
            if let mine = cloud.myMemberRecord(in: zone.zoneID, detailed: true) {
                try await cloud.save([mine], in: cloud.privateDB, policy: .allKeys)
            }
            let saved = try await cloud.privateDB.record(for: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone.zoneID)) as? CKShare
            guard let url = saved?.url else { throw CKError(.internalError) }
            let offer = CKRecord(recordType: "BuddyWatchOffer", recordID: CKRecord.ID(recordName: Self.offerName(token: code.token, sharer: me)))
            offer["token"] = code.token as NSString
            offer["sharer"] = me as NSString
            offer["nickname"] = BuddyProfile.nickname as NSString
            offer["icon"] = BuddyProfile.icon.rawValue as NSString
            offer["code"] = NSNumber(value: BuddyProfile.code)
            offer["shareURL"] = url.absoluteString as NSString
            offer["zone"] = zone.zoneID.zoneName as NSString
            try await cloud.save([offer], in: cloud.publicDB, policy: .allKeys)
            await refresh()
            return true
        } catch {
            _ = try? await cloud.privateDB.deleteRecordZone(withID: zone.zoneID)
            message = BuddyCloud.describe(error)
            return false
        }
    }

    func stopSharing(_ sharing: Sharing) async {
        guard let me = await cloud.ensureMe() else { return }
        do {
            _ = try await cloud.privateDB.deleteRecordZone(withID: sharing.zoneID)
            _ = try? await cloud.publicDB.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: Self.offerName(token: sharing.token, sharer: me))])
            sharings.removeAll { $0.id == sharing.id }
        } catch {
            message = BuddyCloud.describe(error)
        }
    }

    // 自分の勉強状況を、見せている全員のゾーンに書く（BuddyCloud が状況を変えたときに呼ぶ）
    func pushStatus() async {
        guard cloud.isActive else { return }
        if !hasLoaded { await refresh() }
        for sharing in sharings {
            guard let record = cloud.myMemberRecord(in: sharing.zoneID, detailed: true) else { continue }
            try? await cloud.save([record], in: cloud.privateDB, policy: .allKeys)
        }
    }

    // MARK: - 見る人：受け取る・断る・外す

    func accept(_ offer: Offer, for code: Code) async {
        if code.kind == .school {
            let limit = school?.maxStudents ?? Self.defaultClassSize
            guard students(in: code).count < limit else {
                message = L10n.format("1つのクラスに入れるのは%d人までです", limit)
                return
            }
        }
        guard let url = URL(string: offer.shareURL) else { return }
        do {
            let metadata = try await cloud.fetchShareMetadata(url)
            try await cloud.accept(metadata)
            markHandled(offer)
            await refresh()
        } catch {
            message = BuddyCloud.describe(error)
        }
    }

    func decline(_ offer: Offer) async {
        let denial = CKRecord(recordType: "BuddyJoinDenial", recordID: CKRecord.ID(recordName: "no-" + offer.recordName))
        denial["token"] = offer.token as NSString
        denial["zone"] = offer.zone as NSString
        _ = try? await cloud.publicDB.modifyRecords(saving: [denial], deleting: [], savePolicy: .allKeys)
        markHandled(offer)
        offers[offer.token]?.removeAll { $0.id == offer.id }
    }

    // 見るのをやめる。相手のアプリにも知らせて、相手の共有を片づけてもらう
    func remove(_ item: Watched) async {
        let name = Self.offerName(token: item.token, sharer: item.member.userRecordName)
        let denial = CKRecord(recordType: "BuddyJoinDenial", recordID: CKRecord.ID(recordName: "no-" + name))
        denial["token"] = item.token as NSString
        denial["zone"] = item.zoneID.zoneName as NSString
        _ = try? await cloud.publicDB.modifyRecords(saving: [denial], deleting: [], savePolicy: .allKeys)
        do {
            _ = try await cloud.sharedDB.deleteRecordZone(withID: item.zoneID)
            watched.removeAll { $0.id == item.id }
        } catch {
            message = BuddyCloud.describe(error)
        }
    }

    // MARK: - スタンプ（見る人 → 見せる人）

    func canSend(_ kind: BuddyStampKind, to item: Watched) -> Bool {
        guard let me = cloud.myRecordName else { return false }
        return !item.stamps.contains { $0.from == me && $0.kind == kind }
    }

    func send(_ kind: BuddyStampKind, to item: Watched) async {
        guard canSend(kind, to: item), let me = cloud.myRecordName else { return }
        let today = BuddyTotals.dayKey()
        let name = "stamp-\(today)-\(kind.rawValue)-\(me)-\(item.member.userRecordName)"
        let record = CKRecord(recordType: "BuddyStamp", recordID: CKRecord.ID(recordName: name, zoneID: item.zoneID))
        record["from"] = me as NSString
        record["to"] = item.member.userRecordName as NSString
        record["kind"] = kind.rawValue as NSString
        record["dayKey"] = today as NSString
        do {
            try await cloud.save([record], in: cloud.sharedDB, policy: .allKeys)
            if let index = watched.firstIndex(where: { $0.id == item.id }) {
                watched[index].stamps.append(BuddyCloud.Stamp(recordName: name, from: me, to: item.member.userRecordName, kind: kind, dayKey: today))
            }
        } catch {
            message = BuddyCloud.describe(error)
        }
    }

    // MARK: - 塾コード

    func activateSchool(code raw: String) async -> Bool {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !code.isEmpty else { return false }
        do {
            let record = try await cloud.publicDB.record(for: CKRecord.ID(recordName: "school-" + code))
            let found = Self.school(record, code: code)
            guard found.isValid else {
                message = L10n.string("この塾コードは期限が切れています")
                return false
            }
            saveSchool(found)
            return true
        } catch {
            message = (error as? CKError)?.code == .unknownItem
                ? L10n.string("塾コードが見つかりません。もう一度確かめてください")
                : BuddyCloud.describe(error)
            return false
        }
    }

    func forgetSchool() {
        saveSchool(nil)
    }

    private func checkSchool() async {
        guard let current = school else { return }
        do {
            let record = try await cloud.publicDB.record(for: CKRecord.ID(recordName: "school-" + current.code))
            saveSchool(Self.school(record, code: current.code))
        } catch {
            // 消されたコードは無効にする。つながらないときは前のまま
            if (error as? CKError)?.code == .unknownItem {
                saveSchool(School(code: current.code, name: current.name, maxStudents: current.maxStudents, expiresAt: .distantPast))
            }
        }
    }

    private static func school(_ record: CKRecord, code: String) -> School {
        let max = record["maxStudents"] as? Int ?? 0
        return School(
            code: code,
            name: record["schoolName"] as? String ?? "",
            maxStudents: max > 0 ? max : defaultClassSize,
            expiresAt: record["expiresAt"] as? Date
        )
    }

    private func saveSchool(_ value: School?) {
        school = value
        UserDefaults.standard.set(value.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.schoolKey)
    }

    // MARK: - 書き出し（先生）

    // クラスの一覧を CSV にする（名前、番号、今日、今週、連続日数、最後に勉強した日）
    func csv(for code: Code) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        var lines = [L10n.string("名前,番号,今日（分）,今週（分）,連続日数,最後に勉強した日")]
        for item in students(in: code).sorted(by: { $0.member.week > $1.member.week }) {
            let member = item.member
            let name = member.nickname.replacingOccurrences(of: "\"", with: "\"\"")
            lines.append([
                "\"\(name)\"",
                BuddyProfile.displayCode(member.code),
                String(member.today / 60),
                String(member.week / 60),
                String(member.streakDays),
                member.lastStudiedAt.map { formatter.string(from: $0) } ?? "",
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - 小さな道具

    static func offerName(token: String, sharer: String) -> String {
        "offer-\(token)-\(sharer)"
    }

    private func markHandled(_ offer: Offer) {
        var handled = UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? []
        handled.append(offer.recordName)
        UserDefaults.standard.set(Array(handled.suffix(500)), forKey: Self.handledKey)
    }
}
