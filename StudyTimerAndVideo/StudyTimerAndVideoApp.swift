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
    @StateObject private var storeKit = StoreKitManager()
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
            StartView()
                .environmentObject(storeKit)
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
