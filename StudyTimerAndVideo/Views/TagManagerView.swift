import SwiftUI
import SwiftData

// タグの編集。色はデザインに合うやわらかい色から選ぶ
struct TagManagerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]

    @State private var newTagName = ""
    @State private var selectedColor = TagManagerView.palette[0]

    static let palette = ["5E8DB8", "7FB3A8", "D9A066", "C98B9B", "9B8EC4", "8E9AA6"]

    private var trimmed: String {
        newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField(L10n.string("タグ名"), text: $newTagName)
                            .font(ReelTheme.sans(15))
                            .onSubmit(addTag)
                        Button(L10n.string("追加"), action: addTag)
                            .font(ReelTheme.sans(14, weight: .medium))
                            .foregroundColor(trimmed.isEmpty ? ReelTheme.secondary : ReelTheme.accentDeep)
                            .disabled(trimmed.isEmpty)
                    }
                    HStack(spacing: 12) {
                        ForEach(Self.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? ReelTheme.accent)
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(Color.white, lineWidth: selectedColor == hex ? 3 : 0))
                                .overlay(Circle().stroke(ReelTheme.line, lineWidth: selectedColor == hex ? 1 : 0).padding(-2))
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(ReelTheme.card)

                Section {
                    ForEach(tags) { tag in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 10, height: 10)
                            Text("#\(tag.name)")
                                .font(ReelTheme.sans(15))
                                .foregroundColor(ReelTheme.ink)
                        }
                        .listRowBackground(ReelTheme.card)
                    }
                    .onDelete(perform: deleteTags)
                } footer: {
                    Text(L10n.string("左にスワイプで削除できます。"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ReelTheme.background.ignoresSafeArea())
            // 見出しは左上に置くと iOS 26 で「…」にまとめられるので、上の真ん中に出す
            .navigationTitle(L10n.string("タグ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("完了")) { dismiss() }
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }
        }
    }

    private func addTag() {
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Tag(name: trimmed, colorHex: selectedColor))
        newTagName = ""
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tags[index])
        }
    }
}
