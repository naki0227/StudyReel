import SwiftUI
import SwiftData

//MARK: - 学習統計画面
struct StudyStatsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // SwiftData Query
    // SwiftData Query
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @Query private var tags: [Tag]
    
    @ObservedObject var subjectManager: SubjectManager
    
    @State private var showTrend = false
    @State private var showManualAdd = false
    @State private var selectedTag: Tag?
    
    var filteredSessions: [StudySession] {
        if let tag = selectedTag {
            return sessions.filter { $0.tags?.contains(tag) ?? false }
        } else {
            return sessions
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if let tag = selectedTag {
                    Section(header: Text("フィルタ: \(tag.name)")) {
                        Button("フィルタ解除") {
                            selectedTag = nil
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("学習履歴")) {
                    if filteredSessions.isEmpty {
                        Text("まだ記録がありません")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(filteredSessions) { session in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.subject)
                                        .font(.headline)
                                    Text(formatDate(session.date))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    if let tags = session.tags, !tags.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack {
                                                ForEach(tags) { tag in
                                                    Text(tag.name)
                                                        .font(.caption2)
                                                        .padding(4)
                                                        .background(tag.color.opacity(0.2))
                                                        .foregroundColor(tag.color)
                                                        .cornerRadius(4)
                                                }
                                            }
                                        }
                                    }
                                }
                                Spacer()
                                Text(formatTime(session.duration))
                                    .font(.body)
                            }
                        }
                        .onDelete(perform: deleteSession)
                    }
                }
            }
            .navigationTitle("学習統計")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Menu {
                            Button("すべて", action: { selectedTag = nil })
                            ForEach(tags) { tag in
                                Button(tag.name) {
                                    selectedTag = tag
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(selectedTag != nil ? .blue : .primary)
                        }
                        
                        Button(action: { showManualAdd = true }) {
                            Image(systemName: "plus")
                        }
                        Button(action: { showTrend = true }) {
                            Image(systemName: "chart.bar.xaxis")
                        }
                    }
                }
            }
            .sheet(isPresented: $showTrend) {
                StudyStatsTrendView(sessions: filteredSessions, subjectManager: subjectManager)
            }
            .sheet(isPresented: $showManualAdd) {
                ManualAddView(subjectManager: subjectManager)
            }
        }
    }
    
    private func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            let session = filteredSessions[index]
            modelContext.delete(session)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
