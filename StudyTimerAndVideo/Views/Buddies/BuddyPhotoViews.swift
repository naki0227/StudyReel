import AVKit
import SwiftData
import SwiftUI

// 通報する相手（と写真）
struct BuddyReportTarget: Identifiable {
    let id = UUID()
    let group: BuddyCloud.Group
    let userRecordName: String
    let nickname: String
    let code: Int
    let photo: BuddyCloud.Photo?
    let photoData: Data?
}

// 通報。理由を選んで送ると、開発者に届く（相手には分からない）
struct BuddyReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloud = BuddyCloud.shared
    private let target: BuddyReportTarget
    @State private var reason: BuddyReportReason
    @State private var note = ""
    @State private var sending = false
    @State private var sent = false

    init(target: BuddyReportTarget) {
        self.target = target
        _reason = State(initialValue: target.photo == nil ? .name : .photo)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(target.nickname) \(BuddyProfile.displayCode(target.code))")
                        .font(ReelTheme.sans(15, weight: .medium))
                    if let data = target.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                Section(L10n.string("理由")) {
                    Picker(L10n.string("理由"), selection: $reason) {
                        ForEach(BuddyReportReason.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    TextField(L10n.string("くわしく（なくてもかまいません）"), text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Text(L10n.string("開発者に、相手の名前と番号、アプリの利用者番号、グループ名、日時が届きます。写真の通報では写真も届きます。開発者が確かめて、よくないものは写真の機能から締め出すなどの対応をします。相手には、だれが通報したかは分かりません。"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                    if target.photo?.isClip == true {
                        Text(L10n.string("動画の通報では、その10秒の動画も届きます。"))
                            .font(ReelTheme.sans(11))
                            .foregroundColor(ReelTheme.secondary)
                    }
                    Text(L10n.string("急ぎの危険があるときは、警察に相談してください。"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }
            }
            .navigationTitle(L10n.string("通報"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("送る")) { send() }
                        .disabled(sending)
                }
            }
            .alert(L10n.string("通報を受け付けました"), isPresented: $sent) {
                Button(L10n.string("OK")) { dismiss() }
            } message: {
                Text(L10n.string("見たくないときは、その人をブロックできます。"))
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private func send() {
        sending = true
        Task {
            let ok = await cloud.report(
                userRecordName: target.userRecordName, nickname: target.nickname, code: target.code,
                group: target.group, reason: reason, note: note, photo: target.photo, photoData: target.photoData
            )
            sending = false
            if ok { sent = true }
        }
    }
}

// 仲間の写真を1枚出す。取ってくるまでは灰色、出せないもの（センシティブ）は「表示できません」
struct BuddyPhotoImage: View {
    private let photo: BuddyCloud.Photo
    private let group: BuddyCloud.Group
    private let onLoad: ((Data?) -> Void)?
    @State private var data: Data?
    @State private var failed = false

    init(photo: BuddyCloud.Photo, group: BuddyCloud.Group, onLoad: ((Data?) -> Void)? = nil) {
        self.photo = photo
        self.group = group
        self.onLoad = onLoad
    }

    var body: some View {
        ZStack {
            Rectangle().fill(ReelTheme.line.opacity(0.5))
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                Text(L10n.string("表示できません"))
                    .font(ReelTheme.sans(10))
                    .foregroundColor(ReelTheme.secondary)
            } else {
                ProgressView()
            }
            if photo.isClip {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white, .black.opacity(0.35))
                    .accessibilityLabel(L10n.string("10秒の動画"))
            }
        }
        .clipped()
        .task(id: photo.id) {
            let loaded = await BuddyPhotos.data(for: photo, in: group)
            data = loaded
            failed = loaded == nil
            onLoad?(loaded)
        }
    }
}

// 写真を大きく見る。通報、（オーナーか自分なら）削除
struct BuddyPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloud = BuddyCloud.shared
    private let photo: BuddyCloud.Photo
    private let group: BuddyCloud.Group
    private let onReport: (Data?) -> Void
    @State private var data: Data?
    @State private var clipURL: URL?

    init(photo: BuddyCloud.Photo, group: BuddyCloud.Group, onReport: @escaping (Data?) -> Void) {
        self.photo = photo
        self.group = group
        self.onReport = onReport
    }

    private var isMine: Bool { photo.from == cloud.myRecordName }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ZStack {
                    BuddyPhotoImage(photo: photo, group: group) { data = $0 }
                    if let clipURL {
                        BuddyClipPlayer(url: clipURL)
                    }
                }
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .task(id: photo.id) {
                    clipURL = await BuddyPhotos.clipURL(for: photo, in: group)
                }
                HStack {
                    Text("\(photo.nickname) \(BuddyProfile.displayCode(photo.code))")
                        .font(ReelTheme.sans(14, weight: .medium))
                        .foregroundColor(ReelTheme.ink)
                    Spacer()
                    Text(L10n.format("あと%@で消えます", buddyDuration(Int(photo.expiresAt.timeIntervalSinceNow))))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }
                HStack(spacing: 20) {
                    if !isMine {
                        Button {
                            onReport(data)
                        } label: {
                            Label(L10n.string("通報"), systemImage: "exclamationmark.bubble")
                        }
                        Button(role: .destructive) {
                            if let member = group.members.first(where: { $0.userRecordName == photo.from }) {
                                cloud.block(member)
                            }
                            dismiss()
                        } label: {
                            Label(L10n.string("ブロック"), systemImage: "hand.raised")
                        }
                    }
                    if group.isOwner || isMine {
                        Button(role: .destructive) {
                            Task {
                                await cloud.deletePhoto(photo, in: group)
                                dismiss()
                            }
                        } label: {
                            Label(L10n.string("削除"), systemImage: "trash")
                        }
                    }
                }
                .font(ReelTheme.sans(13))
                Spacer()
            }
            .padding(20)
            .background(GridPaperBackground().ignoresSafeArea())
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

// 保存したタイムラプスから1コマを選んで、顔にモザイクをかけて仲間に出す
struct BuddyPhotoComposer: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloud = BuddyCloud.shared
    @Query(filter: #Predicate<StudySession> { $0.videoFileName != nil }, sort: \StudySession.date, order: .reverse)
    private var sessions: [StudySession]

    private let group: BuddyCloud.Group
    @State private var selected: StudySession?
    @State private var position = 0.5
    @State private var image: CGImage?
    @State private var data: Data?
    @State private var sensitive = false
    @State private var working = false
    @State private var sending = false
    // 写真1枚か、そこから10秒の動画か
    @State private var asClip = false
    @State private var clip: MosaickedClip?
    @State private var makingClip = false

    init(group: BuddyCloud.Group) {
        self.group = group
    }

    // 最近1週間の、動画が残っている記録
    private var candidates: [StudySession] {
        let since = Date().addingTimeInterval(-7 * 24 * 3600)
        return sessions.filter { $0.date >= since && MediaStore.videoURL(named: $0.videoFileName) != nil }.prefix(20).map { $0 }
    }

    private var viewers: Int {
        group.members.filter { $0.userRecordName != cloud.myRecordName }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if candidates.isEmpty {
                        Text(L10n.string("この1週間に保存したタイムラプスがありません。アプリの中に動画を残している記録から選べます。"))
                            .font(ReelTheme.sans(13))
                            .foregroundColor(ReelTheme.secondary)
                            .padding(.vertical, 30)
                    } else {
                        sessionPicker
                        if selected != nil { framePicker }
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(GridPaperBackground().ignoresSafeArea())
            .navigationTitle(L10n.string("今日の1コマ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("キャンセル")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
            }
        }
        .tint(ReelTheme.accentDeep)
        .onChange(of: "\(selected?.id.uuidString ?? "")-\(position)-\(asClip)") {
            // 選び直したら、作った動画は使わない
            if let clip { try? FileManager.default.removeItem(at: clip.url) }
            clip = nil
        }
        .task(id: "\(selected?.id.uuidString ?? "")-\(position)") {
            // スライダーを動かしている間は待ち、止まってから1コマ作る
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await makeFrame()
        }
    }

    private var sessionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("どの記録から選びますか"))
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(candidates) { session in
                        Button {
                            selected = session
                            position = 0.5
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                ZStack {
                                    Rectangle().fill(ReelTheme.line.opacity(0.5))
                                    if let thumb = MediaStore.thumbnail(named: session.thumbnailFileName) {
                                        Image(uiImage: thumb).resizable().scaledToFill()
                                    }
                                }
                                .frame(width: 110, height: 82)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(selected?.id == session.id ? ReelTheme.accentDeep : .clear, lineWidth: 2))
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(ReelTheme.sans(10))
                                    .foregroundColor(ReelTheme.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var framePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Rectangle().fill(ReelTheme.line.opacity(0.5))
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                }
                if working { ProgressView() }
            }
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Slider(value: $position, in: 0...1)
            Text(L10n.string("スライダーで、出してもいい瞬間を選んでください。顔にはモザイクがかかります。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
            Picker(L10n.string("出し方"), selection: $asClip) {
                Text(L10n.string("写真")).tag(false)
                Text(L10n.string("10秒の動画")).tag(true)
            }
            .pickerStyle(.segmented)
            if asClip {
                clipSection
            }
            if sensitive {
                Text(L10n.string("この1コマは送れません。ほかの瞬間を選んでください。"))
                    .font(ReelTheme.sans(12, weight: .medium))
                    .foregroundColor(.red)
            }
            Text(L10n.format("この写真は%d人に見えます。24時間で消えます。", viewers))
                .font(ReelTheme.sans(12))
                .foregroundColor(ReelTheme.ink)
            Button {
                send()
            } label: {
                Text(L10n.string("仲間に出す"))
                    .font(ReelTheme.sans(15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Capsule().fill(canSend ? ReelTheme.accentDeep : ReelTheme.secondary.opacity(0.4)))
            }
            .disabled(!canSend)
            .accessibilityIdentifier("buddies.photo.send")
        }
    }

    private var canSend: Bool { data != nil && !sensitive && !working && !sending && (!asClip || clip != nil) }

    // 動画は、作ったものを本人が見てからでないと送れない
    @ViewBuilder
    private var clipSection: some View {
        if let clip {
            BuddyClipPlayer(url: clip.url)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(L10n.string("送る前に、顔が隠れているか最後まで見て確かめてください。"))
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.secondary)
        } else {
            Button {
                makeClip()
            } label: {
                HStack(spacing: 8) {
                    if makingClip { ProgressView() }
                    Text(L10n.string(makingClip ? "モザイクをかけています…" : "この瞬間から10秒の動画を作る"))
                }
                .font(ReelTheme.sans(14, weight: .medium))
                .foregroundColor(ReelTheme.accentDeep)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(ReelTheme.accentSoft))
            }
            .disabled(makingClip || working)
        }
    }

    private func makeClip() {
        guard let session = selected, let url = MediaStore.videoURL(named: session.videoFileName) else { return }
        makingClip = true
        Task {
            let made = await BuddyClips.make(from: url, at: position)
            var flagged = false
            if let made { flagged = await BuddyClips.isSensitive(made) }
            makingClip = false
            if flagged {
                sensitive = true
                if let made { try? FileManager.default.removeItem(at: made.url) }
                return
            }
            clip = made
            if let made { data = BuddyPhotos.jpeg(made.thumbnail) }
        }
    }

    private func makeFrame() async {
        guard let session = selected, let url = MediaStore.videoURL(named: session.videoFileName) else { return }
        working = true
        defer { working = false }
        guard let frame = await BuddyPhotos.frame(from: url, at: position) else {
            image = nil
            data = nil
            return
        }
        let hidden = await Task.detached(priority: .userInitiated) { BuddyPhotos.mosaicked(frame) }.value
        guard let hidden else { return }
        // モザイクの前と後の両方を見る
        let flagged = await BuddyPhotos.isSensitive(frame)
        let flaggedAfter = flagged ? true : await BuddyPhotos.isSensitive(hidden)
        image = hidden
        sensitive = flaggedAfter
        data = flaggedAfter ? nil : BuddyPhotos.jpeg(hidden)
    }

    private func send() {
        guard let data else { return }
        sending = true
        Task {
            let ok = await cloud.sendPhoto(data, clip: asClip ? clip : nil, to: group)
            sending = false
            if ok {
                if let clip { try? FileManager.default.removeItem(at: clip.url) }
                dismiss()
            }
        }
    }
}

// 仲間の10秒の動画。音はなく、くり返し流す
struct BuddyClipPlayer: View {
    let url: URL
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        VideoPlayer(player: player)
            .disabled(true)
            .onAppear {
                let queue = AVQueuePlayer()
                queue.isMuted = true
                looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
                player = queue
                queue.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
                looper = nil
            }
    }
}
