import SwiftData
import SwiftUI

// 教材を足す画面。定番の一覧から選ぶか、バーコードや表紙を読み取るか、名前を打つ
struct MaterialAddView: View {
    var onAdd: (StudyMaterial) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var subjectManager = SubjectManager()

    @State private var query = ""
    @State private var name = ""
    @State private var subject = ""
    @State private var author: String?
    @State private var isbn: String?
    @State private var cover: UIImage?
    @State private var showsForm = false

    @State private var showScanner = false
    @State private var showCoverCamera = false
    @State private var isLooking = false
    @State private var textCandidates: [String] = []
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Group {
                if showsForm {
                    form
                } else {
                    catalogList
                }
            }
            .background(ReelTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("教材を追加"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showsForm ? L10n.string("戻る") : L10n.string("閉じる")) {
                        if showsForm {
                            showsForm = false
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(ReelTheme.ink)
                }
                if showsForm {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.string("追加")) { add() }
                            .font(ReelTheme.sans(15, weight: .semibold))
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                scannerSheet
            }
            .fullScreenCover(isPresented: $showCoverCamera) {
                CoverCameraView { image in
                    showCoverCamera = false
                    if let image {
                        readCover(image)
                    }
                }
                .ignoresSafeArea()
            }
            .alert(message ?? "", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button(L10n.string("OK"), role: .cancel) {}
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    // MARK: - 一覧から選ぶ

    private var catalogList: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    scanButton(L10n.string("バーコード"), systemImage: "barcode.viewfinder") {
                        if ISBNScannerView.isAvailable {
                            showScanner = true
                        } else {
                            message = L10n.string("この端末ではバーコードを読み取れません。")
                        }
                    }
                    scanButton(L10n.string("表紙を撮る"), systemImage: "camera") {
                        if CoverCameraView.isAvailable {
                            showCoverCamera = true
                        }
                    }
                    scanButton(L10n.string("名前を入力"), systemImage: "character.cursor.ibeam") {
                        fill(name: query, subject: "")
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
            } footer: {
                if isLooking {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(L10n.string("調べています"))
                    }
                }
            }

            let results = MaterialCatalog.search(query)
            ForEach(MaterialCatalog.groups, id: \.self) { group in
                let items = results.filter { $0.group == group }
                if !items.isEmpty {
                    Section(L10n.string(group)) {
                        ForEach(items) { item in
                            Button {
                                fill(name: item.name, subject: item.subject)
                            } label: {
                                HStack {
                                    Text(item.name)
                                        .font(ReelTheme.sans(15))
                                        .foregroundColor(ReelTheme.ink)
                                    Spacer()
                                    Text(L10n.string(item.subject))
                                        .font(ReelTheme.sans(12))
                                        .foregroundColor(ReelTheme.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !query.isEmpty && results.isEmpty {
                Button {
                    fill(name: query, subject: "")
                } label: {
                    Label(L10n.format("「%@」で追加", query), systemImage: "plus")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.string("教材名で探す"))
    }

    private func scanButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .light))
                Text(title)
                    .font(ReelTheme.sans(11))
            }
            .foregroundColor(ReelTheme.accentDeep)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ReelTheme.card))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 中身を確かめて追加

    private var form: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    Group {
                        if let cover {
                            Image(uiImage: cover)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                ReelTheme.accentSoft
                                Image(systemName: "book.closed")
                                    .foregroundColor(ReelTheme.accentDeep)
                            }
                        }
                    }
                    .frame(width: 64, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        TextField(L10n.string("教材名"), text: $name, axis: .vertical)
                            .font(ReelTheme.serif(18))
                        if let author {
                            Text(author)
                                .font(ReelTheme.sans(12))
                                .foregroundColor(ReelTheme.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !textCandidates.isEmpty {
                Section {
                    ForEach(textCandidates, id: \.self) { candidate in
                        Button {
                            name = candidate
                        } label: {
                            HStack {
                                Text(candidate)
                                    .foregroundColor(ReelTheme.ink)
                                Spacer()
                                if candidate == name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } header: {
                    Text(L10n.string("表紙から読み取った文字"))
                } footer: {
                    Text(L10n.string("書名をタップしてください。読み取りは端末の中だけで行います。"))
                }
            }

            Section(L10n.string("教科")) {
                Picker(L10n.string("教科"), selection: $subject) {
                    ForEach(subjectOptions, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var subjectOptions: [String] {
        var options = subjectManager.subjects
        if !subject.isEmpty && !options.contains(subject) {
            options.append(subject)
        }
        return options
    }

    private var scannerSheet: some View {
        ZStack(alignment: .bottom) {
            ISBNScannerView { code in
                showScanner = false
                lookUp(isbn: code)
            }
            .ignoresSafeArea()

            Text(L10n.string("本の裏のバーコード（978で始まる方）を写してください"))
                .font(ReelTheme.sans(13))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(.bottom, 40)
        }
    }

    // MARK: - 動き

    private func fill(name: String, subject: String) {
        self.name = name
        self.subject = subject.isEmpty ? (subjectManager.subjects.first ?? "") : L10n.string(subject)
        author = nil
        isbn = nil
        cover = nil
        textCandidates = []
        showsForm = true
    }

    private func lookUp(isbn code: String) {
        isLooking = true
        Task {
            let info = await BookLookup.lookup(isbn: code)
            isLooking = false
            if let info {
                fill(name: info.title, subject: "")
                author = info.author
                isbn = info.isbn
                cover = info.cover
            } else {
                fill(name: "", subject: "")
                isbn = code
                message = L10n.string("本が見つかりませんでした。名前を入力してください。")
            }
        }
    }

    private func readCover(_ image: UIImage) {
        isLooking = true
        Task {
            let lines = await CoverTextReader.candidates(in: image)
            isLooking = false
            fill(name: lines.first ?? "", subject: "")
            cover = image
            textCandidates = lines
        }
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        subjectManager.add(subject)
        let material = StudyMaterial(
            name: trimmed,
            subject: subject,
            isbn: isbn,
            author: author,
            coverFileName: cover.flatMap { MediaStore.storeImage($0.preparedForCover()) }
        )
        modelContext.insert(material)
        CloudBackup.markChanged()
        onAdd(material)
        dismiss()
    }
}

private extension UIImage {
    // 表紙は小さくして保存する（長い辺 600px）
    func preparedForCover() -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > 600 else { return self }
        let scale = 600 / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
