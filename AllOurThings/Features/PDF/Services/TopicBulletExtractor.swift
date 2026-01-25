import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.allourhings.pdf", category: "TopicBulletExtractor")

struct TopicBulletDraft: Identifiable {
    let id = UUID()
    let text: String
    let pageNumber: Int
}

final class TopicBulletExtractor {
    static let shared = TopicBulletExtractor()
    private init() {}

    func generateBullets(
        sectionsByTopic: [ManualTopic: [SectionData]],
        model: SystemLanguageModel
    ) async -> [ManualTopic: [TopicBulletDraft]] {
        guard case .available = model.availability else {
            logger.warning("⚠️ [TopicBulletExtractor] Model not available, skipping bullets")
            return [:]
        }

        var results: [ManualTopic: [TopicBulletDraft]] = [:]
        let maxRetries = 2

        for topic in ManualTopic.allCases {
            guard let sections = sectionsByTopic[topic], !sections.isEmpty else { continue }

            let prompt = buildPrompt(topic: topic, sections: sections)
            let sourceText = buildSourceText(from: sections)
            let instructions = """
            You are summarizing manual sections into concise bullet points for the topic: \(topic.displayName).
            Write bullets that explain meaning in plain language, not headings or copied phrases.
            Do NOT copy more than 5 consecutive words from the manual text.
            Avoid section titles and avoid generic labels like "Instructions" or "Required".
            Return 3-6 bullet points, each 1 sentence and under 140 characters.
            Each bullet must include a single page number chosen from the provided sections.
            Use these topic-specific guidelines:
            \(topicGuidance(for: topic))
            Return ONLY valid JSON, no extra text.
            Format:
            [
              {"text": "bullet point", "page": 4}
            ]
            """

            var attempt = 0
            var accepted: [TopicBulletDraft] = []
            var lastParsed: [TopicBulletDraft] = []

            while attempt <= maxRetries && accepted.isEmpty {
                do {
                    logger.info("🤖 [TopicBulletExtractor] Generating bullets for \(topic.displayName) (attempt \(attempt + 1))")
                    let session = LanguageModelSession(tools: [], instructions: instructions)
                    let response = try await session.respond(to: prompt)
                    lastParsed = parseBullets(from: response.content)
                    accepted = filterValidBullets(lastParsed, sourceText: sourceText)
                } catch {
                    logger.error("❌ [TopicBulletExtractor] Bullets failed for \(topic.displayName): \(error.localizedDescription)")
                    break
                }

                attempt += 1
            }

            if accepted.isEmpty && !lastParsed.isEmpty {
                accepted = filterValidBullets(lastParsed, sourceText: sourceText, allowLooser: true)
            }

            results[topic] = accepted
            logger.info("✅ [TopicBulletExtractor] Generated \(accepted.count) bullets for \(topic.displayName)")
        }

        return results
    }

    private func buildPrompt(topic: ManualTopic, sections: [SectionData]) -> String {
        let formattedSections = sections.map { section in
            let content = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let contentPreview = String(content.prefix(1200))
            let pages = section.pageNumbers.sorted().map(String.init).joined(separator: ", ")
            return """
            Heading: \(section.heading)
            Pages: [\(pages)]
            Content:
            \(contentPreview)
            """
        }.joined(separator: "\n\n---\n\n")

        return """
        Topic: \(topic.displayName)

        \(formattedSections)
        """
    }

    private func buildSourceText(from sections: [SectionData]) -> String {
        sections.map { "\($0.heading) \($0.content)" }.joined(separator: " ")
    }

    private func parseBullets(from response: String) -> [TopicBulletDraft] {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
        }
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonStart = cleaned.firstIndex(of: "["),
              let jsonEnd = cleaned.lastIndex(of: "]") else {
            logger.warning("⚠️ [TopicBulletExtractor] No JSON array found in response")
            return []
        }

        let jsonString = String(cleaned[jsonStart...jsonEnd])

        struct BulletResponse: Codable {
            let text: String
            let page: Int
        }

        do {
            guard let jsonData = jsonString.data(using: .utf8) else {
                logger.error("❌ [TopicBulletExtractor] Failed to convert JSON string to Data")
                return []
            }

            let responses = try JSONDecoder().decode([BulletResponse].self, from: jsonData)
            return responses.compactMap { response in
                let trimmed = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return TopicBulletDraft(text: trimmed, pageNumber: response.page)
            }
        } catch {
            logger.error("❌ [TopicBulletExtractor] JSON parsing failed: \(error.localizedDescription)")
            return []
        }
    }

    private func topicGuidance(for topic: ManualTopic) -> String {
        switch topic {
        case .overview:
            return "Describe what the product is and what it is used for in plain terms."
        case .safety:
            return "Summarize key safety do's and don'ts a user should remember."
        case .setupInstallation:
            return "Explain placement, clearance, power/grounding, and initial setup steps."
        case .operationControls:
            return "Summarize how to operate key controls or modes in everyday language."
        case .maintenanceCleaning:
            return "Summarize routine cleaning and care steps, including what to avoid."
        case .troubleshooting:
            return "Summarize common issues and quick checks or fixes."
        case .specifications:
            return "Summarize essential technical details a user would compare."
        case .partsAccessories:
            return "Summarize included parts or compatible accessories."
        case .warrantySupport:
            return "Summarize support contacts, warranty scope, or service steps."
        }
    }

    private func filterValidBullets(
        _ bullets: [TopicBulletDraft],
        sourceText: String,
        allowLooser: Bool = false
    ) -> [TopicBulletDraft] {
        let normalizedSource = normalizeText(sourceText)
        return bullets.filter { bullet in
            let trimmed = bullet.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return false }
            if trimmed.count > 140 { return false }
            if !allowLooser && isLikelyHeading(trimmed) { return false }
            if !allowLooser && hasLongOverlap(trimmed, sourceText: normalizedSource) { return false }
            if !allowLooser && containsGenericLabel(trimmed) { return false }
            if sentenceCount(in: trimmed) > 1 { return false }
            return true
        }
    }

    private func normalizeText(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        return text
            .lowercased()
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasLongOverlap(_ bullet: String, sourceText: String) -> Bool {
        let normalizedBullet = normalizeText(bullet)
        let words = normalizedBullet.split(separator: " ").map(String.init)
        guard words.count >= 6 else { return false }

        for index in 0...(words.count - 6) {
            let phrase = words[index..<(index + 6)].joined(separator: " ")
            if sourceText.contains(phrase) {
                return true
            }
        }

        return false
    }

    private func isLikelyHeading(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        if words.count <= 4 {
            let titleCaseWords = words.filter { word in
                guard let first = word.first else { return false }
                return first.isUppercase
            }
            if titleCaseWords.count == words.count {
                return true
            }
        }

        let uppercased = text == text.uppercased()
        return uppercased && text.count <= 40
    }

    private func containsGenericLabel(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let blocked = [
            "instructions",
            "required",
            "overview",
            "manual",
            "section",
            "information"
        ]
        return blocked.contains { lowercased.contains($0) }
    }

    private func sentenceCount(in text: String) -> Int {
        let terminators = text.filter { ".!?".contains($0) }
        return max(1, terminators.count)
    }
}
