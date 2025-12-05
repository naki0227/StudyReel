import Foundation
import SwiftData
import SwiftUI

class DataMigrator {
    private let modelContext: ModelContext
    private let userDefaultsKey = "study_sessions"
    private let migrationFlagKey = "hasMigratedToSwiftData"
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func migrateIfNeeded() {
        // Check if already migrated
        if UserDefaults.standard.bool(forKey: migrationFlagKey) {
            return
        }
        
        print("🚀 Starting migration to SwiftData...")
        
        // Load legacy data
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let legacySessions = try? JSONDecoder().decode([LegacyStudySession].self, from: data) else {
            print("ℹ️ No legacy data found or decode failed.")
            markAsMigrated()
            return
        }
        
        // Convert and insert
        for legacy in legacySessions {
            let newSession = StudySession(
                id: legacy.id,
                date: legacy.date,
                duration: legacy.duration,
                subject: legacy.subject
            )
            modelContext.insert(newSession)
        }
        
        // Save context
        do {
            try modelContext.save()
            print("✅ Successfully migrated \(legacySessions.count) sessions.")
            markAsMigrated()
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    
    private func markAsMigrated() {
        UserDefaults.standard.set(true, forKey: migrationFlagKey)
    }
}
