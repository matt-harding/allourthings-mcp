import SwiftUI
import SwiftData

struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingAddSheet = false

    let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.xs),
        GridItem(.flexible(), spacing: Theme.Spacing.xs)
    ]

    private var groupedItems: [(name: String, items: [Item])] {
        let grouped = Dictionary(grouping: items) { item in
            item.category.isEmpty ? "Uncategorized" : item.category
        }

        return grouped.map { (name: $0.key, items: $0.value) }
            .sorted { tuple1, tuple2 in
                // Sort alphabetically
                return tuple1.name < tuple2.name
            }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.medium, pinnedViews: []) {
                        ForEach(groupedItems, id: \.name) { group in
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                // Simple Section Header
                                Text(group.name)
                                    .font(Theme.Fonts.cosyHeadline())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                    .padding(.horizontal, Theme.Spacing.small)
                                    .padding(.vertical, Theme.Spacing.xs)

                                // Grid for this group's items
                                LazyVGrid(columns: columns, spacing: Theme.Spacing.xs) {
                                    ForEach(group.items) { item in
                                        NavigationLink {
                                            ItemDetailView(item: item)
                                        } label: {
                                            ItemRowView(item: item)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .contextMenu {
                                            Button(role: .destructive, action: {
                                                deleteItem(item)
                                            }) {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.xs)
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
            .background(Theme.Colors.skyBlue)
            .navigationTitle("AllOurThings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Item", systemImage: "plus.circle.fill")
                    }
                    .tint(Theme.Colors.blushPink)
                    .cosyButtonPress()
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditItemView()
            }
        } detail: {
            VStack(spacing: Theme.Spacing.medium) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.softLavender)
                Text("Your Collection Awaits")
                    .font(Theme.Fonts.cosyHeadline())
                    .foregroundColor(Theme.Colors.cocoaBrown)
                Text("Select an item to see its details")
                    .font(Theme.Fonts.cosyBody())
                    .foregroundColor(Theme.Colors.softGray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.skyBlue)
        }
    }

    private func deleteItem(_ item: Item) {
        withAnimation {
            // Delete associated files first
            if let imagePath = item.imageFilePath {
                ImageStorageHelper.shared.deleteImage(at: imagePath)
            }
            if let pdfPath = item.manualFilePath {
                PDFStorageHelper.shared.deletePDF(at: pdfPath)
            }

            // Delete the item from the model context
            modelContext.delete(item)

            // Save the context
            do {
                try modelContext.save()
            } catch {
                print("Error deleting item: \(error)")
            }
        }
    }
}

struct ItemRowView: View {
    let item: Item

    var body: some View {
        VStack(spacing: 0) {
            // Image Section (or placeholder)
            ZStack {
                if let imageData = item.imageData,
                   let uiImage = UIImage(data: imageData) {
                    // Show image
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    // Placeholder with category color
                    Theme.Colors.categoryColor(for: item.category)
                        .opacity(0.2)

                    // Placeholder icon
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Theme.Colors.categoryColor(for: item.category).opacity(0.4))
                }

                // Badge in corner showing location
                VStack {
                    HStack {
                        Spacer()
                        if !item.location.isEmpty {
                            Text(item.location)
                                .font(Theme.Fonts.cosyCaption())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.softLavender.opacity(0.9))
                                .cornerRadius(Theme.CornerRadius.small)
                                .padding(Theme.Spacing.xxs)
                        }
                    }
                    Spacer()
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)

            // Info Section
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(item.name)
                    .font(Theme.Fonts.cosyHeadline())
                    .foregroundColor(Theme.Colors.cocoaBrown)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !item.manufacturer.isEmpty {
                    Text(item.manufacturer)
                        .font(Theme.Fonts.cosyCaption())
                        .foregroundColor(Theme.Colors.softGray)
                        .lineLimit(1)
                }
            }
            .padding(Theme.Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cloudWhite)
        }
        .cornerRadius(Theme.CornerRadius.large)
        .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
        )
    }
}

struct ItemDetailView: View {
    let item: Item
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingFeatureEditor = false
    @State private var manualSectionCount: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                // Header Section
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(item.name)
                        .font(Theme.Fonts.cosyExtraLargeTitle())
                        .foregroundColor(Theme.Colors.cocoaBrown)

                    if !item.category.isEmpty {
                        Text(item.category)
                            .font(Theme.Fonts.cosyLargeTitle())
                            .foregroundColor(Theme.Colors.categoryColor(for: item.category))
                    }
                }

                // Image Section
                if let imageData = item.imageData,
                   let uiImage = UIImage(data: imageData) {
                    VStack(spacing: 0) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(Theme.CornerRadius.large)
                            .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 3, y: 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                    .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.thick)
                            )
                    }
                    .padding(Theme.Spacing.medium)
                    .background(Theme.Colors.cloudWhite)
                    .cornerRadius(Theme.CornerRadius.xl)
                    .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 3, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                            .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.thick)
                    )
                }

                // Details Section
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    DetailRow(title: "Manufacturer", value: item.manufacturer)
                    DetailRow(title: "Model Number", value: item.modelNumber)
                    DetailRow(title: "Location", value: item.location)

                    if let purchaseDate = item.purchaseDate {
                        DetailRow(title: "Purchase Date", value: purchaseDate.formatted(date: .abbreviated, time: .omitted))
                    }

                    if let warrantyDate = item.warrantyExpirationDate {
                        DetailRow(title: "Warranty Expires", value: warrantyDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }

                // Notes Section
                if !item.notes.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "note.text")
                                .foregroundColor(Theme.Colors.butterYellow)
                            Text("Notes")
                                .font(Theme.Fonts.cosyHeadline())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                        }
                        Text(item.notes)
                            .font(Theme.Fonts.cosyBody())
                            .foregroundColor(Theme.Colors.cocoaBrown)
                    }
                    .padding(Theme.Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.butterYellow.opacity(0.2))
                    .cornerRadius(Theme.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .stroke(Theme.Colors.butterYellow, lineWidth: Theme.BorderWidth.thick)
                    )
                }

                // Features Section
                if !item.features.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "star.fill")
                                .foregroundColor(Theme.Colors.mintGreen)
                            Text("Key Features")
                                .font(Theme.Fonts.cosyHeadline())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                            Spacer()
                            Button(action: { showingFeatureEditor = true }) {
                                Text("Edit")
                                    .font(Theme.Fonts.cosyCaption())
                                    .foregroundColor(Theme.Colors.blushPink)
                            }
                        }

                        // Capabilities
                        let capabilities = item.features.filter { $0.type == .capability }
                        if !capabilities.isEmpty {
                            Text("Capabilities")
                                .font(Theme.Fonts.cosySubheadline())
                                .foregroundColor(Theme.Colors.mutedPlum)
                                .textCase(.uppercase)
                                .padding(.top, Theme.Spacing.xs)

                            ForEach(capabilities) { feature in
                                HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                    Text("•")
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                    Text(feature.text)
                                        .font(Theme.Fonts.cosyBody())
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                }
                            }
                        }

                        // Specifications
                        let specifications = item.features.filter { $0.type == .specification }
                        if !specifications.isEmpty {
                            Text("Specifications")
                                .font(Theme.Fonts.cosySubheadline())
                                .foregroundColor(Theme.Colors.mutedPlum)
                                .textCase(.uppercase)
                                .padding(.top, Theme.Spacing.small)

                            ForEach(specifications) { feature in
                                HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                    Text("•")
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                    Text(feature.text)
                                        .font(Theme.Fonts.cosyBody())
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                }
                            }
                        }
                    }
                    .padding(Theme.Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.mintGreen.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .stroke(Theme.Colors.mintGreen, lineWidth: Theme.BorderWidth.thick)
                    )
                }

                // Manual & Chat Section
                if manualSectionCount > 0 {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "book.fill")
                                .foregroundColor(Theme.Colors.blushPink)
                            Text("Q&A")
                                .font(Theme.Fonts.cosyHeadline())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                            Spacer()
                            Text("\(manualSectionCount) sections")
                                .font(Theme.Fonts.cosyCaption())
                                .foregroundColor(Theme.Colors.softGray)
                        }
                        .padding(.horizontal, Theme.Spacing.medium)
                        .padding(.top, Theme.Spacing.medium)

                        // Embedded chat
                        ItemChatView(item: item)
                            .frame(height: 400)
                    }
                    .background(Theme.Colors.cloudWhite)
                    .cornerRadius(Theme.CornerRadius.xl)
                    .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 3, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                            .stroke(Theme.Colors.blushPink, lineWidth: Theme.BorderWidth.thick)
                    )
                }

                Spacer()
            }
            .padding(Theme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cloudWhite)
            .cornerRadius(Theme.CornerRadius.xl)
            .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 3, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                    .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.thick)
            )
            .padding(Theme.Spacing.medium)
        }
        .cosyGradientBackground()
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingEditSheet = true }) {
                    Text("Edit")
                        .font(Theme.Fonts.cosyButton())
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.small)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.blushPink)
                        .cornerRadius(Theme.CornerRadius.xl)
                }
                .cosyButtonPress()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditItemView(item: item)
        }
        .sheet(isPresented: $showingFeatureEditor) {
            FeatureEditorView(item: item)
        }
        .task {
            await checkManualSections()
        }
    }

    private func checkManualSections() async {
        let itemId = item.id
        var descriptor = FetchDescriptor<ManualSection>()
        descriptor.predicate = #Predicate { section in
            section.itemId == itemId
        }

        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        await MainActor.run {
            manualSectionCount = count
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Fonts.cosyCaption())
                    .foregroundColor(Theme.Colors.mutedPlum)
                    .textCase(.uppercase)
                Text(value)
                    .font(Theme.Fonts.cosyBody())
                    .foregroundColor(Theme.Colors.cocoaBrown)
            }
            .padding(Theme.Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.warmCream.opacity(0.5))
            .cornerRadius(Theme.CornerRadius.small)
        }
    }
}
