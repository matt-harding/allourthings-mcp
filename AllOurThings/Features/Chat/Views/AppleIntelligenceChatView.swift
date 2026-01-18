import SwiftUI
import SwiftData
import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.allourhings.chat", category: "ChatView")

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
        print("========================================")
        print("🤖 SETUP SESSION CALLED")
        print("========================================")
        logger.info("🤖 [AppleIntelligenceChatView] Setting up session...")
        guard case .available = model.availability else {
            print("⚠️ Model not available")
            logger.warning("⚠️ [AppleIntelligenceChatView] Model not available, skipping session setup")
            return
        }

        let instructions = """
        You are a helpful assistant for a household item management app.

        You have access to tools to search and retrieve information from item manuals.

        When the user asks a question:
        1. Use list_manual_sections to see what documentation sections are available for items
        2. Use get_manual_section to retrieve specific section content
        3. Use search_manual_sections to find relevant information across all manuals

        CRITICAL CITATION RULES:
        - ALWAYS include page citations when referencing manual information
        - Use the exact format: (page X) or (pages X-Y) where X and Y are page numbers
        - Place citations immediately after the relevant information
        - Include citations even if the content is brief or just a heading
        - Examples:
          * "Clean with soft cloth (page 12)"
          * "Temperature should be 375°F (page 8)"
          * "For maintenance instructions, see the Care and Maintenance section (page 27)"

        If a tool returns page information, YOU MUST cite those pages in your response.
        Do not just reference sections without page numbers - always include the page numbers provided by the tools.

        Be concise and helpful. Use the tools systematically to find accurate information.
        """

        // Create tools
        let tools: [any Tool] = [
            ListManualSectionsTool(modelContext: modelContext),
            GetManualSectionTool(modelContext: modelContext),
            SearchManualSectionsTool(modelContext: modelContext)
        ]

        logger.info("🤖 [AppleIntelligenceChatView] Created \(tools.count) tools for session")
        logger.info("🤖 [AppleIntelligenceChatView] Current items count: \(items.count)")

        session = LanguageModelSession(tools: tools, instructions: instructions)
        logger.info("✅ [AppleIntelligenceChatView] Session setup complete")
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        print("========================================")
        print("💬 SENDING MESSAGE: \(text)")
        print("========================================")
        logger.info("💬 [AppleIntelligenceChatView] Sending message: '\(text)'")

        // Collect items with manuals (for citation linking)
        let manualsRefs = items.compactMap { item -> ItemManualReference? in
            guard let filePath = item.manualFilePath else { return nil }
            return ItemManualReference(itemName: item.name, manualFilePath: filePath)
        }

        logger.info("💬 [AppleIntelligenceChatView] Found \(manualsRefs.count) items with manual references")

        // Add user message
        let userMessage = ChatMessage(text: text, isUser: true, itemsWithManuals: manualsRefs)
        messages.append(userMessage)

        // Clear input
        inputText = ""
        isProcessing = true
        errorMessage = nil

        // Get response from model with tools
        Task {
            do {
                guard let session = session else {
                    logger.error("❌ [AppleIntelligenceChatView] Session not initialized")
                    throw NSError(domain: "AppleIntelligenceChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
                }

                // Check if session is already responding
                if session.isResponding {
                    logger.warning("⚠️ [AppleIntelligenceChatView] Session already responding")
                    throw NSError(domain: "AppleIntelligenceChat", code: 2, userInfo: [NSLocalizedDescriptionKey: "Session is already processing a request"])
                }

                logger.info("🤖 [AppleIntelligenceChatView] Waiting for response from model...")

                // Send message - session will automatically use tools as needed
                let response = try await session.respond(to: text)

                logger.info("✅ [AppleIntelligenceChatView] Received response (length: \(response.content.count))")
                logger.info("📝 [AppleIntelligenceChatView] Response: \(response.content)")

                // Add AI response
                await MainActor.run {
                    let aiMessage = ChatMessage(text: response.content, isUser: false, itemsWithManuals: manualsRefs)
                    messages.append(aiMessage)
                    isProcessing = false
                    logger.info("✅ [AppleIntelligenceChatView] Message processing complete")
                }
            } catch {
                logger.error("❌ [AppleIntelligenceChatView] Error: \(error.localizedDescription)")
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

    private func handleCitationTap(url: URL, itemsWithManuals: [ItemManualReference]) {
        logger.info("🔗 [AppleIntelligenceChatView] Citation tapped: \(url)")

        guard url.scheme == "manual",
              url.host == "page",
              let pageString = url.pathComponents.last,
              let pageNumber = Int(pageString) else {
            logger.warning("⚠️ [AppleIntelligenceChatView] Invalid citation URL format")
            return
        }

        logger.info("🔗 [AppleIntelligenceChatView] Parsed page number: \(pageNumber)")
        logger.info("🔗 [AppleIntelligenceChatView] Available manuals: \(itemsWithManuals.count)")

        // If only one manual, open it directly
        guard let firstManual = itemsWithManuals.first else {
            logger.warning("⚠️ [AppleIntelligenceChatView] No manuals available to open")
            return
        }

        logger.info("📱 [AppleIntelligenceChatView] Opening PDF: \(firstManual.itemName) at page \(pageNumber)")

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
            logger.warning("⚠️ [MessageBubble] Failed to create regex for citation parsing")
            return attributedString
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        logger.info("📎 [MessageBubble] Found \(matches.count) citation(s) in message")

        // Process matches in reverse to maintain correct indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }

            // Extract page number
            let pageNumberRange = match.range(at: 1)
            guard let pageRange = Range(pageNumberRange, in: text) else { continue }
            let pageNumber = String(text[pageRange])

            logger.info("  ✓ Creating citation link for page \(pageNumber)")

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
