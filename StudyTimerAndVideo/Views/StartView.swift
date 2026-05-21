import SwiftUI
import SwiftData
import UIKit
import WidgetKit

// MARK: - タイトル画面
struct StartView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var goals: [DailyGoal]
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    
    @State private var showTimerView = false
    @State private var showStatsView = false
    @State private var showGoalSetting = false
    @State private var showCalendar = false
    @State private var showSettings = false
    @State private var showPaywall = false
    
    // タイマー設定値(時・分・秒)
    @State private var hours = 0
    @State private var minutes = 25
    @State private var seconds = 0

    @State private var selectedMode: Mode = .timer
    
    @StateObject var subjectManager = SubjectManager()
    @StateObject var permissionManager = PermissionManager()
    @StateObject private var draftStore = CurrentSessionDraftStore()
    
    @State private var showPermissionAlert = false
    @State private var sessionBootstrap: SessionBootstrap?
    
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
                AppPalette.homeGradient(for: colorScheme)
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
                                        .foregroundColor(titleColor)
                                    
                                    modePicker
                                    
                                    if selectedMode == .timer {
                                        timerPicker
                                    }
                                    
                                    startButton
                                    proButton
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
                                    .foregroundColor(titleColor)
                                
                                modePicker
                                
                                if selectedMode == .timer {
                                    timerPicker
                                }
                                
                                startButton

                                proButton
                                
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
                Group {
                    if let sessionBootstrap {
                        ContentView(
                            subjectManager: subjectManager,
                            totalSeconds: sessionBootstrap.totalSeconds,
                            onFinish: {
                                showTimerView = false
                                self.sessionBootstrap = nil
                            },
                            mode: sessionBootstrap.mode,
                            bootstrap: sessionBootstrap
                        )
                    } else {
                        EmptyView()
                    }
                }
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert(isPresented: $showPermissionAlert) {
                Alert(
                    title: Text(L10n.string("権限が必要です")),
                    message: Text(L10n.string("カメラと写真へのアクセスを許可してください。")),
                    primaryButton: .default(Text(L10n.string("設定を開く")), action: {
                        permissionManager.openSettings()
                    }),
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                permissionManager.checkPermissions()
                consumePendingSessionDraftIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                permissionManager.checkPermissions()
                consumePendingSessionDraftIfNeeded()
            }
            .onOpenURL { url in
                handleIncomingURL(url)
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
                    Text(L10n.string("今日の目標"))
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
            Button(L10n.string("タイマー")) { selectedMode = .timer }
                .padding()
                .background(AppPalette.controlFill(for: colorScheme, selected: selectedMode == .timer))
                .foregroundColor(AppPalette.controlText(for: colorScheme, selected: selectedMode == .timer))
                .cornerRadius(8)
            
            Button(L10n.string("ストップウォッチ")) { selectedMode = .stopwatch}
                .padding()
                .background(AppPalette.controlFill(for: colorScheme, selected: selectedMode == .stopwatch))
                .foregroundColor(AppPalette.controlText(for: colorScheme, selected: selectedMode == .stopwatch))
                .cornerRadius(8)
        }
    }
    
    var timerPicker: some View {
        HStack {
            Picker(L10n.string("時間"), selection: $hours) {
                ForEach(0..<13) { value in
                    Text(L10n.format("%d時間", value)).tag(value)
                }
            }
            .frame(width: 80)
            .clipped()
                
            Picker(L10n.string("分"), selection: $minutes) {
                ForEach(0..<60) { value in
                    Text(L10n.format("%d分", value)).tag(value)
                }
            }
            .frame(width: 80)
            .clipped()
            
            Picker(L10n.string("秒"), selection: $seconds) {
                ForEach(0..<60) { value in
                    Text(L10n.format("%d秒", value)).tag(value)
                }
            }
            .frame(width: 80)
            .clipped()
        }
        .pickerStyle(WheelPickerStyle())
        .foregroundColor(.white)
        .frame(height: 70)
        .background(AppPalette.controlFill(for: colorScheme).opacity(0.9))
        .cornerRadius(12)
    }
    
    var startButton: some View {
        Button(action: {
            Task {
                if permissionManager.hasRequiredPermissions {
                    startSession(recordTimelapse: true)
                    return
                }

                await permissionManager.requestRequiredPermissionsIfNeeded()

                if permissionManager.hasRequiredPermissions {
                    startSession(recordTimelapse: true)
                } else if permissionManager.needsSettingsRedirect {
                    showPermissionAlert = true
                } else {
                    startSession(recordTimelapse: false)
                }
            }
        }) {
            Text(L10n.string("スタート"))
                .font(.title2)
                .padding()
                .frame(width: 200)
                .background(AppPalette.cardFillStrong(for: colorScheme))
                .foregroundColor(colorScheme == .dark ? .white : .blue)
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
                Text(L10n.string("統計"))
                    .font(.caption)
            }
            .frame(width: 100, height: 80)
            .background(AppPalette.cardFillStrong(for: colorScheme))
            .foregroundColor(colorScheme == .dark ? .white : .purple)
            .cornerRadius(12)
        }
    }

    var proButton: some View {
        Button(action: {
            showPaywall = true
        }) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("StudyReel Pro"))
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(L10n.string("詳細な学習分析を見る"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: 320)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
        }
    }
    
    var calendarButton: some View {
        Button(action: {
            showCalendar = true
        }) {
            VStack {
                Image(systemName: "calendar")
                    .font(.title)
                Text(L10n.string("カレンダー"))
                    .font(.caption)
            }
            .frame(width: 100, height: 80)
            .background(AppPalette.cardFillStrong(for: colorScheme))
            .foregroundColor(colorScheme == .dark ? .white : .orange)
            .cornerRadius(12)
        }
    }

    private var titleColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    private func startSession(recordTimelapse: Bool) {
        sessionBootstrap = SessionBootstrap(
            totalSeconds: hours * 3600 + minutes * 60 + seconds,
            mode: selectedMode,
            startedAt: nil,
            autoStart: false,
            initialRecordingEnabled: recordTimelapse,
            source: .app
        )
        showTimerView = true
    }

    private func consumePendingSessionDraftIfNeeded() {
        guard !showTimerView, let draft = draftStore.consumePendingDraft() else { return }

        let canRecordTimelapse = permissionManager.cameraPermissionGranted && permissionManager.photoLibraryPermissionGranted
        sessionBootstrap = SessionBootstrap(
            totalSeconds: draft.plannedDurationSeconds,
            mode: draft.resolvedMode,
            startedAt: draft.startedAt,
            autoStart: true,
            initialRecordingEnabled: draft.shouldRecordTimelapse && canRecordTimelapse,
            source: draft.source
        )
        showTimerView = true
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "studyreel" else { return }

        if url.host == "start" {
            consumePendingSessionDraftIfNeeded()
            if showTimerView { return }

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let modeValue = components?.queryItems?.first(where: { $0.name == "mode" })?.value ?? "timer"
            let minutesValue = Int(components?.queryItems?.first(where: { $0.name == "minutes" })?.value ?? "")
            let shouldRecord = (components?.queryItems?.first(where: { $0.name == "record" })?.value ?? "1") != "0"

            let mode: Mode = modeValue == "stopwatch" ? .stopwatch : .timer
            let totalSeconds = max(0, (minutesValue ?? 25) * 60)
            syncWidgetTimerState(mode: mode, totalSeconds: totalSeconds)

            sessionBootstrap = SessionBootstrap(
                totalSeconds: mode == .timer ? totalSeconds : 0,
                mode: mode,
                startedAt: Date(),
                autoStart: true,
                initialRecordingEnabled: shouldRecord,
                source: .widget
            )
            showTimerView = true
        } else if url.host == "paywall" {
            showPaywall = true
        }
    }

    private func syncWidgetTimerState(mode: Mode, totalSeconds: Int) {
        let userDefaults = UserDefaults(suiteName: CurrentSessionDraftStore.appGroupKey) ?? .standard
        if mode == .timer, totalSeconds > 0 {
            let endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
            userDefaults.set(endDate.timeIntervalSince1970, forKey: "pomodoro_timer_end_timestamp")
        } else {
            userDefaults.removeObject(forKey: "pomodoro_timer_end_timestamp")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
