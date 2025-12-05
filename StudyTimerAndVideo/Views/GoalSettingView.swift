import SwiftUI
import SwiftData

struct GoalSettingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var goals: [DailyGoal]
    
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    
    var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    var currentGoal: DailyGoal? {
        goals.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("今日の目標時間")) {
                    HStack {
                        Picker("時間", selection: $hours) {
                            ForEach(0..<24) { h in
                                Text("\(h)時間").tag(h)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 100)
                        
                        Picker("分", selection: $minutes) {
                            ForEach(0..<60) { m in
                                Text("\(m)分").tag(m)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 100)
                    }
                }
                
                Button("保存") {
                    saveGoal()
                    dismiss()
                }
            }
            .navigationTitle("目標設定")
            .onAppear {
                if let goal = currentGoal {
                    hours = goal.targetDuration / 3600
                    minutes = (goal.targetDuration % 3600) / 60
                } else {
                    // Default to 1 hour if no goal set
                    hours = 1
                    minutes = 0
                }
            }
        }
    }
    
    private func saveGoal() {
        let totalSeconds = hours * 3600 + minutes * 60
        
        if let goal = currentGoal {
            goal.targetDuration = totalSeconds
        } else {
            let newGoal = DailyGoal(date: today, targetDuration: totalSeconds)
            modelContext.insert(newGoal)
        }
    }
}
