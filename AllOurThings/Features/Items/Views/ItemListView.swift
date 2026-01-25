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
                if items.isEmpty {
                    VStack(spacing: Theme.Spacing.large) {
                        Spacer()

                        VStack(spacing: Theme.Spacing.small) {
                            Image(systemName: "cube.box.fill")
                                .font(.system(size: 64))
                                .foregroundColor(Theme.Colors.softLavender)
                            Text("No items yet")
                                .font(Theme.Fonts.cosyHeadline())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                            Text("Add your first item to get started")
                                .font(Theme.Fonts.cosyBody())
                                .foregroundColor(Theme.Colors.softGray)
                        }

                        Button(action: { showingAddSheet = true }) {
                            Label("Add Item", systemImage: "plus.circle.fill")
                                .font(Theme.Fonts.cosyTitle())
                                .foregroundColor(.white)
                                .padding(.horizontal, Theme.Spacing.xl)
                                .padding(.vertical, Theme.Spacing.medium)
                                .background(Theme.Colors.blushPink)
                                .cornerRadius(Theme.CornerRadius.xl)
                                .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 3, y: 3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                                        .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                                )
                        }
                        .cosyButtonPress()

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
            }
            .background(Theme.Colors.skyBlue)
            .navigationTitle("AllOurThings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !items.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddSheet = true }) {
                            Label("Add Item", systemImage: "plus.circle.fill")
                        }
                        .tint(Theme.Colors.blushPink)
                        .cosyButtonPress()
                    }
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
    @State private var manualSectionCount: Int = 0
    @State private var manualSections: [ManualSection] = []
    @State private var sectionsByTopic: [ManualTopic: [ManualSection]] = [:]
    @State private var pdfToShow: PDFViewerData?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                headerSection
                basicInformationSection
                datesSection
                photoSection
                notesSection
                manualSection
                manualTopicsSection
                chatSection

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
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                }
                .tint(Theme.Colors.blushPink)
                .cosyButtonPress()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditItemView(item: item)
        }
        .sheet(item: $pdfToShow) { pdfData in
            PDFViewerView(
                pdfPath: pdfData.pdfPath,
                pageNumber: pdfData.pageNumber,
                itemName: pdfData.itemName
            )
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

        let sections = (try? modelContext.fetch(descriptor)) ?? []
        await MainActor.run {
            manualSections = sections
            manualSectionCount = sections.count
            sectionsByTopic = ManualTopicTagger.shared.tagSections(sections)
        }
    }

    private func openManual(pageNumber: Int) {
        guard let manualPath = item.manualFilePath, !manualPath.isEmpty else { return }
        pdfToShow = PDFViewerData(
            pdfPath: manualPath,
            pageNumber: pageNumber,
            itemName: item.name
        )
    }

    @ViewBuilder
    private var headerSection: some View {
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
    }

    @ViewBuilder
    private var basicInformationSection: some View {
        if !item.category.isEmpty ||
            !item.manufacturer.isEmpty ||
            !item.modelNumber.isEmpty ||
            !item.location.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("Basic Information")
                    .font(Theme.Fonts.cosyHeadline())
                    .foregroundColor(Theme.Colors.cocoaBrown)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    if !item.category.isEmpty {
                        DetailRowValue(title: "Category", value: item.category)
                    }
                    if !item.manufacturer.isEmpty {
                        DetailRowValue(title: "Manufacturer", value: item.manufacturer)
                    }
                    if !item.modelNumber.isEmpty {
                        DetailRowValue(title: "Model Number", value: item.modelNumber)
                    }
                    if !item.location.isEmpty {
                        DetailRowValue(title: "Location", value: item.location)
                    }
                }
            }
            .cosyCard(padding: Theme.Spacing.medium)
        }
    }

    @ViewBuilder
    private var datesSection: some View {
        if item.purchaseDate != nil || item.warrantyExpirationDate != nil {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("Dates")
                    .font(Theme.Fonts.cosyHeadline())
                    .foregroundColor(Theme.Colors.cocoaBrown)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    if let purchaseDate = item.purchaseDate {
                        DetailRowValue(
                            title: "Purchase Date",
                            value: purchaseDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                    if let warrantyDate = item.warrantyExpirationDate {
                        DetailRowValue(
                            title: "Warranty Expires",
                            value: warrantyDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }
            }
            .cosyCard(padding: Theme.Spacing.medium)
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        if let imageData = item.imageData,
           let uiImage = UIImage(data: imageData) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("Photo")
                    .font(Theme.Fonts.cosyHeadline())
                    .foregroundColor(Theme.Colors.cocoaBrown)

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
            .cosyCard(padding: Theme.Spacing.medium)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
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
    }

    @ViewBuilder
    private var manualSection: some View {
        if let manualPath = item.manualFilePath, !manualPath.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(Theme.Colors.blushPink)
                    Text("Manual")
                        .font(Theme.Fonts.cosyHeadline())
                        .foregroundColor(Theme.Colors.cocoaBrown)
                    Spacer()
                    Text("\(manualSectionCount) sections")
                        .font(Theme.Fonts.cosyCaption())
                        .foregroundColor(Theme.Colors.softGray)
                }

                if let manualName = item.manualFileName, !manualName.isEmpty {
                    Text(manualName)
                        .font(Theme.Fonts.cosyBody())
                        .foregroundColor(Theme.Colors.cocoaBrown)
                        .lineLimit(2)
                }

                Button(action: {
                    pdfToShow = PDFViewerData(
                        pdfPath: manualPath,
                        pageNumber: 1,
                        itemName: item.name
                    )
                }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "book.fill")
                        Text("Open Manual")
                    }
                    .font(Theme.Fonts.cosyBody())
                    .foregroundColor(Theme.Colors.cocoaBrown)
                    .padding(.horizontal, Theme.Spacing.small)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.warmCream)
                    .cornerRadius(Theme.CornerRadius.medium)
                }
                .cosyButtonPress()
            }
            .padding(Theme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.peach.opacity(0.15))
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.peach, lineWidth: Theme.BorderWidth.thick)
            )
        }
    }

    @ViewBuilder
    private var manualTopicsSection: some View {
        if !manualSections.isEmpty {
            ManualTopicsSectionView(
                sectionsByTopic: sectionsByTopic,
                openManual: openManual
            )
        }
    }

    @ViewBuilder
    private var chatSection: some View {
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
    }
}

struct ManualTopicsSectionView: View {
    let sectionsByTopic: [ManualTopic: [ManualSection]]
    let openManual: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(Theme.Colors.softLavender)
                Text("Manual Topics")
                    .font(Theme.Fonts.cosyHeadline())
                    .foregroundColor(Theme.Colors.cocoaBrown)
            }

            ForEach(ManualTopic.allCases, id: \.self) { topic in
                ManualTopicCardView(
                    topic: topic,
                    sections: sectionsByTopic[topic] ?? [],
                    openManual: openManual
                )
            }
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.softLavender.opacity(0.15))
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.softLavender, lineWidth: Theme.BorderWidth.thick)
        )
    }
}

struct ManualTopicCardView: View {
    let topic: ManualTopic
    let sections: [ManualSection]
    let openManual: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(topic.displayName)
                    .font(Theme.Fonts.cosySubheadline())
                    .foregroundColor(Theme.Colors.mutedPlum)
                Spacer()
                Text("\(sections.count) sections")
                    .font(Theme.Fonts.cosyCaption())
                    .foregroundColor(Theme.Colors.softGray)
            }

            if sections.isEmpty {
                Text("No manual content found for this topic.")
                    .font(Theme.Fonts.cosyCaption())
                    .foregroundColor(Theme.Colors.softGray)
            } else {
                ForEach(sections) { section in
                    ManualSectionCardView(section: section, openManual: openManual)
                }
            }
        }
        .padding(Theme.Spacing.small)
        .background(Theme.Colors.warmCream.opacity(0.6))
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
        )
    }
}

struct ManualSectionCardView: View {
    let section: ManualSection
    let openManual: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(section.displayHeading)
                .font(Theme.Fonts.cosySubheadline())
                .foregroundColor(Theme.Colors.cocoaBrown)

            if section.pageNumbers.isEmpty {
                Text("Page info unavailable")
                    .font(Theme.Fonts.cosyCaption())
                    .foregroundColor(Theme.Colors.softGray)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80), spacing: Theme.Spacing.xs)],
                    spacing: Theme.Spacing.xs
                ) {
                    ForEach(section.pageNumbers.sorted(), id: \.self) { page in
                        Button(action: { openManual(page) }) {
                            Text("Page \(page)")
                                .font(Theme.Fonts.cosyCaption())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                                .padding(.horizontal, Theme.Spacing.xs)
                                .padding(.vertical, Theme.Spacing.xxs)
                                .background(Theme.Colors.warmCream)
                                .cornerRadius(Theme.CornerRadius.small)
                        }
                        .cosyButtonPress()
                    }
                }
            }

            if !section.content.isEmpty {
                Text(section.content)
                    .font(Theme.Fonts.cosyBody())
                    .foregroundColor(Theme.Colors.cocoaBrown)
            }
        }
        .padding(Theme.Spacing.small)
        .background(Theme.Colors.cloudWhite)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
        )
    }
}

struct DetailRowValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(title)
                .font(Theme.Fonts.cosyCaption())
                .foregroundColor(Theme.Colors.mutedPlum)
                .textCase(.uppercase)
            Text(value.isEmpty ? "Not set" : value)
                .font(Theme.Fonts.cosyBody())
                .foregroundColor(value.isEmpty ? Theme.Colors.softGray : Theme.Colors.cocoaBrown)
        }
        .padding(Theme.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.warmCream.opacity(0.5))
        .cornerRadius(Theme.CornerRadius.small)
    }
}
