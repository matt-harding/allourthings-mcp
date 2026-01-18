//
//  ItemChatView.swift
//  AllOurThings
//
//  Chat interface scoped to a single item
//

import SwiftUI
import SwiftData
import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.allourhings.chat", category: "ItemChatView")

struct ItemChatView: View {
    let item: Item
    @Environment(\.modelContext) private var modelContext

    // Reference to the system language model
    @State private var model = SystemLanguageModel()

    // State
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var session: LanguageModelSession?
    @State private var pdfToShow: PDFViewerData?

    var body: some View {
        VStack(spacing: 0) {
            // Availability status bar
            availabilityStatusView

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.small) {
                        ForEach(messages) { message in
                            ItemMessageBubble(
                                message: message,
                                onCitationTap: { url in
                                    handleCitationTap(url: url)
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(Theme.Spacing.medium)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input area
            inputArea
        }
        .background(Theme.Colors.skyBlue)
        .onAppear {
            setupSession()
        }
        .sheet(item: $pdfToShow) { pdfData in
            PDFViewerView(
                pdfPath: pdfData.pdfPath,
                pageNumber: pdfData.pageNumber,
                itemName: pdfData.itemName
            )
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var availabilityStatusView: some View {
        switch model.availability {
        case .available:
            EmptyView()

        case .unavailable(.modelNotReady):
            InfoBanner(
                text: "Apple Intelligence is preparing...",
                icon: "hourglass",
                color: Theme.Colors.butterYellow
            )

        case .unavailable(.appleIntelligenceNotEnabled):
            InfoBanner(
                text: "Enable Apple Intelligence in Settings to chat",
                icon: "exclamationmark.triangle",
                color: Theme.Colors.peach,
                action: ("Open Settings", openSettings)
            )

        case .unavailable(.deviceNotEligible):
            InfoBanner(
                text: "Apple Intelligence not available on this device",
                icon: "info.circle",
                color: Theme.Colors.softGray
            )

        case .unavailable:
            InfoBanner(
                text: "Apple Intelligence is not available",
                icon: "info.circle",
                color: Theme.Colors.softGray
            )
        }
    }

    private var inputArea: some View {
        HStack(spacing: Theme.Spacing.small) {
            TextField("Ask about \(item.name)...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.Fonts.cosyBody())
                .foregroundColor(Theme.Colors.cocoaBrown)
                .padding(Theme.Spacing.small)
                .background(Theme.Colors.cloudWhite)
                .cornerRadius(Theme.CornerRadius.large)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                        .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                )
                .disabled(!isModelAvailable || isProcessing)

            Button(action: sendMessage) {
                Image(systemName: isProcessing ? "hourglass" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isModelAvailable && !inputText.isEmpty && !isProcessing
                                     ? Theme.Colors.blushPink
                                     : Theme.Colors.softGray)
            }
            .disabled(!isModelAvailable || inputText.isEmpty || isProcessing)
            .cosyButtonPress()
        }
        .padding(Theme.Spacing.medium)
        .background(Theme.Colors.warmCream)
    }

    private var isModelAvailable: Bool {
        if case .available = model.availability {
            return true
        }
        return false
    }

    // MARK: - Functions

    private func setupSession() {
        print("========================================")
        print("🤖 SETUP SESSION CALLED FOR ITEM: \(item.name)")
        print("========================================")
        logger.info("🤖 [ItemChatView] Setting up session for item: '\(self.item.name)'")
        guard case .available = model.availability else {
            print("⚠️ Model not available")
            logger.warning("⚠️ [ItemChatView] Model not available, skipping session setup")
            return
        }

        // Build features context if available
        let featuresContext: String = {
            let features = item.features
            guard !features.isEmpty else { return "" }

            let capabilities = features
                .filter { $0.type == .capability }
                .map { "• \($0.text)" }
                .joined(separator: "\n")

            let specifications = features
                .filter { $0.type == .specification }
                .map { "• \($0.text)" }
                .joined(separator: "\n")

            var context = "\n\nKEY FEATURES OF \(item.name.uppercased()):\n"

            if !capabilities.isEmpty {
                context += "\nCapabilities:\n\(capabilities)\n"
            }

            if !specifications.isEmpty {
                context += "\nSpecifications:\n\(specifications)\n"
            }

            context += """

            These features are extracted from the manual. Reference them when relevant, but always \
            verify detailed usage instructions using the manual tools.
            """

            return context
        }()

        let instructions = """
        You are a helpful assistant for answering questions about a specific household item: \(item.name).
        \(featuresContext)

        You have access to tools to retrieve information from this item's manual:
        1. list_manual_sections - Lists available sections in the manual
        2. get_manual_section - Retrieves full content of a specific section
        3. search_manual_sections - Searches across all manual sections

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

        Be concise and helpful. Focus specifically on information about \(item.name).
        """

        // Create tools (only manual-related tools, no search_items needed)
        let tools: [any Tool] = [
            ListManualSectionsTool(modelContext: modelContext),
            GetManualSectionTool(modelContext: modelContext),
            SearchManualSectionsTool(modelContext: modelContext)
        ]

        logger.info("🤖 [ItemChatView] Created \(tools.count) tools for session")

        session = LanguageModelSession(tools: tools, instructions: instructions)
        logger.info("✅ [ItemChatView] Session setup complete for \(self.item.name)")
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        print("========================================")
        print("💬 SENDING MESSAGE: \(text)")
        print("========================================")
        logger.info("💬 [ItemChatView] Sending message: '\(text)'")

        // Collect manual reference for citation linking
        let manualRef: ItemManualReference? = {
            guard let filePath = item.manualFilePath else { return nil }
            return ItemManualReference(itemName: item.name, manualFilePath: filePath)
        }()

        let manualsRefs = manualRef.map { [$0] } ?? []
        logger.info("💬 [ItemChatView] Manual available: \(manualRef != nil)")

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
                    logger.error("❌ [ItemChatView] Session not initialized")
                    throw NSError(domain: "ItemChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
                }

                if session.isResponding {
                    logger.warning("⚠️ [ItemChatView] Session already responding")
                    throw NSError(domain: "ItemChat", code: 2, userInfo: [NSLocalizedDescriptionKey: "Session is already processing a request"])
                }

                logger.info("🤖 [ItemChatView] Waiting for response from model...")

                let response = try await session.respond(to: text)

                logger.info("✅ [ItemChatView] Received response (length: \(response.content.count))")
                logger.info("📝 [ItemChatView] Response: \(response.content)")

                await MainActor.run {
                    let aiMessage = ChatMessage(text: response.content, isUser: false, itemsWithManuals: manualsRefs)
                    messages.append(aiMessage)
                    isProcessing = false
                    logger.info("✅ [ItemChatView] Message processing complete")
                }
            } catch {
                logger.error("❌ [ItemChatView] Error: \(error.localizedDescription)")
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

    private func handleCitationTap(url: URL) {
        logger.info("🔗 [ItemChatView] Citation tapped: \(url)")

        guard url.scheme == "manual",
              url.host == "page",
              let pageString = url.pathComponents.last,
              let pageNumber = Int(pageString) else {
            logger.warning("⚠️ [ItemChatView] Invalid citation URL format")
            return
        }

        logger.info("🔗 [ItemChatView] Parsed page number: \(pageNumber)")

        guard let filePath = item.manualFilePath else {
            logger.warning("⚠️ [ItemChatView] No manual available to open")
            return
        }

        logger.info("📱 [ItemChatView] Opening PDF: \(item.name) at page \(pageNumber)")

        pdfToShow = PDFViewerData(
            pdfPath: filePath,
            pageNumber: pageNumber,
            itemName: item.name
        )
    }
}

// MARK: - Info Banner

struct InfoBanner: View {
    let text: String
    let icon: String
    let color: Color
    var action: (String, () -> Void)?

    var body: some View {
        HStack(spacing: Theme.Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(color)

            Text(text)
                .font(Theme.Fonts.cosyCaption())
                .foregroundColor(Theme.Colors.cocoaBrown)

            if let (label, callback) = action {
                Spacer()
                Button(action: callback) {
                    Text(label)
                        .font(Theme.Fonts.cosyCaption())
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.small)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Theme.Colors.blushPink)
                        .cornerRadius(Theme.CornerRadius.small)
                }
                .cosyButtonPress()
            }
        }
        .padding(Theme.Spacing.small)
        .background(color.opacity(0.2))
        .overlay(
            Rectangle()
                .frame(height: Theme.BorderWidth.thick)
                .foregroundColor(color),
            alignment: .bottom
        )
    }
}

// MARK: - Item Message Bubble

struct ItemMessageBubble: View {
    let message: ChatMessage
    let onCitationTap: (URL) -> Void

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: Theme.Spacing.xxs) {
                Text(parseCitationsForMessage(message.text, itemsWithManuals: message.itemsWithManuals))
                    .font(Theme.Fonts.cosyBody())
                    .foregroundColor(Theme.Colors.cocoaBrown)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Theme.Colors.blushPink.opacity(0.3) : Theme.Colors.cloudWhite)
                    .cornerRadius(Theme.CornerRadius.large)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .stroke(message.isUser ? Theme.Colors.blushPink : Theme.Colors.peach, lineWidth: Theme.BorderWidth.thick)
                    )
                    .environment(\.openURL, OpenURLAction { url in
                        onCitationTap(url)
                        return .handled
                    })

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

        let pattern = "\\(pages? (\\d+)(?:-(\\d+))?\\)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            logger.warning("⚠️ [MessageBubble] Failed to create regex for citation parsing")
            return attributedString
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        logger.info("📎 [MessageBubble] Found \(matches.count) citation(s) in message")

        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }

            let pageNumberRange = match.range(at: 1)
            guard let pageRange = Range(pageNumberRange, in: text) else { continue }
            let pageNumber = String(text[pageRange])

            logger.info("  ✓ Creating citation link for page \(pageNumber)")

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
    let item = Item(name: "Test Guitar", manufacturer: "Fender", modelNumber: "ST123", category: "Music", location: "Living Room", notes: "")
    return ItemChatView(item: item)
}
