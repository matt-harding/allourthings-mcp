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
            VStack(spacing: 0) {
                if !isFoundationModelsAvailable {
                    // Foundation Models not available message
                    VStack(spacing: Theme.Spacing.medium) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Theme.Colors.peach)

                        Text("Apple Intelligence Not Available")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.cocoaBrown)

                        Text("This chat feature requires Apple Intelligence and Foundation Models, which are not available on this device or iOS version.")
                            .font(Theme.Fonts.cosyBody())
                            .multilineTextAlignment(.center)
                            .foregroundColor(Theme.Colors.softGray)

                        Text("Requirements:")
                            .font(Theme.Fonts.cosySubheadline())
                            .foregroundColor(Theme.Colors.cocoaBrown)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("• iOS 26 or later")
                            Text("• Apple Intelligence enabled")
                            Text("• A17 Pro, M1, or newer chip")
                        }
                        .font(Theme.Fonts.cosyCaption())
                        .foregroundColor(Theme.Colors.softGray)
                    }
                    .padding(Theme.Spacing.xl)
                    .background(Theme.Colors.warmCream)
                    .cornerRadius(Theme.CornerRadius.large)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .stroke(Theme.Colors.peach, lineWidth: Theme.BorderWidth.thick)
                    )
                    .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
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

                                                Text(response.answer)
                                                    .font(Theme.Fonts.cosyBody())
                                                    .foregroundColor(Theme.Colors.cocoaBrown)
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
