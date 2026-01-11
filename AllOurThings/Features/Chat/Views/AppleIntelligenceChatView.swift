import SwiftUI
import Foundation
import FoundationModels

@available(iOS 26.0, *)
struct AppleIntelligenceChatView: View {
    @Environment(\.modelContext) private var modelContext

    // Reference to the system language model
    @State private var model = SystemLanguageModel.default
    @State private var session: LanguageModelSession?

    // Chat state
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Apple Intelligence")
                    .font(Theme.Fonts.cosyTitle())
                    .foregroundColor(Theme.Colors.cocoaBrown)

                // Availability status indicator
                availabilityStatusView
            }
            .padding()
            .background(Theme.Colors.warmCream)

            Divider()
                .background(Theme.Colors.gentleBorder)

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
        .background(Theme.Colors.skyBlue)
        .onAppear {
            setupSession()
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

            Text("Ask me anything and I'll help using on-device Apple Intelligence")
                .font(Theme.Fonts.cosyBody())
                .foregroundColor(Theme.Colors.softGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
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
            TextField("Ask a question...", text: $inputText, axis: .vertical)
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
                Image(systemName: isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? Theme.Colors.blushPink : Theme.Colors.gentleBorder)
            }
            .disabled(!canSend && !isProcessing)
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
        You are a helpful AI assistant. Be concise and friendly in your responses.
        If you're unsure about something, say so rather than making up information.
        """

        session = LanguageModelSession(instructions: instructions)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        // Add user message
        let userMessage = ChatMessage(text: text, isUser: true)
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

                let response = try await session.respond(to: text)

                // Add AI response
                await MainActor.run {
                    let aiMessage = ChatMessage(text: response.content, isUser: false)
                    messages.append(aiMessage)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    let errorMsg = ChatMessage(
                        text: "Sorry, I encountered an error: \(error.localizedDescription)",
                        isUser: false
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
}

// MARK: - Chat Message Model

@available(iOS 26.0, *)
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Message Bubble

@available(iOS 26.0, *)
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(Theme.Fonts.cosyBody())
                    .foregroundColor(message.isUser ? .white : Theme.Colors.cocoaBrown)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Theme.Colors.blushPink : Theme.Colors.cloudWhite)
                    .cornerRadius(Theme.CornerRadius.large)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .stroke(message.isUser ? Color.clear : Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.thin)
                    )

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Fonts.cosyCaption())
                    .foregroundColor(Theme.Colors.softGray)
                    .padding(.horizontal, 4)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        AppleIntelligenceChatView()
    }
}
