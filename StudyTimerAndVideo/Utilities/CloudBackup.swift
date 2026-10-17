import Foundation
import SwiftData

// iCloud Drive への手動・自動バックアップ。無料で使えて、最初からオン
// ファイルアプリの「StudyReel」フォルダに出るので、そこから家族と共有もできる
// 記録は backup.json に、サムネイルと動画は Media フォルダにコピーする
@MainActor
final class CloudBackup: ObservableObject {
    static let shared = CloudBackup()

    static let autoBackupKey = "icloud_auto_backup"
    static let lastBackupKey = "icloud_last_backup"
    static let containerIdentifier = "iCloud.com.ni.StudyTimerAndVideo"

    @Published private(set) var isWorking = false
    @Published private(set) var lastBackupDate: Date?

    private init() {
        lastBackupDate = UserDefaults.standard.object(forKey: Self.lastBackupKey) as? Date
    }

    static var isAutoBackupEnabled: Bool {
        UserDefaults.standard.object(forKey: autoBackupKey) as? Bool ?? true
    }

    // iCloud にサインインしていて、iCloud Drive が使えるか
    static var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    static let needsBackupKey = "icloud_needs_backup"

    // 記録が増えたり変わったりしたときに呼ぶ。次の自動バックアップで必ず送る
    static func markChanged() {
        UserDefaults.standard.set(true, forKey: needsBackupKey)
    }

    // アプリが裏に回ったときや、記録を保存したあとに呼ぶ。変更がなければ1日1回まで
    static func backupIfNeeded(context: ModelContext) {
        guard isAutoBackupEnabled, isAvailable else { return }
        let hasChanges = UserDefaults.standard.bool(forKey: needsBackupKey)
        if !hasChanges, let last = shared.lastBackupDate, Calendar.current.isDateInToday(last) { return }
        Task { @MainActor in
            try? await shared.backupNow(context: context)
        }
    }

    func backupNow(context: ModelContext) async throws {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let snapshot = try BackupSnapshot(context: context)
        try await Task.detached(priority: .utility) {
            try CloudBackupFiles.write(snapshot)
        }.value

        let now = Date()
        lastBackupDate = now
        UserDefaults.standard.set(now, forKey: Self.lastBackupKey)
        UserDefaults.standard.set(false, forKey: Self.needsBackupKey)
    }

    // バックアップの内容を今の記録に足す。同じ記録は二重に入れない。戻した記録の数を返す
    @discardableResult
    func restore(context: ModelContext) async throws -> Int {
        guard !isWorking else { return 0 }
        isWorking = true
        defer { isWorking = false }

        let snapshot = try await Task.detached(priority: .userInitiated) {
            try CloudBackupFiles.read()
        }.value

        let restored = try snapshot.merge(into: context)
        try context.save()
        return restored
    }
}

enum CloudBackupError: LocalizedError {
    case notSignedIn
    case noBackup
    case failed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return L10n.string("iCloudにサインインしてください。")
        case .noBackup: return L10n.string("バックアップが見つかりません。")
        case .failed: return L10n.string("バックアップできませんでした。iCloudの空き容量を確認してください。")
        }
    }
}

// MARK: - 保存する中身

struct BackupSnapshot: Codable {
    struct SessionRecord: Codable {
        let id: UUID
        let date: Date
        let duration: Int
        let subject: String
        let recordedAt: Date?
        let title: String?
        let memo: String?
        let thumbnailFileName: String?
        let videoFileName: String?
        let tagNames: [String]
    }

    struct TagRecord: Codable {
        let name: String
        let colorHex: String
    }

    struct GoalRecord: Codable {
        let date: Date
        let targetDuration: Int
    }

    var version = 1
    var createdAt = Date()
    var sessions: [SessionRecord]
    var tags: [TagRecord]
    var goals: [GoalRecord]

    var mediaFileNames: [String] {
        sessions.flatMap { [$0.thumbnailFileName, $0.videoFileName].compactMap { $0 } }
    }

    @MainActor
    init(context: ModelContext) throws {
        let sessions = try context.fetch(FetchDescriptor<StudySession>())
        let tags = try context.fetch(FetchDescriptor<Tag>())
        let goals = try context.fetch(FetchDescriptor<DailyGoal>())

        self.sessions = sessions.map {
            SessionRecord(
                id: $0.id,
                date: $0.date,
                duration: $0.duration,
                subject: $0.subject,
                recordedAt: $0.recordedAt,
                title: $0.title,
                memo: $0.memo,
                thumbnailFileName: $0.thumbnailFileName,
                videoFileName: $0.videoFileName,
                tagNames: ($0.tags ?? []).map(\.name)
            )
        }
        self.tags = tags.map { TagRecord(name: $0.name, colorHex: $0.colorHex) }
        self.goals = goals.map { GoalRecord(date: $0.date, targetDuration: $0.targetDuration) }
    }

    // 記録は id、タグは名前、目標は日付で照らし合わせて、ないものだけ足す
    @MainActor
    func merge(into context: ModelContext) throws -> Int {
        var tagsByName: [String: Tag] = [:]
        for tag in try context.fetch(FetchDescriptor<Tag>()) {
            tagsByName[tag.name] = tag
        }
        for record in tags where tagsByName[record.name] == nil {
            let tag = Tag(name: record.name, colorHex: record.colorHex)
            context.insert(tag)
            tagsByName[record.name] = tag
        }

        let calendar = Calendar.current
        let goalDays = try Set(context.fetch(FetchDescriptor<DailyGoal>()).map { calendar.startOfDay(for: $0.date) })
        for record in goals where !goalDays.contains(calendar.startOfDay(for: record.date)) {
            context.insert(DailyGoal(date: record.date, targetDuration: record.targetDuration))
        }

        let existingIDs = try Set(context.fetch(FetchDescriptor<StudySession>()).map(\.id))
        var restored = 0
        for record in sessions where !existingIDs.contains(record.id) {
            let session = StudySession(
                id: record.id,
                date: record.date,
                duration: record.duration,
                subject: record.subject,
                tags: [],
                recordedAt: record.recordedAt,
                title: record.title,
                memo: record.memo,
                thumbnailFileName: MediaStore.videoURL(named: record.thumbnailFileName) == nil ? nil : record.thumbnailFileName,
                videoFileName: MediaStore.videoURL(named: record.videoFileName) == nil ? nil : record.videoFileName
            )
            context.insert(session)
            session.tags = record.tagNames.compactMap { tagsByName[$0] }
            restored += 1
        }
        return restored
    }
}

// MARK: - ファイルの読み書き（メインスレッド以外で呼ぶ）

enum CloudBackupFiles {
    private static let backupFileName = "backup.json"

    private static func rootURL() throws -> URL {
        guard FileManager.default.ubiquityIdentityToken != nil,
              let container = FileManager.default.url(forUbiquityContainerIdentifier: CloudBackup.containerIdentifier) else {
            throw CloudBackupError.notSignedIn
        }
        let root = container
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("StudyReel", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Media", isDirectory: true), withIntermediateDirectories: true)
        return root
    }

    static func write(_ snapshot: BackupSnapshot) throws {
        let root = try rootURL()
        let media = root.appendingPathComponent("Media", isDirectory: true)

        // サムネイルと動画は、まだないものか大きさが変わったものだけ送る
        for name in snapshot.mediaFileNames {
            let source = MediaStore.url(for: name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = media.appendingPathComponent(name)
            if fileSize(destination) == fileSize(source) { continue }
            try coordinatedCopy(from: source, to: destination)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try coordinatedWrite(data, to: root.appendingPathComponent(backupFileName))
    }

    static func read() throws -> BackupSnapshot {
        let root = try rootURL()
        let url = root.appendingPathComponent(backupFileName)
        guard let data = try coordinatedRead(url) else { throw CloudBackupError.noBackup }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(BackupSnapshot.self, from: data) else { throw CloudBackupError.noBackup }

        // 端末にないサムネイルと動画を iCloud から戻す。読み込みの協調でダウンロードも待つ
        let media = root.appendingPathComponent("Media", isDirectory: true)
        for name in snapshot.mediaFileNames {
            let local = MediaStore.url(for: name)
            if FileManager.default.fileExists(atPath: local.path) { continue }
            try? coordinatedCopy(from: media.appendingPathComponent(name), to: local, readingCloud: true)
        }
        return snapshot
    }

    private static func fileSize(_ url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
    }

    private static func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
            do {
                try data.write(to: target, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if coordinationError != nil || writeError != nil { throw CloudBackupError.failed }
    }

    private static func coordinatedRead(_ url: URL) throws -> Data? {
        var coordinationError: NSError?
        var data: Data?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { target in
            data = try? Data(contentsOf: target)
        }
        if coordinationError != nil { throw CloudBackupError.noBackup }
        return data
    }

    // readingCloud が true のときは iCloud 側を読み、false のときは iCloud 側へ書く
    private static func coordinatedCopy(from source: URL, to destination: URL, readingCloud: Bool = false) throws {
        var coordinationError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator()
        let copy: (URL, URL) -> Void = { from, to in
            do {
                if FileManager.default.fileExists(atPath: to.path) {
                    try FileManager.default.removeItem(at: to)
                }
                try FileManager.default.copyItem(at: from, to: to)
            } catch {
                copyError = error
            }
        }

        if readingCloud {
            coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationError) { cloud in
                copy(cloud, destination)
            }
        } else {
            coordinator.coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { cloud in
                copy(source, cloud)
            }
        }
        if coordinationError != nil || copyError != nil { throw CloudBackupError.failed }
    }
}
