import SwiftUI
import SwiftData
import Foundation
import FoundationModels

struct AppleIntelligenceChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    // Reference to the system language model
    @State private var model = SystemLanguageModel.default
    @State private var session: LanguageModelSession?

    // Chat state
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var pdfToShow: PDFViewerData?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content based on availability
                switch model.availability {
                case .available:
                    chatInterfaceView

                case .unavailable(.deviceNotEligible):
                    unavailableView(
                        icon: "xmark.circle.fill",
                        title: "Device Not Supported",
                        message: "Apple Intelligence requires a compatible device with Apple silicon."
                    )

                case .unavailable(.appleIntelligenceNotEnabled):
                    unavailableView(
                        icon: "gear.circle.fill",
                        title: "Apple Intelligence Not Enabled",
                        message: "Please enable Apple Intelligence in Settings to use this feature."
                    )

                case .unavailable(.modelNotReady):
                    unavailableView(
                        icon: "arrow.down.circle.fill",
                        title: "Model Not Ready",
                        message: "The model is downloading or preparing. Please try again in a few moments."
                    )

                case .unavailable(let other):
                    unavailableView(
                        icon: "exclamationmark.triangle.fill",
                        title: "Unavailable",
                        message: "Apple Intelligence is unavailable: \(String(describing: other))"
                    )
                }
            }
            .cosyGradientBackground(topColor: Theme.Colors.skyBlue.opacity(0.3), bottomColor: Theme.Colors.skyBlue)
            .navigationTitle("Item Questions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    availabilityStatusView
                }
            }
            .sheet(item: $pdfToShow) { pdfData in
                PDFViewerView(
                    pdfPath: pdfData.pdfPath,
                    pageNumber: pdfData.pageNumber,
                    itemName: pdfData.itemName
                )
            }
            .onAppear {
                setupSession()
            }
        }
    }

    // MARK: - Availability Status View

    private var availabilityStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(availabilityColor)
                .frame(width: 8, height: 8)

            Text(availabilityText)
                .font(Theme.Fonts.cosyCaption())
                .foregroundColor(Theme.Colors.softGray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.Colors.cloudWhite)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    private var availabilityColor: Color {
        switch model.availability {
        case .available:
            return .green
        case .unavailable(.modelNotReady):
            return .yellow
        default:
            return .red
        }
    }

    private var availabilityText: String {
        switch model.availability {
        case .available:
            return "Available"
        case .unavailable(.deviceNotEligible):
            return "Device Not Eligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Not Enabled"
        case .unavailable(.modelNotReady):
            return "Preparing..."
        case .unavailable:
            return "Unavailable"
        }
    }

    // MARK: - Chat Interface

    private var chatInterfaceView: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                emptyStateView
            } else {
                messageListView
            }

            Divider()
                .background(Theme.Colors.gentleBorder)

            inputArea
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.blushPink)

            Text("Start a conversation")
                .font(Theme.Fonts.cosyTitle())
                .foregroundColor(Theme.Colors.cocoaBrown)

            Text("Ask questions about your items and get helpful answers using on-device Apple Intelligence")
                .font(Theme.Fonts.cosyBody())
                .foregroundColor(Theme.Colors.softGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            onCitationTap: { url in
                                handleCitationTap(url: url, itemsWithManuals: message.itemsWithManuals)
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { oldValue, newValue in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("What would you like to know?", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.Fonts.cosyBody())
                .foregroundColor(Theme.Colors.cocoaBrown)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.Colors.cloudWhite)
                .cornerRadius(Theme.CornerRadius.large)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                        .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.thin)
                )
                .lineLimit(1...5)
                .disabled(isProcessing)

            Button(action: sendMessage) {
                if isProcessing {
                    ProgressView()
                        .tint(Theme.Colors.blushPink)
                } else {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                }
            }
            .frame(width: Constants.Dimensions.circularButtonSize, height: Constants.Dimensions.circularButtonSize)
            .background(canSend ? Theme.Colors.blushPink : Theme.Colors.softGray)
            .cornerRadius(22)
            .disabled(!canSend)
            .cosyButtonPress()
        }
        .padding()
        .background(Theme.Colors.warmCream)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    // MARK: - Unavailable View

    private func unavailableView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.softGray)

            Text(title)
                .font(Theme.Fonts.cosyTitle())
                .foregroundColor(Theme.Colors.cocoaBrown)

            Text(message)
                .font(Theme.Fonts.cosyBody())
                .foregroundColor(Theme.Colors.softGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if case .unavailable(.appleIntelligenceNotEnabled) = model.availability {
                Button(action: openSettings) {
                    Text("Open Settings")
                        .cosyButton(backgroundColor: Theme.Colors.blushPink)
                }
                .cosyButtonPress()
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Functions

    private func setupSession() {
        guard case .available = model.availability else { return }

        let instructions = """
        You are a helpful assistant for a household item management app.

        When answering questions using information from manual documentation:
        - Cite page numbers using format: (page X) or (pages X-Y)
        - Place citations immediately after relevant information
        - Example: "Set temperature to 60°C (page 12)"
        - Always cite specific page numbers when available in the manual text

        Be concise, helpful, and prioritize information from manual documentation when available.
        """

        session = LanguageModelSession(instructions: instructions)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        // Collect items with manuals
        let manualsRefs = items.compactMap { item -> ItemManualReference? in
            guard let filePath = item.manualFilePath else { return nil }
            return ItemManualReference(itemName: item.name, manualFilePath: filePath)
        }

        // Add user message
        let userMessage = ChatMessage(text: text, isUser: true, itemsWithManuals: manualsRefs)
        messages.append(userMessage)

        // Clear input
        inputText = ""
        isProcessing = true
        errorMessage = nil

        // Get response from model
        Task {
            do {
                guard let session = session else {
                    throw NSError(domain: "AppleIntelligenceChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
                }

                // Check if session is already responding
                if session.isResponding {
                    throw NSError(domain: "AppleIntelligenceChat", code: 2, userInfo: [NSLocalizedDescriptionKey: "Session is already processing a request"])
                }

                // Build context for this specific message
                let itemsContext = buildItemsContext(maxManualLength: 2000)
                let contextualPrompt = """
                Context: The user has \(items.count) items in their collection.

                \(itemsContext)

                User question: \(text)
                """

                let response = try await session.respond(to: contextualPrompt)

                // Add AI response
                await MainActor.run {
                    let aiMessage = ChatMessage(text: response.content, isUser: false, itemsWithManuals: manualsRefs)
                    messages.append(aiMessage)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    let errorMsg = ChatMessage(
                        text: "Sorry, I encountered an error: \(error.localizedDescription)",
                        isUser: false,
                        itemsWithManuals: []
                    )
                    messages.append(errorMsg)
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func buildItemsContext(maxManualLength: Int = 2000) -> String {
        guard !items.isEmpty else {
            return "The user has no items in their collection yet."
        }

        return items.map { item in
            buildItemContext(for: item, maxManualLength: maxManualLength)
        }.joined(separator: "\n")
    }

    private func buildItemContext(for item: Item, maxManualLength: Int) -> String {
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

        // Include manual text but limit its length
        if let manualText = item.manualText, !manualText.isEmpty {
            let truncatedManual = String(manualText.prefix(maxManualLength))
            let wasTruncated = manualText.count > maxManualLength
            itemInfo += "\n  Manual documentation:\n\(truncatedManual)"
            if wasTruncated {
                itemInfo += "\n  [Manual truncated for length...]"
            }
        }

        return itemInfo
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
            return
        }

        // Create PDF viewer data and present
        pdfToShow = PDFViewerData(
            pdfPath: firstManual.manualFilePath,
            pageNumber: pageNumber,
            itemName: firstManual.itemName
        )
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
    let itemsWithManuals: [ItemManualReference]
}

// MARK: - Supporting Structs

struct ItemManualReference {
    let itemName: String
    let manualFilePath: String
}

struct PDFViewerData: Identifiable {
    let id = UUID()
    let pdfPath: String
    let pageNumber: Int?
    let itemName: String
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let onCitationTap: (URL) -> Void

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if message.isUser {
                    // User message - plain text
                    Text(message.text)
                        .font(Theme.Fonts.cosyBody())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.blushPink)
                        .cornerRadius(Theme.CornerRadius.large)
                } else {
                    // AI message - parsed citations
                    Text(parseCitationsForMessage(message.text, itemsWithManuals: message.itemsWithManuals))
                        .font(Theme.Fonts.cosyBody())
                        .foregroundColor(Theme.Colors.cocoaBrown)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.cloudWhite)
                        .cornerRadius(Theme.CornerRadius.large)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .stroke(Theme.Colors.peach, lineWidth: Theme.BorderWidth.thick)
                        )
                        .environment(\.openURL, OpenURLAction { url in
                            onCitationTap(url)
                            return .handled
                        })
                }

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Fonts.cosyCaption())
                    .foregroundColor(Theme.Colors.softGray)
                    .padding(.horizontal, 4)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }

    private func parseCitationsForMessage(_ text: String, itemsWithManuals: [ItemManualReference]) -> AttributedString {
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
}

#Preview {
    AppleIntelligenceChatView()
}
