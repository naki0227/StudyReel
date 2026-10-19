import SwiftData
import SwiftUI

// 記録に使う教材を選ぶ。最後に選んだ教材は次の記録でも最初から選ばれる
enum MaterialSelection {
    static let lastKey = "last_material_id"

    static var lastID: UUID? {
        get { UserDefaults.standard.string(forKey: lastKey).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: lastKey) }
    }
}

struct MaterialPickerSheet: View {
    @Binding var selection: UUID?

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<StudyMaterial> { $0.finishedAt == nil }, sort: \StudyMaterial.createdAt, order: .reverse)
    private var materials: [StudyMaterial]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    choose(nil)
                } label: {
                    row(title: L10n.string("教材なし"), subtitle: nil, material: nil, isOn: selection == nil)
                }

                ForEach(materials) { material in
                    Button {
                        choose(material.id)
                    } label: {
                        row(title: material.name, subtitle: material.subject, material: material, isOn: selection == material.id)
                    }
                }

                Button {
                    showAdd = true
                } label: {
                    Label(L10n.string("教材を追加"), systemImage: "plus")
                        .font(ReelTheme.sans(15))
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ReelTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("教材"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("閉じる")) { dismiss() }
                        .foregroundColor(ReelTheme.ink)
                }
            }
            .sheet(isPresented: $showAdd) {
                MaterialAddView { material in
                    choose(material.id)
                }
            }
        }
        .tint(ReelTheme.accentDeep)
    }

    private func row(title: String, subtitle: String?, material: StudyMaterial?, isOn: Bool) -> some View {
        HStack(spacing: 12) {
            if material != nil {
                MaterialCover(material: material)
                    .frame(width: 32, height: 44)
            } else {
                Image(systemName: "minus.circle")
                    .foregroundColor(ReelTheme.secondary)
                    .frame(width: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ReelTheme.sans(15))
                    .foregroundColor(ReelTheme.ink)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                }
            }
            Spacer()
            if isOn {
                Image(systemName: "checkmark")
                    .foregroundColor(ReelTheme.accentDeep)
            }
        }
    }

    private func choose(_ id: UUID?) {
        selection = id
        MaterialSelection.lastID = id
        dismiss()
    }
}

// 選んでいる教材を1行で見せて、タップで選び直す
struct MaterialChooserRow: View {
    @Binding var selection: UUID?
    @Query private var materials: [StudyMaterial]
    @State private var showPicker = false

    private var material: StudyMaterial? {
        selection.flatMap { id in materials.first { $0.id == id } }
    }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 12) {
                MaterialCover(material: material)
                    .frame(width: 30, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("教材"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                    Text(material?.name ?? L10n.string("選ぶ（なくてもOK）"))
                        .font(ReelTheme.sans(14))
                        .foregroundColor(material == nil ? ReelTheme.secondary : ReelTheme.ink)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ReelTheme.line)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous).fill(ReelTheme.card))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            MaterialPickerSheet(selection: $selection)
        }
        .onAppear {
            // やり終えた・消した教材を選んだままにしない
            if let selection, !materials.contains(where: { $0.id == selection && !$0.isFinished }) {
                self.selection = nil
            }
        }
    }
}
