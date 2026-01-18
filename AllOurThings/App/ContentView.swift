//
//  ContentView.swift
//  AllOurThings
//
//  Created by Matt on 28/12/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    init() {
        // Configure tab bar appearance for cosy aesthetic
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.backgroundColor = UIColor(Theme.Colors.warmCream)
        tabBarAppearance.shadowColor = UIColor(Theme.Colors.gentleBorder)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainTabView
            } else {
                WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }

    private var mainTabView: some View {
        ItemListView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: Item.self)

        let sampleItems = [
            Item(name: "Samsung Refrigerator", manufacturer: "Samsung", modelNumber: "RF28T5001WW", category: "Kitchen", location: "Kitchen", notes: "French door style, purchased at Costco"),
            Item(name: "LG Washing Machine", manufacturer: "LG", modelNumber: "WM3900HWA", category: "Laundry", location: "Laundry Room"),
            Item(name: "Dyson Vacuum", manufacturer: "Dyson", modelNumber: "V11 Animal", category: "Cleaning", location: "Utility Closet", notes: "Great for pet hair"),
            Item(name: "KitchenAid Stand Mixer", manufacturer: "KitchenAid", modelNumber: "KSM150PSER", category: "Kitchen", location: "Kitchen Counter")
        ]

        for item in sampleItems {
            container.mainContext.insert(item)
        }

        return ContentView()
            .modelContainer(container)
    }
}
