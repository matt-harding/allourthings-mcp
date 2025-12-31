import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    @State private var questionText = ""
    @State private var responses: [QuestionResponse] = []
    @State private var isLoading = false
    @State private var hasAPIKey = false
    @State private var showingSettings = false
    @State private var showingPDF = false
    @State private var selectedPDFPath: String?
    @State private var selectedPageNumber: Int?
    @State private var selectedItemName: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !hasAPIKey {
                    // No API Key message
                    VStack(spacing: Theme.Spacing.large) {
                        VStack(spacing: Theme.Spacing.medium) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Theme.Colors.blushPink)

                            Text("API Key Required")
                                .font(Theme.Fonts.cosyLargeTitle())
                                .foregroundColor(Theme.Colors.cocoaBrown)

                            Text("Add your Gemini API key to enable AI chat about your items.")
                                .font(Theme.Fonts.cosyBody())
                                .multilineTextAlignment(.center)
                                .foregroundColor(Theme.Colors.softGray)
                        }
                        .padding(Theme.Spacing.xl)
                        .background(Theme.Colors.warmCream)
                        .cornerRadius(Theme.CornerRadius.large)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .stroke(Theme.Colors.blushPink, lineWidth: Theme.BorderWidth.thick)
                        )
                        .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)

                        Button(action: { showingSettings = true }) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Open Settings")
                            }
                            .font(Theme.Fonts.cosyButton())
                            .foregroundColor(.white)
                            .padding(.horizontal, Theme.Spacing.large)
                            .padding(.vertical, Theme.Spacing.small)
                            .background(Theme.Colors.blushPink)
                            .cornerRadius(Theme.CornerRadius.xl)
                            .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                                    .stroke(Theme.Colors.cocoaBrown.opacity(0.3), lineWidth: Theme.BorderWidth.thin)
                            )
                        }
                        .cosyButtonPress()
                    }
                    .padding(Theme.Spacing.medium)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Responses section
                    if responses.isEmpty && !isLoading {
                        // Empty state with magical atmosphere
                        VStack(spacing: Theme.Spacing.medium) {
                            ZStack {
                                // Decorative stars in background
                                ForEach(0..<8, id: \.self) { index in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Theme.Colors.butterYellow.opacity(0.05))
                                        .offset(
                                            x: CGFloat.random(in: -150...150),
                                            y: CGFloat.random(in: -150...150)
                                        )
                                }

                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(Theme.Colors.softLavender)
                            }

                            Text("Let's Chat!")
                                .font(Theme.Fonts.cosyLargeTitle())
                                .foregroundColor(Theme.Colors.cocoaBrown)

                            Text("Ask questions about your items and get helpful answers")
                                .font(Theme.Fonts.cosyBody())
                                .foregroundColor(Theme.Colors.softGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.Spacing.xl)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Theme.Spacing.medium) {
                                ForEach(responses.reversed()) { response in
                                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                        // User question bubble
                                        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                            Image(systemName: "person.crop.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Theme.Colors.softLavender)

                                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                                Text(response.question)
                                                    .font(Theme.Fonts.cosyBody())
                                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                            }
                                            .padding(Theme.Spacing.small)
                                            .background(Theme.Colors.blushPink.opacity(0.85))
                                            .cornerRadius(Theme.CornerRadius.large)
                                            .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                                    .stroke(Theme.Colors.blushPink, lineWidth: Theme.BorderWidth.standard)
                                            )
                                            .frame(maxWidth: .infinity * 0.75, alignment: .leading)
                                        }
                                        .padding(.horizontal, Theme.Spacing.medium)

                                        // AI answer bubble
                                        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                            Spacer()
                                                .frame(width: 30)

                                            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(Theme.Colors.peach)

                                                Text(parseCitations(response.answer, itemsWithManuals: response.itemsWithManuals))
                                                    .font(Theme.Fonts.cosyBody())
                                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                                    .environment(\.openURL, OpenURLAction { url in
                                                        handleCitationTap(url: url, itemsWithManuals: response.itemsWithManuals)
                                                        return .handled
                                                    })
                                            }
                                            .padding(Theme.Spacing.small)
                                            .background(Theme.Colors.cloudWhite)
                                            .cornerRadius(Theme.CornerRadius.large)
                                            .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                                    .stroke(Theme.Colors.peach, lineWidth: Theme.BorderWidth.thick)
                                            )
                                            .frame(maxWidth: .infinity * 0.75, alignment: .leading)
                                        }
                                        .padding(.horizontal, Theme.Spacing.medium)

                                        // Timestamp
                                        Text(response.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(Theme.Fonts.cosyCaption())
                                            .foregroundColor(Theme.Colors.softGray)
                                            .padding(.horizontal, Theme.Spacing.medium)
                                            .padding(.trailing, Theme.Spacing.xl)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                            }
                            .padding(.vertical, Theme.Spacing.medium)
                        }
                    }

                    // Input section at bottom
                    VStack(spacing: 0) {
                        Divider()
                            .background(Theme.Colors.gentleBorder)

                        HStack(spacing: Theme.Spacing.small) {
                            TextField("What would you like to know?", text: $questionText, axis: .vertical)
                                .font(Theme.Fonts.cosyBody())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                                .padding(Theme.Spacing.small)
                                .background(Theme.Colors.warmCream)
                                .cornerRadius(Theme.CornerRadius.xl)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                                        .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                                )
                                .lineLimit(1...3)

                            Button(action: askQuestion) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(questionText.isEmpty || isLoading ? Theme.Colors.softGray : Theme.Colors.blushPink)
                            .cornerRadius(22)
                            .disabled(questionText.isEmpty || isLoading)
                            .cosyButtonPress()
                        }
                        .padding(Theme.Spacing.medium)
                        .background(Theme.Colors.cloudWhite)
                        .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 0, y: -3)
                        .overlay(
                            Rectangle()
                                .fill(Theme.Colors.gentleBorder)
                                .frame(height: Theme.BorderWidth.thin)
                                .frame(maxHeight: .infinity, alignment: .top)
                        )
                    }
                }
            }
            .cosyGradientBackground(topColor: Theme.Colors.skyBlue.opacity(0.3), bottomColor: Theme.Colors.skyBlue)
            .navigationTitle("Item Questions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Theme.Colors.blushPink)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingPDF) {
                if let pdfPath = selectedPDFPath, let itemName = selectedItemName {
                    PDFViewerView(
                        pdfPath: pdfPath,
                        pageNumber: selectedPageNumber,
                        itemName: itemName
                    )
                }
            }
            .onAppear {
                checkAPIKey()
            }
        }
    }

    private func askQuestion() {
        guard !questionText.isEmpty else { return }

        isLoading = true
        let question = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        questionText = ""

        // Collect items with manuals
        let manualsRefs = items.compactMap { item -> ItemManualReference? in
            guard let filePath = item.manualFilePath else { return nil }
            return ItemManualReference(itemName: item.name, manualFilePath: filePath)
        }

        Task {
            let answer = await generateAnswer(for: question)
            await MainActor.run {
                let response = QuestionResponse(
                    question: question,
                    answer: answer,
                    itemsWithManuals: manualsRefs
                )
                responses.append(response)
                isLoading = false
            }
        }
    }

    private func checkAPIKey() {
        hasAPIKey = KeychainHelper.shared.hasGeminiKey()
    }

    private func generateAnswer(for question: String) async -> String {
        // Build context about the user's items
        let itemsContext = buildItemsContext()

        let prompt = """
        You are a helpful assistant for a household item management app. The user has \(items.count) items in their collection.

        Here is information about their items:
        \(itemsContext)

        User question: \(question)

        Please provide a helpful, concise answer based on their actual items. If you need to reference specific items, use their exact names. Keep responses friendly and informative.

        IMPORTANT: Some items include detailed manual documentation with page numbers (e.g., "Page 5:"). When answering questions using information from the manual:
        1. Cite the page number inline using the format: (page X)
        2. Place the citation immediately after the relevant information
        3. Example: "The recommended temperature is 60°C (page 12)."
        4. Always cite specific page numbers when available in the manual text
        5. If information spans multiple pages, cite all relevant pages: (pages 5-7)

        Prioritize information from manual documentation over general knowledge when available.
        """

        do {
            let response = try await GeminiService.shared.generateResponse(prompt: prompt)
            return response
        } catch {
            return "Sorry, I couldn't process your question. Error: \(error.localizedDescription)"
        }
    }

    private func parseCitations(_ text: String, itemsWithManuals: [ItemManualReference]) -> AttributedString {
        var attributedString = AttributedString(text)

        // Pattern to match (page X) or (pages X-Y) or (page X-Y)
        let pattern = "\\(pages? (\\d+)(?:-(\\d+))?\\)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return attributedString
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        // Process matches in reverse to maintain correct indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }

            // Extract page number
            let citationText = String(text[range])
            let pageNumberRange = match.range(at: 1)
            guard let pageRange = Range(pageNumberRange, in: text) else { continue }
            let pageNumber = String(text[pageRange])

            // Create link URL with custom scheme
            if let attrRange = Range(range, in: attributedString) {
                attributedString[attrRange].foregroundColor = Theme.Colors.blushPink
                attributedString[attrRange].underlineStyle = .single
                attributedString[attrRange].link = URL(string: "manual://page/\(pageNumber)")
            }
        }

        return attributedString
    }

    private func handleCitationTap(url: URL, itemsWithManuals: [ItemManualReference]) {
        guard url.scheme == "manual",
              url.host == "page",
              let pageString = url.pathComponents.last,
              let pageNumber = Int(pageString) else {
            return
        }

        // If only one manual, open it directly
        guard let firstManual = itemsWithManuals.first else {
            print("No manuals available")
            return
        }

        selectedPDFPath = firstManual.manualFilePath
        selectedPageNumber = pageNumber
        selectedItemName = firstManual.itemName
        showingPDF = true
    }

    private func buildItemsContext() -> String {
        if items.isEmpty {
            return "The user has no items in their collection yet."
        }

        return items.map { item in
            var itemInfo = "- \(item.name)"
            if !item.category.isEmpty {
                itemInfo += " (Category: \(item.category))"
            }
            if !item.manufacturer.isEmpty {
                itemInfo += " by \(item.manufacturer)"
            }
            if !item.location.isEmpty {
                itemInfo += " located in \(item.location)"
            }
            if let warrantyDate = item.warrantyExpirationDate {
                itemInfo += " (Warranty expires: \(warrantyDate.formatted(date: .abbreviated, time: .omitted)))"
            }
            if !item.notes.isEmpty {
                itemInfo += " (Notes: \(item.notes))"
            }
            if let manualText = item.manualText, !manualText.isEmpty {
                itemInfo += "\n  Manual documentation:\n\(manualText)"
            }
            return itemInfo
        }.joined(separator: "\n")
    }
}

struct QuestionResponse: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let timestamp = Date()
    let itemsWithManuals: [ItemManualReference]
}

struct ItemManualReference {
    let itemName: String
    let manualFilePath: String
}
