import SwiftUI
import SwiftData

// MARK: - タイトル画面
struct StartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [DailyGoal]
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    
    @State private var showTimerView = false
    @State private var showStatsView = false
    @State private var showGoalSetting = false
    @State private var showCalendar = false
    @State private var showSettings = false
    
    // タイマー設定値(時・分・秒)
    @State private var hours = 0
    @State private var minutes = 25
    @State private var seconds = 0

    @State private var selectedMode: Mode = .timer
    
    @StateObject var subjectManager = SubjectManager()
    @StateObject var permissionManager = PermissionManager()
    
    @State private var showPermissionAlert = false
    
    var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    var todayGoal: DailyGoal? {
        goals.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    var todayStudyTime: Int {
        sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
            .map { $0.duration }
            .reduce(0, +)
    }
    
    var progress: Double {
        guard let goal = todayGoal, goal.targetDuration > 0 else { return 0 }
        return Double(todayStudyTime) / Double(goal.targetDuration)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.white)
                        }
                    }
                }
                
                GeometryReader { geometry in
                    let isLandscape = geometry.size.width > geometry.size.height
                    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                    
                    ScrollView {
                        if isLandscape {
                            HStack(alignment: .center, spacing: 40) {
                                Spacer()
                                
                                // Left Column: Info & Stats
                                VStack(spacing: 20) {
                                    goalRing
                                    
                                    HStack(spacing: 20) {
                                        statsButton
                                        calendarButton
                                    }
                                }
                                .frame(width: isIPad ? 300 : geometry.size.width * 0.4)
                                
                                // Right Column: Controls
                                VStack(spacing: 20) {
                                    Text("StudyReel")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    modePicker
                                    
                                    if selectedMode == .timer {
                                        timerPicker
                                    }
                                    
                                    startButton
                                }
                                .frame(width: isIPad ? 400 : geometry.size.width * 0.5)
                                
                                Spacer()
                            }
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                            .padding()
                        } else {
                            // Portrait Layout
                            VStack(spacing: 20) {
                                Spacer()
                                
                                goalRing
                                
                                Text("StudyReel")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                modePicker
                                
                                if selectedMode == .timer {
                                    timerPicker
                                }
                                
                                startButton
                                
                                HStack(spacing: 20) {
                                    statsButton
                                    calendarButton
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .frame(width: isIPad ? 500 : nil) // Limit width on iPad Portrait
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showTimerView) {
                ContentView(
                    subjectManager: subjectManager,
                    totalSeconds: hours * 3600 + minutes * 60 + seconds,
                    onFinish: {showTimerView = false },
                    mode: selectedMode
                )
            }
            .sheet(isPresented: $showStatsView) {
                StudyStatsView(
                    subjectManager: subjectManager
                )
            }
            .sheet(isPresented: $showGoalSetting) {
                GoalSettingView()
            }
            .sheet(isPresented: $showCalendar) {
                CalendarView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert(isPresented: $showPermissionAlert) {
                Alert(
                    title: Text("権限が必要です"),
                    message: Text("カメラと写真へのアクセスを許可してください。"),
                    primaryButton: .default(Text("設定を開く"), action: {
                        permissionManager.openSettings()
                    }),
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                permissionManager.checkPermissions()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Subviews
    
    var goalRing: some View {
        Button(action: { showGoalSetting = true }) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.3)
                    .foregroundColor(.white)
                
                Circle()
                    .trim(from: 0.0, to: min(progress, 1.0))
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: progress)
                
                VStack {
                    Text("今日の目標")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(formatTime(todayStudyTime)) / \(formatTime(todayGoal?.targetDuration ?? 0))")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(Int(progress * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 150, height: 150)
            .padding(.top, 20)
        }
    }
    
    var modePicker: some View {
        HStack {
            Button("タイマー") { selectedMode = .timer }
                .padding()
                .background(selectedMode == .timer ? Color.white : Color.gray.opacity(0.5))
                .foregroundColor(.blue)
                .cornerRadius(8)
            
            Button("ストップウォッチ") { selectedMode = .stopwatch}
                .padding()
                .background(selectedMode == .stopwatch ? Color.white : Color.gray.opacity(0.5))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
    }
    
    var timerPicker: some View {
        HStack {
            Picker("Hours", selection: $hours) {
                ForEach(0..<13) { Text("\($0) 時") }
            }
            .frame(width: 80)
            .clipped()
                
            Picker("Minutes", selection: $minutes) {
                ForEach(0..<60) { Text("\($0) 分") }
            }
            .frame(width: 80)
            .clipped()
            
            Picker("Seconds", selection: $seconds) {
                ForEach(0..<60) { Text("\($0) 秒") }
            }
            .frame(width: 80)
            .clipped()
        }
        .pickerStyle(WheelPickerStyle())
        .foregroundColor(.white)
        .frame(height: 70)
        .cornerRadius(12)
    }
    
    var startButton: some View {
        Button(action: {
            if permissionManager.cameraPermissionGranted && permissionManager.photoLibraryPermissionGranted {
                showTimerView = true
            } else {
                permissionManager.checkPermissions()
                if !permissionManager.cameraPermissionGranted || !permissionManager.photoLibraryPermissionGranted {
                    showPermissionAlert = true
                }
            }
        }) {
            Text("スタート")
                .font(.title2)
                .padding()
                .frame(width: 200)
                .background(Color.white)
                .foregroundColor(.blue)
                .cornerRadius(12)
        }
    }
    
    var statsButton: some View {
        Button(action: {
            showStatsView = true
        }) {
            VStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title)
                Text("統計")
                    .font(.caption)
            }
            .frame(width: 100, height: 80)
            .background(Color.white.opacity(0.9))
            .foregroundColor(.purple)
            .cornerRadius(12)
        }
    }
    
    var calendarButton: some View {
        Button(action: {
            showCalendar = true
        }) {
            VStack {
                Image(systemName: "calendar")
                    .font(.title)
                Text("カレンダー")
                    .font(.caption)
            }
            .frame(width: 100, height: 80)
            .background(Color.white.opacity(0.9))
            .foregroundColor(.orange)
            .cornerRadius(12)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }
}
