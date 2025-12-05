import SwiftUI

//MARK: - 教科編集画面
struct SubjectEditView: View {
    @ObservedObject var subjectManager: SubjectManager
    @State private var newSubject: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("新しい教科", text: $newSubject)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("追加") {
                        subjectManager.add(newSubject)
                        newSubject = ""
                    }
                }
                .padding()
                
                List {
                    ForEach(subjectManager.subjects, id: \.self) { subject in
                        Text(subject)
                    }
                    .onDelete(perform:subjectManager.delete)
                }
            }
            .navigationTitle("教科の編集")
        }
    }
}
