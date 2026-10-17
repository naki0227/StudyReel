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
    // Create container here to access context
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: StudySession.self, Tag.self, DailyGoal.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                StartView()
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
            .onAppear {
                let context = container.mainContext
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
