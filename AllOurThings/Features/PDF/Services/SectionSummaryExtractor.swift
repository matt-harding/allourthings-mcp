import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.allourhings.pdf", category: "SectionSummaryExtractor")

final class SectionSummaryExtractor {
    static let shared = SectionSummaryExtractor()
    private init() {}

    func summarizeSections(_ sections: [SectionData], model: SystemLanguageModel) async -> [SectionData] {
        guard case .available = model.availability else {
            logger.warning("⚠️ [SectionSummaryExtractor] Model not available, skipping summaries")
            return sections
        }

        var summarizedSections: [SectionData] = []
        summarizedSections.reserveCapacity(sections.count)

        let instructions = """
        You are summarizing a section of a product manual.
        Return a concise summary in 1-3 sentences.
        Avoid page numbers and avoid repeating the heading.
        """

        for section in sections {
            let content = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty {
                summarizedSections.append(section)
                continue
            }

            let trimmedContent = String(content.prefix(2000))
            let prompt = """
            Section Heading: \(section.heading)

            Section Content:
            \(trimmedContent)
            """

            do {
                logger.info("🤖 [SectionSummaryExtractor] Summarizing section: \(section.heading)")
                let session = LanguageModelSession(tools: [], instructions: instructions)
                let response = try await session.respond(to: prompt)
                let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

                logger.info("🧾 [SectionSummaryExtractor] Summary for '\(section.heading)': \(summary)")

                var updated = section
                updated.summary = summary
                summarizedSections.append(updated)
            } catch {
                logger.error("❌ [SectionSummaryExtractor] Summary failed: \(error.localizedDescription)")
                summarizedSections.append(section)
            }
        }

        return summarizedSections
    }
}
