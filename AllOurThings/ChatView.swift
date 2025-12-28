import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    @State private var questionText = ""
    @State private var responses: [QuestionResponse] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
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
            .navigationTitle("Item Questions")
        }
    }

    private func askQuestion() {
        guard !questionText.isEmpty else { return }

        isLoading = true
        let question = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        questionText = ""

        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let answer = generateAnswer(for: question)
            let response = QuestionResponse(question: question, answer: answer)
            responses.append(response)
            isLoading = false
        }
    }

    private func generateAnswer(for question: String) -> String {
        let itemCount = items.count
        let questionLower = question.lowercased()

        // Basic question matching
        if questionLower.contains("how many") || questionLower.contains("count") {
            return "You have \(itemCount) items in your collection."
        }

        if questionLower.contains("kitchen") {
            let kitchenItems = items.filter { $0.category.lowercased().contains("kitchen") || $0.location.lowercased().contains("kitchen") }
            return "You have \(kitchenItems.count) kitchen items: \(kitchenItems.map { $0.name }.joined(separator: ", "))"
        }

        if questionLower.contains("warranty") {
            let itemsWithWarranty = items.filter { $0.warrantyExpirationDate != nil }
            if itemsWithWarranty.isEmpty {
                return "None of your items have warranty information recorded."
            } else {
                return "You have \(itemsWithWarranty.count) items with warranty information. Check the detail view for specific expiration dates."
            }
        }

        if questionLower.contains("manufacturer") || questionLower.contains("brand") {
            let manufacturers = Set(items.compactMap { $0.manufacturer.isEmpty ? nil : $0.manufacturer })
            if manufacturers.isEmpty {
                return "No manufacturer information is recorded for your items."
            } else {
                return "Your items are from these manufacturers: \(manufacturers.sorted().joined(separator: ", "))"
            }
        }

        if questionLower.contains("location") || questionLower.contains("where") {
            let locations = Set(items.compactMap { $0.location.isEmpty ? nil : $0.location })
            if locations.isEmpty {
                return "No location information is recorded for your items."
            } else {
                return "Your items are located in: \(locations.sorted().joined(separator: ", "))"
            }
        }

        // Default response
        return "I can help you with questions about your \(itemCount) items. Try asking about quantities, locations, warranties, or manufacturers."
    }
}

struct QuestionResponse: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let timestamp = Date()
}