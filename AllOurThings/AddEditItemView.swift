import SwiftUI
import SwiftData

struct AddEditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var manufacturer = ""
    @State private var modelNumber = ""
    @State private var category = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var purchaseDate: Date?
    @State private var warrantyExpirationDate: Date?
    @State private var showingPurchaseDatePicker = false
    @State private var showingWarrantyDatePicker = false

    let item: Item?

    var isEditing: Bool {
        item != nil
    }

    init(item: Item? = nil) {
        self.item = item
        if let item = item {
            _name = State(initialValue: item.name)
            _manufacturer = State(initialValue: item.manufacturer)
            _modelNumber = State(initialValue: item.modelNumber)
            _category = State(initialValue: item.category)
            _location = State(initialValue: item.location)
            _notes = State(initialValue: item.notes)
            _purchaseDate = State(initialValue: item.purchaseDate)
            _warrantyExpirationDate = State(initialValue: item.warrantyExpirationDate)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model Number", text: $modelNumber)
                    TextField("Category", text: $category)
                    TextField("Location", text: $location)
                }

                Section("Dates") {
                    HStack {
                        Text("Purchase Date")
                        Spacer()
                        if let purchaseDate = purchaseDate {
                            Text(purchaseDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not set")
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingPurchaseDatePicker = true
                    }

                    HStack {
                        Text("Warranty Expires")
                        Spacer()
                        if let warrantyDate = warrantyExpirationDate {
                            Text(warrantyDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not set")
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingWarrantyDatePicker = true
                    }
                }

                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingPurchaseDatePicker) {
                NavigationView {
                    DatePicker("Purchase Date", selection: Binding(
                        get: { purchaseDate ?? Date() },
                        set: { purchaseDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .navigationTitle("Purchase Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Clear") {
                                purchaseDate = nil
                                showingPurchaseDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingPurchaseDatePicker = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingWarrantyDatePicker) {
                NavigationView {
                    DatePicker("Warranty Expiration", selection: Binding(
                        get: { warrantyExpirationDate ?? Date() },
                        set: { warrantyExpirationDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .navigationTitle("Warranty Expiration")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Clear") {
                                warrantyExpirationDate = nil
                                showingWarrantyDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingWarrantyDatePicker = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func saveItem() {
        if let item = item {
            // Edit existing item
            item.name = name
            item.manufacturer = manufacturer
            item.modelNumber = modelNumber
            item.category = category
            item.location = location
            item.notes = notes
            item.purchaseDate = purchaseDate
            item.warrantyExpirationDate = warrantyExpirationDate
        } else {
            // Create new item
            let newItem = Item(
                name: name,
                manufacturer: manufacturer,
                modelNumber: modelNumber,
                category: category,
                purchaseDate: purchaseDate,
                warrantyExpirationDate: warrantyExpirationDate,
                location: location,
                notes: notes
            )
            modelContext.insert(newItem)
        }

        do {
            try modelContext.save()
        } catch {
            print("Error saving item: \(error)")
        }

        dismiss()
    }
}