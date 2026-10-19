//
//  StudyTimerAndVideoApp.swift
//  StudyTimerAndVideo
//
//  Created by hw24a094 on 2025/09/27.
//

import SwiftUI
import SwiftData

//MARK: - アプリエントリーポイント
@main
struct StudyTimerAndVideoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var storeKit = StoreKitManager()
    @State private var showsSplash = true
    @AppStorage(OnboardingView.storageKey) private var hasSeenOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    // Create container here to access context
    let container: ModelContainer
    
    init() {
        do {
            // iCloud の権限があると SwiftData は CloudKit 同期を自動で始めようとし、
            // 今のモデルは CloudKit の条件（全項目が省略可能など）を満たさないので起動時に落ちる。
            // バックアップは iCloud Drive にファイルで送っているので、CloudKit 同期は使わない
            let configuration = ModelConfiguration(cloudKitDatabase: .none)
            container = try ModelContainer(
                for: StudySession.self, Tag.self, DailyGoal.self, StudyMaterial.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                StartView()
                if !hasSeenOnboarding {
                    OnboardingView {
                        withAnimation(.easeOut(duration: 0.35)) {
                            hasSeenOnboarding = true
                        }
                    }
                    .transition(.opacity)
                    .zIndex(0.5)
                }
                if showsSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environmentObject(storeKit)
            // 明るい見た目に固定する（ダークモードには切り替えない）
            .preferredColorScheme(.light)
            .task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeOut(duration: 0.5)) {
                    showsSplash = false
                }
            }
            .onChange(of: scenePhase) { _, phase in
                // 自動バックアップがオンなら、裏に回ったときに iCloud へ送る
                if phase == .background {
                    CloudBackup.backupIfNeeded(context: container.mainContext)
                }
            }
            .onAppear {
                let context = container.mainContext
                // すでに使っている人には案内を出さない
                if !hasSeenOnboarding, (try? context.fetchCount(FetchDescriptor<StudySession>())) ?? 0 > 0 {
                    hasSeenOnboarding = true
                }
                let migrator = DataMigrator(modelContext: context)
                migrator.migrateIfNeeded()
                #if DEBUG
                DebugPreviewSeeder.seedIfNeeded(modelContext: context)
                #endif
            }
        }
        .modelContainer(container)
    }
}
