import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.allourhings.pdf", category: "SectionExtractor")

final class SectionExtractor {
    static let shared = SectionExtractor()
    private init() {}

    private struct SectionResponse: Codable {
        let heading: String
        let pageNumbers: [Int]
    }

    private struct PageText {
        let number: Int
        let text: String
    }

    func extractSections(from manualText: String, model: SystemLanguageModel) async -> [SectionData] {
        logger.info("🧩 [SectionExtractor] Starting AI section extraction")

        guard case .available = model.availability else {
            logger.warning("⚠️ [SectionExtractor] Model not available, skipping AI extraction")
            return []
        }

        let pages = parsePages(from: manualText)
        guard !pages.isEmpty else {
            logger.warning("⚠️ [SectionExtractor] No pages detected in manual text")
            return []
        }

        let maxPagesForAI = 80
        guard pages.count <= maxPagesForAI else {
            logger.warning("⚠️ [SectionExtractor] Manual too long for AI extraction (\(pages.count) pages)")
            return []
        }

        let instructions = """
        You are extracting section structure from a product manual.

        You will receive page excerpts labeled with "Page N:".
        Identify the manual's sections in order and return ONLY valid JSON.

        Requirements:
        - Use headings from the manual when possible.
        - Each section MUST include the page numbers it spans.
        - Return the full list of page numbers for each section.
        - Do not overlap sections; cover pages in order.
        - Use this exact JSON format:

        [
          {"heading": "Section Title", "pageNumbers": [1, 2, 3]}
        ]
        """

        let prompt = buildPrompt(from: pages)

        do {
            logger.info("🤖 [SectionExtractor] Creating section extraction session")
            let session = LanguageModelSession(tools: [], instructions: instructions)

            logger.info("🤖 [SectionExtractor] Waiting for model response...")
            let response = try await session.respond(to: prompt)
            logger.info("✅ [SectionExtractor] Received response (length: \(response.content.count))")

            let sections = parseSections(from: response.content)
            logger.info("✅ [SectionExtractor] Parsed \(sections.count) section definitions")

            let refinedSections = await refineSections(
                sections: sections,
                pages: pages,
                model: model
            )
            let finalSections = refinedSections.isEmpty ? sections : refinedSections

            let pageMap = Dictionary(uniqueKeysWithValues: pages.map { ($0.number, $0.text) })

            let sectionData = finalSections.compactMap { section -> SectionData? in
                let uniquePages = Array(Set(section.pageNumbers))
                    .sorted()
                    .filter { pageMap[$0] != nil }

                guard !uniquePages.isEmpty else { return nil }

                let content = uniquePages
                    .compactMap { pageMap[$0] }
                    .joined(separator: "\n")

                let heading = section.heading.trimmingCharacters(in: .whitespacesAndNewlines)
                return SectionData(heading: heading, content: content, pageNumbers: uniquePages, summary: "")
            }

            logger.info("✅ [SectionExtractor] Built \(sectionData.count) section(s)")
            return sectionData
        } catch {
            logger.error("❌ [SectionExtractor] Extraction failed: \(error.localizedDescription)")
            return []
        }
    }

    private func refineSections(
        sections: [SectionResponse],
        pages: [PageText],
        model: SystemLanguageModel
    ) async -> [SectionResponse] {
        guard !sections.isEmpty else {
            return []
        }

        let instructions = """
        You are refining a manual's section list into more coherent themes.

        Input is an ordered list of sections with headings, page numbers, and brief snippets.
        You may MERGE adjacent sections that clearly belong to the same topic.
        Do NOT reorder sections. Do NOT create new page numbers.

        Return ONLY valid JSON in this exact format:

        [
          {"heading": "Section Title", "pageNumbers": [1, 2, 3]}
        ]
        """

        let prompt = buildRefinementPrompt(from: sections, pages: pages)

        do {
            logger.info("🤖 [SectionExtractor] Creating section refinement session")
            let session = LanguageModelSession(tools: [], instructions: instructions)

            logger.info("🤖 [SectionExtractor] Waiting for refinement response...")
            let response = try await session.respond(to: prompt)
            logger.info("✅ [SectionExtractor] Received refinement response (length: \(response.content.count))")

            let refined = parseSections(from: response.content)
            logger.info("✅ [SectionExtractor] Parsed \(refined.count) refined sections")
            return refined
        } catch {
            logger.error("❌ [SectionExtractor] Refinement failed: \(error.localizedDescription)")
            return []
        }
    }

    private func parsePages(from text: String) -> [PageText] {
        let lines = text.components(separatedBy: "\n")
        var pages: [PageText] = []
        var currentNumber: Int?
        var currentLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if let pageNumber = extractPageNumber(from: trimmed) {
                if let number = currentNumber {
                    let pageText = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    pages.append(PageText(number: number, text: pageText))
                }
                currentNumber = pageNumber
                currentLines = []
            } else if currentNumber != nil {
                currentLines.append(line)
            }
        }

        if let number = currentNumber {
            let pageText = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            pages.append(PageText(number: number, text: pageText))
        }

        return pages
    }

    private func buildPrompt(from pages: [PageText]) -> String {
        let excerptLimit = 400

        let pageBlocks = pages.map { page -> String in
            let excerpt = String(page.text.prefix(excerptLimit))
            return """
            Page \(page.number):
            \(excerpt)
            """
        }

        return pageBlocks.joined(separator: "\n\n")
    }

    private func buildRefinementPrompt(from sections: [SectionResponse], pages: [PageText]) -> String {
        let pageMap = Dictionary(uniqueKeysWithValues: pages.map { ($0.number, $0.text) })
        let snippetLimit = 200

        let blocks = sections.enumerated().map { index, section -> String in
            let sortedPages = Array(Set(section.pageNumbers)).sorted()
            let snippets = sortedPages.compactMap { pageMap[$0] }.map { String($0.prefix(snippetLimit)) }
            let snippetText = snippets.joined(separator: " ")

            return """
            Section \(index + 1):
            Heading: \(section.heading)
            Pages: \(sortedPages.map(String.init).joined(separator: ", "))
            Snippet: \(snippetText)
            """
        }

        return blocks.joined(separator: "\n\n")
    }

    private func parseSections(from response: String) -> [SectionResponse] {
        var cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanedResponse.hasPrefix("```json") {
            cleanedResponse = cleanedResponse.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedResponse.hasPrefix("```") {
            cleanedResponse = cleanedResponse.replacingOccurrences(of: "```", with: "")
        }
        if cleanedResponse.hasSuffix("```") {
            cleanedResponse = String(cleanedResponse.dropLast(3))
        }
        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonStart = cleanedResponse.firstIndex(of: "["),
              let jsonEnd = cleanedResponse.lastIndex(of: "]") else {
            logger.warning("⚠️ [SectionExtractor] No JSON array found in response")
            return []
        }

        let jsonString = String(cleanedResponse[jsonStart...jsonEnd])

        do {
            guard let jsonData = jsonString.data(using: .utf8) else {
                logger.error("❌ [SectionExtractor] Failed to convert JSON string to Data")
                return []
            }

            let sections = try JSONDecoder().decode([SectionResponse].self, from: jsonData)
            return sections
        } catch {
            logger.error("❌ [SectionExtractor] JSON parsing failed: \(error.localizedDescription)")
            logger.debug("📝 [SectionExtractor] Failed JSON: \(jsonString)")
            return []
        }
    }

    private func extractPageNumber(from line: String) -> Int? {
        let pattern = "^Page (\\d+):$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }

        let pageNumberRange = match.range(at: 1)
        guard let pageRange = Range(pageNumberRange, in: line) else { return nil }

        return Int(String(line[pageRange]))
    }
}
