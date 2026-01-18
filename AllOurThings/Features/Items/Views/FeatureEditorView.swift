//
//  FeatureEditorView.swift
//  AllOurThings
//
//  Editor for item features (capabilities and specifications)
//

import SwiftUI
import SwiftData

struct FeatureEditorView: View {
    let item: Item
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var editableFeatures: [ItemFeature]

    init(item: Item) {
        self.item = item
        _editableFeatures = State(initialValue: item.features)
    }

    private var capabilities: Binding<[ItemFeature]> {
        Binding(
            get: {
                editableFeatures.filter { $0.type == .capability }
            },
            set: { newCapabilities in
                // Remove old capabilities and add new ones
                editableFeatures.removeAll { $0.type == .capability }
                editableFeatures.append(contentsOf: newCapabilities)
            }
        )
    }

    private var specifications: Binding<[ItemFeature]> {
        Binding(
            get: {
                editableFeatures.filter { $0.type == .specification }
            },
            set: { newSpecifications in
                // Remove old specifications and add new ones
                editableFeatures.removeAll { $0.type == .specification }
                editableFeatures.append(contentsOf: newSpecifications)
            }
        )
    }

    var body: some View {
        NavigationView {
            List {
                // Capabilities Section
                Section {
                    ForEach(capabilities.wrappedValue.indices, id: \.self) { index in
                        if let featureIndex = editableFeatures.firstIndex(where: { $0.id == capabilities.wrappedValue[index].id }) {
                            TextField("Capability", text: $editableFeatures[featureIndex].text)
                                .font(Theme.Fonts.cosyBody())
                        }
                    }
                    .onDelete { indices in
                        deleteCapabilities(at: indices)
                    }

                    Button(action: addCapability) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.mintGreen)
                            Text("Add Capability")
                                .font(Theme.Fonts.cosyBody())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                        }
                    }
                } header: {
                    Text("Capabilities")
                        .font(Theme.Fonts.cosySubheadline())
                }

                // Specifications Section
                Section {
                    ForEach(specifications.wrappedValue.indices, id: \.self) { index in
                        if let featureIndex = editableFeatures.firstIndex(where: { $0.id == specifications.wrappedValue[index].id }) {
                            TextField("Specification", text: $editableFeatures[featureIndex].text)
                                .font(Theme.Fonts.cosyBody())
                        }
                    }
                    .onDelete { indices in
                        deleteSpecifications(at: indices)
                    }

                    Button(action: addSpecification) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.mintGreen)
                            Text("Add Specification")
                                .font(Theme.Fonts.cosyBody())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                        }
                    }
                } header: {
                    Text("Specifications")
                        .font(Theme.Fonts.cosySubheadline())
                }
            }
            .navigationTitle("Edit Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(Theme.Fonts.cosyButton())
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFeatures()
                    }
                    .font(Theme.Fonts.cosyButton())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.blushPink)
                }
            }
        }
    }

    // MARK: - Actions

    private func addCapability() {
        let newFeature = ItemFeature(type: .capability, text: "")
        editableFeatures.append(newFeature)
    }

    private func addSpecification() {
        let newFeature = ItemFeature(type: .specification, text: "")
        editableFeatures.append(newFeature)
    }

    private func deleteCapabilities(at indices: IndexSet) {
        let capabilitiesToDelete = capabilities.wrappedValue
        for index in indices {
            if let feature = capabilitiesToDelete[safe: index],
               let editableIndex = editableFeatures.firstIndex(where: { $0.id == feature.id }) {
                editableFeatures.remove(at: editableIndex)
            }
        }
    }

    private func deleteSpecifications(at indices: IndexSet) {
        let specificationsToDelete = specifications.wrappedValue
        for index in indices {
            if let feature = specificationsToDelete[safe: index],
               let editableIndex = editableFeatures.firstIndex(where: { $0.id == feature.id }) {
                editableFeatures.remove(at: editableIndex)
            }
        }
    }

    private func saveFeatures() {
        // Remove features with empty text
        let validFeatures = editableFeatures.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        // Save to item
        item.features = validFeatures

        // Save to database
        do {
            try modelContext.save()
        } catch {
            print("Error saving features: \(error)")
        }

        dismiss()
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
