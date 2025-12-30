import SwiftUI
import SwiftData
import FoundationModels

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    @State private var questionText = ""
    @State private var responses: [QuestionResponse] = []
    @State private var isLoading = false
    @State private var languageModelSession: Any?
    @State private var isFoundationModelsAvailable = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if !isFoundationModelsAvailable {
                    // Foundation Models not available message
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)

                        Text("Apple Intelligence Not Available")
                            .font(.headline)

                        Text("This chat feature requires Apple Intelligence and Foundation Models, which are not available on this device or iOS version.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Text("Requirements:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• iOS 26 or later")
                            Text("• Apple Intelligence enabled")
                            Text("• A17 Pro, M1, or newer chip")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    // Question input section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ask about your items")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack {
                            TextField("What would you like to know about your items?", text: $questionText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)

                            Button(action: askQuestion) {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(questionText.isEmpty || isLoading)
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    // Responses section
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(responses.reversed()) { response in
                                VStack(alignment: .leading, spacing: 8) {
                                    // Question
                                    HStack {
                                        Image(systemName: "person.circle")
                                            .foregroundColor(.blue)
                                        Text(response.question)
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }

                                    // Answer
                                    HStack {
                                        Image(systemName: "lightbulb")
                                            .foregroundColor(.orange)
                                        Text(response.answer)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }

                                    Text(response.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                    }

                    if responses.isEmpty && !isLoading {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Ask questions about your items")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Get help finding items, maintenance tips, or general information")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle("Item Questions")
        .onAppear {
            initializeLanguageModel()
        }
        }
    }

    private func askQuestion() {
        guard !questionText.isEmpty else { return }

        isLoading = true
        let question = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        questionText = ""

        Task {
            let answer = await generateAnswer(for: question)
            await MainActor.run {
                let response = QuestionResponse(question: question, answer: answer)
                responses.append(response)
                isLoading = false
            }
        }
    }

    private func initializeLanguageModel() {
        if #available(iOS 26.0, *) {
            languageModelSession = LanguageModelSession()
            isFoundationModelsAvailable = true
        } else {
            isFoundationModelsAvailable = false
        }
    }

    private func generateAnswer(for question: String) async -> String {
        guard #available(iOS 26.0, *) else {
            return "Apple Intelligence is not available on this device."
        }

        guard let session = languageModelSession as? LanguageModelSession else {
            return "Apple Intelligence is not available on this device."
        }

        // Build context about the user's items
        let itemsContext = buildItemsContext()

        let prompt = """
        You are a helpful assistant for a household item management app. The user has \(items.count) items in their collection.

        Here is information about their items:
        \(itemsContext)

        User question: \(question)

        Please provide a helpful, concise answer based on their actual items. If you need to reference specific items, use their exact names. Keep responses friendly and informative.
        """

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            // Check if this is a model assets error (common in simulator)
            let errorMessage = error.localizedDescription
            if errorMessage.contains("Model assets are unavailable") {
                return "Apple Intelligence is not available in the iOS Simulator. This feature requires a physical device with Apple Intelligence enabled (iPhone 15 Pro or newer with iOS 26+)."
            }
            return "Sorry, I couldn't process your question at this time. Error: \(errorMessage)"
        }
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
            return itemInfo
        }.joined(separator: "\n")
    }
}

struct QuestionResponse: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let timestamp = Date()
}
