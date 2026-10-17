import SwiftUI

//MARK: - 教科の編集
struct SubjectEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subjectManager: SubjectManager
    @State private var newSubject: String = ""

    private var trimmed: String {
        newSubject.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField(L10n.string("新しい教科"), text: $newSubject)
                            .font(ReelTheme.sans(15))
                            .onSubmit(add)
                        Button(L10n.string("追加"), action: add)
                            .font(ReelTheme.sans(14, weight: .medium))
                            .foregroundColor(trimmed.isEmpty ? ReelTheme.secondary : ReelTheme.accentDeep)
                            .disabled(trimmed.isEmpty)
                    }
                    .listRowBackground(ReelTheme.card)
                }

                Section {
                    ForEach(subjectManager.subjects, id: \.self) { subject in
                        Text(subject)
                            .font(ReelTheme.sans(15))
                            .foregroundColor(ReelTheme.ink)
                            .listRowBackground(ReelTheme.card)
                    }
                    .onDelete(perform: subjectManager.delete)
                } footer: {
                    Text(L10n.string("左にスワイプで削除できます。"))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ReelTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(L10n.string("教科"))
                        .font(ReelTheme.serif(22))
                        .foregroundColor(ReelTheme.ink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("完了")) { dismiss() }
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }
        }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        subjectManager.add(trimmed)
        newSubject = ""
    }
}
