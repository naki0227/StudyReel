import SwiftUI
import SwiftData

struct TagManagerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]
    
    @State private var newTagName = ""
    @State private var selectedColor = Color.blue
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(L10n.string("新しいタグを追加"))) {
                    HStack {
                        TextField(L10n.string("タグ名"), text: $newTagName)
                        ColorPicker("", selection: $selectedColor)
                            .labelsHidden()
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newTagName.isEmpty)
                    }
                }
                
                Section(header: Text(L10n.string("既存のタグ"))) {
                    ForEach(tags) { tag in
                        HStack {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 12, height: 12)
                            Text(tag.name)
                        }
                    }
                    .onDelete(perform: deleteTags)
                }
            }
            .navigationTitle(L10n.string("タグ管理"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("完了")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addTag() {
        guard !newTagName.isEmpty else { return }
        let colorHex = selectedColor.toHex() ?? "0000FF"
        let newTag = Tag(name: newTagName, colorHex: colorHex)
        modelContext.insert(newTag)
        newTagName = ""
        selectedColor = .blue
    }
    
    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tags[index])
        }
    }
}
