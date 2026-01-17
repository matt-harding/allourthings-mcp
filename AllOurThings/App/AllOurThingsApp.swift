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
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Add sample items on first launch
            let context = container.mainContext
            let descriptor = FetchDescriptor<Item>()
            let itemCount = (try? context.fetchCount(descriptor)) ?? 0

            if itemCount == 0 {
                // Add sample items for a nice first impression
                let sampleItems = [
                    Item(name: "Samsung Refrigerator", manufacturer: "Samsung", modelNumber: "RF28T5001WW", category: "Kitchen", location: "Kitchen", notes: "French door style"),
                    Item(name: "LG Washing Machine", manufacturer: "LG", modelNumber: "WM3900HWA", category: "Laundry", location: "Laundry Room", notes: "Front load washer"),
                    Item(name: "Dyson Vacuum", manufacturer: "Dyson", modelNumber: "V11 Animal", category: "Cleaning", location: "Utility Closet", notes: "Great for pet hair"),
                    Item(name: "KitchenAid Mixer", manufacturer: "KitchenAid", modelNumber: "KSM150PSER", category: "Kitchen", location: "Kitchen Counter", notes: "5-quart capacity"),
                    Item(name: "Nest Thermostat", manufacturer: "Google", modelNumber: "T3007ES", category: "Smart Home", location: "Hallway", notes: "Learning thermostat"),
                    Item(name: "Roomba", manufacturer: "iRobot", modelNumber: "j7+", category: "Cleaning", location: "Living Room", notes: "Self-emptying base")
                ]

                for item in sampleItems {
                    context.insert(item)
                }

                try? context.save()
            }

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
