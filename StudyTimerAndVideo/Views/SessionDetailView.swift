import SwiftUI
import SwiftData
import AVKit

// 記録の詳細。アプリ内に動画があれば大きく再生する
struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: StudySession
    @ObservedObject var subjectManager: SubjectManager

    @State private var player: AVPlayer?
    @State private var isEditing = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                media
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(session.displayTitle)
                        .font(ReelTheme.serif(24))
                        .foregroundColor(ReelTheme.ink)

                    Text("\(formattedDate(session.date))  \(formattedDuration(session.duration))")
                        .font(ReelTheme.sans(13))
                        .foregroundColor(ReelTheme.secondary)
                }

                let tagNames = ([session.subject] + (session.tags ?? []).map(\.name))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tagNames, id: \.self) { name in
                            Text("#\(name)")
                                .font(ReelTheme.sans(12))
                                .foregroundColor(ReelTheme.accentDeep)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(ReelTheme.accentSoft))
                        }
                    }
                }

                if let memo = session.memo, !memo.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("メモ"))
                            .font(ReelTheme.sans(12))
                            .foregroundColor(ReelTheme.secondary)
                        Text(memo)
                            .font(ReelTheme.sans(14))
                            .foregroundColor(ReelTheme.ink)
                            .lineSpacing(4)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(ReelTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.string("編集")) { isEditing = true }
                    .foregroundColor(ReelTheme.accentDeep)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(L10n.string("削除"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(ReelTheme.secondary)
                }
            }
        }
        .tint(ReelTheme.accentDeep)
        .sheet(isPresented: $isEditing) {
            SessionEditView(session: session, subjectManager: subjectManager)
        }
        .alert(L10n.string("この記録を削除しますか？"), isPresented: $showDeleteConfirm) {
            Button(L10n.string("戻る"), role: .cancel) {}
            Button(L10n.string("削除"), role: .destructive) {
                player?.pause()
                MediaStore.delete(session.thumbnailFileName, session.videoFileName)
                modelContext.delete(session)
                dismiss()
            }
        } message: {
            Text(L10n.string("写真アプリに保存した動画は消えません。"))
        }
        .onAppear {
            if player == nil, let url = MediaStore.videoURL(named: session.videoFileName) {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder
    private var media: some View {
        if let player {
            VideoPlayer(player: player)
        } else {
            SessionThumbnail(fileName: session.thumbnailFileName, subject: session.subject)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMdEEE")
        return formatter.string(from: date)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? L10n.format("%d時間%d分", h, m) : L10n.format("%d分", m)
    }
}

// 保存したあとにタイトル・教科・メモを直す
struct SessionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: StudySession
    @ObservedObject var subjectManager: SubjectManager

    @State private var title = ""
    @State private var memo = ""
    @State private var subject = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    TextField(L10n.string("タイトル（例：図書館で数学）"), text: $title)
                        .font(ReelTheme.sans(15))
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))

                    ReelRow(systemImage: "book.closed", title: L10n.string("教科")) {
                        Menu {
                            ForEach(subjectManager.subjects, id: \.self) { item in
                                Button(item) { subject = item }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(subject)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                            .font(ReelTheme.sans(14))
                            .foregroundColor(ReelTheme.secondary)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))

                    TextField(L10n.string("メモ（任意）"), text: $memo, axis: .vertical)
                        .font(ReelTheme.sans(14))
                        .lineLimit(4...10)
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
                }
                .padding(16)
            }
            .background(ReelTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("保存")) {
                        session.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
                        session.memo = trimmedMemo.isEmpty ? nil : trimmedMemo
                        if !subject.isEmpty { session.subject = subject }
                        dismiss()
                    }
                    .font(ReelTheme.sans(15, weight: .semibold))
                    .foregroundColor(ReelTheme.accentDeep)
                }
            }
            .onAppear {
                title = session.title ?? ""
                memo = session.memo ?? ""
                subject = session.subject
            }
        }
    }
}
