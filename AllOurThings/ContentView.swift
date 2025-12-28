//
//  ContentView.swift
//  AllOurThings
//
//  Created by Matt on 28/12/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        ApplianceDetailView(item: item)
                    } label: {
                        ApplianceRowView(item: item)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditApplianceView()
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

struct ApplianceRowView: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if !item.category.isEmpty {
                    Text(item.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if !item.manufacturer.isEmpty || !item.modelNumber.isEmpty {
                HStack {
                    if !item.manufacturer.isEmpty {
                        Text(item.manufacturer)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if !item.manufacturer.isEmpty && !item.modelNumber.isEmpty {
                        Text("·")
                            .foregroundColor(.secondary)
                    }
                    if !item.modelNumber.isEmpty {
                        Text(item.modelNumber)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !item.location.isEmpty {
                HStack {
                    Image(systemName: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct ApplianceDetailView: View {
    let item: Item
    @State private var showingEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if !item.category.isEmpty {
                        Text(item.category)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(title: "Manufacturer", value: item.manufacturer)
                    DetailRow(title: "Model Number", value: item.modelNumber)
                    DetailRow(title: "Location", value: item.location)

                    if let purchaseDate = item.purchaseDate {
                        DetailRow(title: "Purchase Date", value: purchaseDate.formatted(date: .abbreviated, time: .omitted))
                    }

                    if let warrantyDate = item.warrantyExpirationDate {
                        DetailRow(title: "Warranty Expires", value: warrantyDate.formatted(date: .abbreviated, time: .omitted))
                    }

                    if !item.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.headline)
                            Text(item.notes)
                                .font(.body)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditApplianceView(item: item)
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.body)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: Item.self)

        let sampleItems = [
            Item(name: "Samsung Refrigerator", manufacturer: "Samsung", modelNumber: "RF28T5001WW", category: "Kitchen Appliance", location: "Kitchen", notes: "French door style, purchased at Costco"),
            Item(name: "LG Washing Machine", manufacturer: "LG", modelNumber: "WM3900HWA", category: "Laundry", location: "Laundry Room"),
            Item(name: "Dyson Vacuum", manufacturer: "Dyson", modelNumber: "V11 Animal", category: "Cleaning", location: "Utility Closet", notes: "Great for pet hair"),
            Item(name: "KitchenAid Stand Mixer", manufacturer: "KitchenAid", modelNumber: "KSM150PSER", category: "Kitchen Appliance", location: "Kitchen Counter")
        ]

        for item in sampleItems {
            container.mainContext.insert(item)
        }

        return ContentView()
            .modelContainer(container)
    }
}
