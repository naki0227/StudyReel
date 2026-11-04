import PencilKit
import PhotosUI
import SwiftUI

// 「0〜9」と「:」の11文字を、指で書くか、写真から作る。動画の時刻がこの字になる（Pro）
struct CustomDigitsView: View {
    var onChange: () -> Void = {}

    @AppStorage(CustomDigits.tintKey) private var tinted = true
    @AppStorage(OverlayDecor.customDigitsKey) private var usesCustomDigits = false
    @State private var editing: GlyphTarget?
    @State private var version = 0
    @State private var showClearConfirm = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CustomDigits.glyphs, id: \.self) { glyph in
                        Button {
                            editing = GlyphTarget(glyph: glyph)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.16, green: 0.19, blue: 0.23))
                                if let image = CustomDigits.image(glyph) {
                                    Image(uiImage: tinted ? image.withTintColor(.white, renderingMode: .alwaysOriginal) : image)
                                        .resizable()
                                        .scaledToFit()
                                        .padding(10)
                                } else {
                                    Text(String(glyph))
                                        .font(.system(size: 28, weight: .light))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                            }
                            .frame(height: 74)
                            .id("\(glyph)-\(version)")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            } footer: {
                Text(L10n.string("マスを押して、その文字を書くか写真を選びます。11文字そろうと使えます。"))
            }

            Section {
                Toggle(L10n.string("時刻の色で塗る"), isOn: $tinted)
                    .onChange(of: tinted) { onChange() }
            } footer: {
                Text(L10n.string("オンにすると、書いた字を「時刻の色」で塗ります。写真の色をそのまま使うときはオフにします。"))
            }

            Section {
                Button(L10n.string("全部消す"), role: .destructive) { showClearConfirm = true }
            }
        }
        .navigationTitle(L10n.string("自分の数字"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { target in
            GlyphEditor(glyph: target.glyph) {
                version += 1
                if CustomDigits.isComplete { usesCustomDigits = true }
                onChange()
            }
        }
        .alert(L10n.string("書いた数字を全部消しますか？"), isPresented: $showClearConfirm) {
            Button(L10n.string("消す"), role: .destructive) {
                CustomDigits.removeAll()
                usesCustomDigits = false
                version += 1
                onChange()
            }
            Button(L10n.string("やめる"), role: .cancel) {}
        }
    }
}

private struct GlyphTarget: Identifiable {
    let glyph: Character
    var id: String { String(glyph) }
}

// 1文字分。指で書くか、写真を選んで写っているものだけ切り抜く
private struct GlyphEditor: View {
    let glyph: Character
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(L10n.format("「%@」を大きく書いてください", String(glyph)))
                    .font(ReelTheme.sans(14))
                    .foregroundColor(ReelTheme.secondary)
                DrawingCanvas(canvas: canvas)
                    .frame(width: 260, height: 300)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ReelTheme.line, lineWidth: 1))
                HStack(spacing: 12) {
                    Button(L10n.string("書き直す")) { canvas.drawing = PKDrawing() }
                        .buttonStyle(.bordered)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(L10n.string("写真から作る"), systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                }
                if isLoadingPhoto {
                    ProgressView()
                }
                Text(L10n.string("写真は、紙に書いた字やシールなど1文字だけが写ったものを選ぶと、背景を消して使います。"))
                    .font(ReelTheme.sans(11))
                    .foregroundColor(ReelTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 20)
            .tint(ReelTheme.accentDeep)
            .navigationTitle(String(glyph))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("保存")) { saveDrawing() }
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                isLoadingPhoto = true
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    let lifted: UIImage? = await Task.detached(priority: .userInitiated) {
                        guard let data, let image = UIImage(data: data) else { return nil }
                        return CustomDigits.liftSubject(from: image)
                    }.value
                    await MainActor.run {
                        isLoadingPhoto = false
                        guard let lifted else { return }
                        CustomDigits.save(lifted, for: glyph)
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveDrawing() {
        let drawing = canvas.drawing
        guard !drawing.bounds.isEmpty else { return }
        let image = drawing.image(from: drawing.bounds.insetBy(dx: -8, dy: -8), scale: 3)
        CustomDigits.save(image, for: glyph)
        onSave()
        dismiss()
    }
}

private struct DrawingCanvas: UIViewRepresentable {
    let canvas: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 14)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
