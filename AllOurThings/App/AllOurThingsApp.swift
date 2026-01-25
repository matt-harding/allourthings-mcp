//
//  AllOurThingsApp.swift
//  AllOurThings
//
//  Created by Matt on 28/12/2025.
//

import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.allourhings.app", category: "Startup")

@main
struct AllOurThingsApp: App {

    init() {
        // THIS SHOULD APPEAR IMMEDIATELY WHEN APP STARTS
        print("========================================")
        print("🚀 APP STARTING - PRINT STATEMENT TEST")
        print("========================================")
        logger.info("🚀 APP STARTING - LOGGER TEST")
    }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            ManualSection.self,
            ManualTopicBullet.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            // If migration fails, try to delete the old database and create a fresh one
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to reset database...")

            // Get the default store URL and delete it
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            // Also remove associated files
            let shmURL = storeURL.appendingPathExtension("shm")
            let walURL = storeURL.appendingPathExtension("wal")
            try? FileManager.default.removeItem(at: shmURL)
            try? FileManager.default.removeItem(at: walURL)

            // Try again with fresh database
            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("✅ Database reset successful")
                return container
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
