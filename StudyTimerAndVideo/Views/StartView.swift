import SwiftUI
import SwiftData
import UIKit
import WidgetKit

// MARK: - ホーム（勉強記録のギャラリー）
struct StartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [DailyGoal]
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @Query(filter: #Predicate<StudyMaterial> { $0.finishedAt == nil }, sort: \StudyMaterial.createdAt, order: .reverse)
    private var studyingMaterials: [StudyMaterial]

    // 新しい記録シートが閉じきってから録画画面を開くための印
    @State private var startAfterSheetCloses = false
    @State private var showStatsView = false
    @State private var showGoalSetting = false
    @State private var showCalendar = false
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showNewSession = false
    @State private var showWeeklyVlog = false
    // 長い目標と過去問
    @State private var showNewGoal = false
    @State private var editingGoal: StudyGoal?
    @State private var sharingGoal: StudyGoal?
    @State private var showScoreRecord = false
    @State private var showPapers = false
    @State private var showBuddies = false
    @State private var buddyJoinLink: BuddyJoinLink?
    @State private var showWatch = false
    @State private var watchJoinLink: WatchJoinLink?

    // タイマー設定値(時・分・秒)
    @State private var hours = 0
    @State private var minutes = 25
    @State private var seconds = 0

    @State private var selectedMode: Mode = .timer

    @StateObject var subjectManager = SubjectManager()
    @StateObject var permissionManager = PermissionManager()
    @StateObject private var draftStore = CurrentSessionDraftStore()

    @State private var showPermissionAlert = false
    @State private var selectedMaterialID: UUID? = MaterialSelection.lastID
    @State private var showShare = false
    @State private var showMaterials = false
    @AppStorage(OnboardingView.storageKey) private var hasSeenOnboarding = false
    @AppStorage(CoachTour.homeKey) private var hasSeenHomeTour = false
    @AppStorage(ThemeColor.storageKey) private var themeRaw = ThemeColor.sky.rawValue
    @State private var showHomeTour = false
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
        // 主役の色をここで決める。ホームとここから開く画面は、この色で描く
        let theme = ThemeColor.apply(rawValue: themeRaw)
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, 14)

                    HomeGoalCard(
                        sessions: sessions,
                        onCreate: { showNewGoal = true },
                        onEdit: { editingGoal = $0 },
                        onRecordScore: { showScoreRecord = true },
                        onPapers: { showPapers = true },
                        onShare: { sharingGoal = $0 }
                    )
                    .padding(.top, 6)
                    .padding(.bottom, DemoMode.isActive ? 16 : 10)

                    // 勉強仲間（スクショ用のデモでは出さない）
                    if !DemoMode.isActive {
                        HomeBuddiesRow { showBuddies = true }
                            .padding(.bottom, 8)
                        // 保護者・塾に共有しているあいだは必ず出す
                        HomeWatchRow { showWatch = true }
                            .padding(.bottom, 8)
                    }

                    todayStrip
                        .coachMark("home.today")
                        .padding(.bottom, 12)
                    weekShareRow
                        .coachMark("home.share")
                        .padding(.bottom, 18)
                    materialsStrip
                        .coachMark("home.materials")
                        .padding(.bottom, 22)

                    if sessions.isEmpty {
                        emptyState
                            .coachMark("home.gallery")
                    } else {
                        ForEach(monthSections) { section in
                            Text(monthTitle(section.month))
                                .font(ReelTheme.sans(13))
                                .foregroundColor(ReelTheme.secondary)
                                .padding(.bottom, 10)
                                .padding(.top, 6)

                            ForEach(Array(section.sessions.enumerated()), id: \.element.id) { index, session in
                                let showsDay = index == 0 || !Calendar.current.isDate(section.sessions[index - 1].date, inSameDayAs: session.date)
                                NavigationLink {
                                    SessionDetailView(session: session, subjectManager: subjectManager)
                                } label: {
                                    galleryRow(session, showsDay: showsDay)
                                }
                                .coachMarkIf(session.id == sessions.first?.id, "home.gallery")
                                .buttonStyle(.plain)
                                .padding(.bottom, 14)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            // 色が変わったらホームを描き直す。開いている設定の画面は閉じない
            .id(theme)
            .background(ReelTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .coachTour(homeTourSteps, isPresented: $showHomeTour) {
                hasSeenHomeTour = true
            }
            .onAppear {
                startHomeTourIfNeeded()
                openDemoScreenIfNeeded()
            }
            .onChange(of: hasSeenOnboarding) { startHomeTourIfNeeded() }
            .onChange(of: hasSeenHomeTour) { startHomeTourIfNeeded() }
            // 録画の設定そのものを渡して開く。設定が届く前に空の画面が出て真っ暗になるのを防ぐ
            .fullScreenCover(item: $sessionBootstrap) { bootstrap in
                ContentView(
                    subjectManager: subjectManager,
                    totalSeconds: bootstrap.totalSeconds,
                    onFinish: {
                        sessionBootstrap = nil
                        // 記録を保存してホームに戻った、いちばん気分のよいところでレビューを頼む（保存せずに閉じたときは頼まない）
                        if let latest = sessions.first, let saved = latest.recordedAt, Date().timeIntervalSince(saved) < 10 * 60 {
                            ReviewRequest.askIfDeserved(sessionCount: sessions.count, latestHasVideo: latest.videoFileName != nil, latestSeconds: latest.duration)
                        }
                    },
                    mode: bootstrap.mode,
                    bootstrap: bootstrap
                )
            }
            .sheet(isPresented: $showNewSession, onDismiss: {
                // シートを閉じている途中に別の画面を出すと表示されないので、閉じきってから始める
                guard startAfterSheetCloses else { return }
                startAfterSheetCloses = false
                beginSession()
            }) {
                NewSessionSheet(mode: $selectedMode, hours: $hours, minutes: $minutes, seconds: $seconds, materialID: $selectedMaterialID) {
                    startAfterSheetCloses = true
                    showNewSession = false
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showStatsView) {
                StudyStatsView(subjectManager: subjectManager)
            }
            .sheet(isPresented: $showWeeklyVlog) {
                WeeklyVlogView()
            }
            .sheet(isPresented: $showMaterials) {
                MaterialsView()
            }
            .sheet(isPresented: $showShare) {
                StudyShareView()
            }
            .sheet(isPresented: $showGoalSetting) {
                GoalSettingView()
            }
            .sheet(isPresented: $showNewGoal) {
                // 作ったらすぐ宣言カードを開く
                GoalEditView(goal: nil) { created in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { sharingGoal = created }
                }
            }
            .sheet(item: $editingGoal) { goal in
                GoalEditView(goal: goal)
            }
            .sheet(item: $sharingGoal) { goal in
                GoalShareView(goal: goal, initialKind: goal.isAchieved ? .achieved : (goal.dayNumber() <= 1 ? .declaration : .progress))
            }
            .sheet(isPresented: $showScoreRecord) {
                ScoreRecordSheet(result: nil, paperName: nil)
            }
            .sheet(isPresented: $showPapers) {
                PastPapersView()
            }
            .sheet(isPresented: $showBuddies, onDismiss: { buddyJoinLink = nil }) {
                BuddiesView(joinLink: buddyJoinLink)
            }
            .sheet(isPresented: $showWatch, onDismiss: { watchJoinLink = nil }) {
                WatchView(joinLink: watchJoinLink)
            }
            // 記録が増えたり消えたりしたら、勉強仲間に見せる今日・今週の合計を更新する
            .onChange(of: sessions.count) {
                BuddyCloud.shared.updateTotals(sessions)
            }
            .task {
                BuddyCloud.shared.updateTotals(sessions)
                // 保護者・塾に共有中の表示と、見守っている人の様子
                await WatchCloud.shared.refresh()
            }
            .sheet(isPresented: $showCalendar) {
                CalendarView(subjectManager: subjectManager)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(subjectManager: subjectManager)
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
            // 前回の勉強中にアプリが終了していたら、そこまでの記録を保存できるようにする
            .sessionRecoveryPrompt(subjectManager: subjectManager, isEnabled: hasSeenOnboarding)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("StudyReel")
                .font(ReelTheme.serif(30))
                .foregroundColor(ReelTheme.ink)

            Spacer()

            HStack(spacing: 16) {
                headerIcon("film.stack", label: L10n.string("1週間のVlog")) { showWeeklyVlog = true }
                headerIcon("chart.bar", label: L10n.string("統計")) { showStatsView = true }
                headerIcon("calendar", label: L10n.string("カレンダー")) { showCalendar = true }
                headerIcon("gearshape", label: L10n.string("設定・情報")) { showSettings = true }
            }
            .coachMark("home.tools")

            Button {
                showNewSession = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(ReelTheme.accentDeep)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(ReelTheme.accentSoft))
            }
            .accessibilityLabel(L10n.string("新しい記録"))
            .coachMark("home.new")
        }
    }

    private func headerIcon(_ name: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 17, weight: .light))
                .foregroundColor(ReelTheme.secondary)
        }
        .accessibilityLabel(label)
    }

    // スクショ用のデモ表示で、指定された画面をすぐ開く
    private func openDemoScreenIfNeeded() {
        guard let screen = DemoMode.screen else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            switch screen {
            case "share": showShare = true
            case "materials": showMaterials = true
            case "papers": showPapers = true
            case "goalShare": sharingGoal = try? modelContext.fetch(FetchDescriptor<StudyGoal>()).first
            case "buddies":
                BuddyCloud.shared.loadDemo()
                showBuddies = true
            default: break
            }
        }
    }

    // 今日の勉強時間と目標。タップで目標を設定する
    private var todayStrip: some View {
        Button {
            showGoalSetting = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.string("今日"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                    Text(compactDuration(todayStudyTime))
                        .font(ReelTheme.serif(20))
                        .foregroundColor(ReelTheme.ink)
                    Spacer()
                    Text(todayGoal.map { L10n.format("目標 %@", compactDuration($0.targetDuration)) } ?? L10n.string("目標を決める"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ReelTheme.line)
                        Capsule().fill(ReelTheme.accent)
                            .frame(width: geometry.size.width * min(progress, 1))
                    }
                }
                .frame(height: 3)
                // しばらく休んでいた人を責めずに迎える（戻ったことに意味がある。docs/research/science.md）
                if todayStudyTime == 0, StudyStreak.daysAway(days: Set(sessions.map { Calendar.current.startOfDay(for: $0.date) })) != nil {
                    Text(L10n.string("おかえりなさい。今日の1回から、また始めましょう"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.accentDeep)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 初回の案内

    private var homeTourSteps: [CoachStep] {
        [
            CoachStep(id: "home.new", title: L10n.string("ここから記録を始めます"), message: L10n.string("時間と教材を選んで「撮影をはじめる」を押すだけです。")),
            CoachStep(id: "home.today", title: L10n.string("今日の勉強時間"), message: L10n.string("タップすると、1日の目標を決められます。")),
            CoachStep(id: "home.share", title: L10n.string("記録を共有"), message: L10n.string("今日や今週の勉強を、画像にして勉強垢やグループに送れます。")),
            CoachStep(id: "home.materials", title: L10n.string("教材ごとに記録"), message: L10n.string("参考書を登録すると、教材ごとに時間がたまります。バーコードでも登録できます。")),
            CoachStep(id: "home.tools", title: L10n.string("Vlog・統計・カレンダー・設定"), message: L10n.string("左から、1週間のVlog作り、統計、カレンダー、設定です。")),
            CoachStep(id: "home.gallery", title: L10n.string("撮った記録が並びます"), message: L10n.string("タップすると動画を見返したり、メモを書き足したりできます。"))
        ]
    }

    private func startHomeTourIfNeeded() {
        guard hasSeenOnboarding, !hasSeenHomeTour, !showHomeTour, SessionRecovery.pendingSession == nil else { return }
        // 初回の案内やスプラッシュが消えてから出す
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard !hasSeenHomeTour, sessionBootstrap == nil else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                showHomeTour = true
            }
        }
    }

    // 勉強中の教材を表紙で並べる。タップで教材の一覧へ
    private var materialsStrip: some View {
        Button {
            showMaterials = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.string("教材"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                    Spacer()
                    Text(studyingMaterials.isEmpty ? L10n.string("教材を追加") : L10n.string("すべて見る"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.accentDeep)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ReelTheme.accentDeep)
                }

                if studyingMaterials.isEmpty {
                    Text(L10n.string("使っている参考書や問題集を入れると、教材ごとに勉強時間がたまります。"))
                        .font(ReelTheme.sans(12))
                        .foregroundColor(ReelTheme.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    // ボタンの中なので横スクロールにはせず、新しい順に5冊まで並べる
                    HStack(alignment: .top, spacing: 12) {
                            ForEach(studyingMaterials.prefix(5)) { material in
                                VStack(alignment: .leading, spacing: 5) {
                                    MaterialCover(material: material)
                                        .frame(width: 58, height: 80)
                                    Text(material.name)
                                        .font(ReelTheme.sans(10))
                                        .foregroundColor(ReelTheme.ink)
                                        .lineLimit(2)
                                        .frame(width: 58, alignment: .leading)
                                }
                            }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.materials")
    }

    // 今週の合計と、共有ボタン（勉強垢のグループや SNS へ）
    private var weekShareRow: some View {
        let weekSeconds: Int = {
            guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
            return sessions.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.duration }
        }()
        return Button {
            showShare = true
        } label: {
            HStack(spacing: 6) {
                Text(L10n.format("今週 %@", compactDuration(weekSeconds)))
                    .foregroundColor(ReelTheme.secondary)
                Spacer()
                Image(systemName: "square.and.arrow.up")
                Text(L10n.string("共有する"))
            }
            .font(ReelTheme.sans(12))
            .foregroundColor(ReelTheme.accentDeep)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.share")
    }

    private func galleryRow(_ session: StudySession, showsDay: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                if showsDay {
                    Text(dayNumber(session.date))
                        .font(ReelTheme.serif(20))
                        .foregroundColor(ReelTheme.ink)
                    Text(weekday(session.date))
                        .font(ReelTheme.sans(11))
                        .foregroundColor(ReelTheme.secondary)
                }
            }
            .frame(width: 34, alignment: .leading)
            .padding(.top, 4)

            ZStack(alignment: .bottomTrailing) {
                SessionThumbnail(fileName: session.thumbnailFileName, subject: session.subject)
                    .aspectRatio(16 / 10, contentMode: .fit)

                Text(compactDuration(session.duration))
                    .font(ReelTheme.sans(12, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 4)
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Menu {
                Button(role: .destructive) {
                    deleteSession(session)
                } label: {
                    Label(L10n.string("削除"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundColor(ReelTheme.secondary)
                    .frame(width: 24, height: 24)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(L10n.string("勉強した時間が、ひとつのVlogになる。"))
                .font(ReelTheme.serif(17))
                .foregroundColor(ReelTheme.ink)
                .multilineTextAlignment(.center)
            Button {
                showNewSession = true
            } label: {
                Text(L10n.string("はじめての記録をつける"))
                    .font(ReelTheme.sans(14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(ReelTheme.accentDeep))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private struct MonthSection: Identifiable {
        let month: Date
        let sessions: [StudySession]
        var id: Date { month }
    }

    private var monthSections: [MonthSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
        return grouped.keys.sorted(by: >).map { month in
            MonthSection(month: month, sessions: (grouped[month] ?? []).sorted { $0.date > $1.date })
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        String(format: "%02d", Calendar.current.component(.day, from: date))
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func compactDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
    }

    private func deleteSession(_ session: StudySession) {
        MediaStore.delete(session.thumbnailFileName, session.videoFileName)
        modelContext.delete(session)
    }

    // 撮影の許可を確認してから録画画面を開く
    private func beginSession() {
        // 紹介動画用のデモ表示ではカメラを使わないので、許可を求めずに始める
        if DemoMode.isActive {
            startSession(recordTimelapse: true)
            return
        }
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
    }

    private func startSession(recordTimelapse: Bool) {
        sessionBootstrap = SessionBootstrap(
            totalSeconds: hours * 3600 + minutes * 60 + seconds,
            mode: selectedMode,
            startedAt: nil,
            autoStart: false,
            initialRecordingEnabled: recordTimelapse,
            source: .app,
            materialID: selectedMaterialID
        )
    }

    private func consumePendingSessionDraftIfNeeded() {
        guard sessionBootstrap == nil, let draft = draftStore.consumePendingDraft() else { return }

        let canRecordTimelapse = permissionManager.cameraPermissionGranted && permissionManager.photoLibraryPermissionGranted
        sessionBootstrap = SessionBootstrap(
            totalSeconds: draft.plannedDurationSeconds,
            mode: draft.resolvedMode,
            startedAt: draft.startedAt,
            autoStart: true,
            initialRecordingEnabled: draft.shouldRecordTimelapse && canRecordTimelapse,
            source: draft.source
        )
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "studyreel" else { return }

        if url.host == "start" {
            consumePendingSessionDraftIfNeeded()
            if sessionBootstrap != nil { return }

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
        } else if url.host == "paywall" {
            showPaywall = true
        } else if url.host == "buddies", let link = BuddyJoinLink(url: url) {
            buddyJoinLink = link
            showBuddies = true
        } else if url.host == "watch", let link = WatchJoinLink(url: url) {
            watchJoinLink = link
            showWatch = true
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
