import SwiftUI

//MARK: - 教科編集画面
struct SubjectEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subjectManager: SubjectManager
    @State private var newSubject: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField(L10n.string("新しい教科"), text: $newSubject)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(L10n.string("追加")) {
                        subjectManager.add(newSubject.trimmingCharacters(in: .whitespacesAndNewlines))
                        newSubject = ""
                    }
                    .disabled(newSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                
                List {
                    ForEach(subjectManager.subjects, id: \.self) { subject in
                        Text(subject)
                    }
                    .onDelete(perform:subjectManager.delete)
                }
            }
            .navigationTitle(L10n.string("教科の編集"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("完了")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
