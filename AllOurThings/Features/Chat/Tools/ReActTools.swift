import Foundation
import FoundationModels
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.allourhings.chat", category: "Tools")

// MARK: - Get Manual Section Tool

struct GetManualSectionTool: Tool {
    let modelContext: ModelContext

    var name: String { "get_manual_section" }

    var description: String {
        """
        Retrieves the full content of a specific manual section by item name and section heading.
        Use this after identifying a relevant section to get detailed information.
        Returns the complete section content with page numbers.
        """
    }

    @Generable
    struct Arguments {
        @Guide(description: "The name of the item")
        var itemName: String

        @Guide(description: "The heading of the manual section to retrieve")
        var sectionHeading: String

        @Guide(description: "Maximum number of characters to return from the section content")
        var maxChars: Int = 1200
    }

    func call(arguments: Arguments) async throws -> String {
        logger.info("📖 [GetManualSectionTool] Called with itemName: '\(arguments.itemName)', sectionHeading: '\(arguments.sectionHeading)'")

        // Find item
        let descriptor = FetchDescriptor<Item>()
        guard let items = try? modelContext.fetch(descriptor) else {
            logger.error("❌ [GetManualSectionTool] Error fetching items from database")
            return "Error fetching items from database."
        }

        guard let item = bestMatchingItem(for: arguments.itemName, in: items) else {
            logger.error("❌ [GetManualSectionTool] Item '\(arguments.itemName)' not found")
            return "Item '\(arguments.itemName)' not found."
        }

        logger.info("📖 [GetManualSectionTool] Found item: '\(item.name)'")

        // Fetch sections for this item
        let itemId = item.id
        var sectionDescriptor = FetchDescriptor<ManualSection>()
        sectionDescriptor.predicate = #Predicate { section in
            section.itemId == itemId
        }

        guard let sections = try? modelContext.fetch(sectionDescriptor) else {
            logger.error("❌ [GetManualSectionTool] Error fetching manual sections")
            return "Error fetching manual sections."
        }

        logger.info("📖 [GetManualSectionTool] Found \(sections.count) sections for item")

        // Find matching section
        guard let section = sections.first(where: {
            $0.heading.lowercased().contains(arguments.sectionHeading.lowercased())
        }) else {
            let availableSections = sections.map { $0.heading }.joined(separator: ", ")
            logger.error("❌ [GetManualSectionTool] Section '\(arguments.sectionHeading)' not found. Available: \(availableSections)")
            return "Section '\(arguments.sectionHeading)' not found. Available sections: \(availableSections)"
        }

        logger.info("📖 [GetManualSectionTool] Found section: '\(section.heading)' with \(section.content.count) characters")
        logger.info("📖 [GetManualSectionTool] Page numbers: \(section.pageNumbers)")

        // Format response to make page numbers very clear for citation
        let pageInfo = section.pageNumbers.isEmpty ? "Page information not available" : section.pageRange
        let response: String
        let maxChars = max(200, arguments.maxChars)
        let trimmedContent = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentPreview = trimmedContent.count > maxChars
            ? String(trimmedContent.prefix(maxChars)) + "\n\n[Content truncated for brevity]"
            : trimmedContent

        if contentPreview.isEmpty {
            // If content is empty, still return page information
            response = """
            Section: \(section.heading)
            \(pageInfo)

            [This section heading appears in the manual but detailed content was not extracted. Please refer to the manual at the pages listed above.]
            """
        } else {
            response = """
            Section: \(section.heading)
            \(pageInfo)

            \(contentPreview)
            """
        }

        logger.info("✅ [GetManualSectionTool] Returning section content")
        return response
    }
}

// MARK: - Search Item Manual Sections Tool

struct SearchItemManualSectionsTool: Tool {
    let modelContext: ModelContext
    let itemId: UUID
    let itemName: String

    var name: String { "search_item_manual_sections" }

    var description: String {
        """
        Searches manual sections for a specific item using semantic similarity.
        Use this for item-scoped questions so you don't need to guess the item name.
        Returns the most relevant sections with page numbers.
        """
    }

    @Generable
    struct Arguments {
        @Guide(description: "The search query to find relevant manual sections")
        var query: String

        @Guide(description: "Maximum number of results to return, defaults to 3 if not provided")
        var maxResults: Int = 3
    }

    func call(arguments: Arguments) async throws -> String {
        let maxResults = arguments.maxResults
        logger.info("🔎 [SearchItemManualSectionsTool] Called with query: '\(arguments.query)', maxResults: \(maxResults)")

        var sectionDescriptor = FetchDescriptor<ManualSection>()
        sectionDescriptor.predicate = #Predicate { section in
            section.itemId == itemId
        }

        guard let sections = try? modelContext.fetch(sectionDescriptor) else {
            logger.error("❌ [SearchItemManualSectionsTool] Error fetching manual sections")
            return "Error fetching manual sections for '\(itemName)'."
        }

        logger.info("🔎 [SearchItemManualSectionsTool] Total sections for item '\(itemName)': \(sections.count)")

        if sections.isEmpty {
            logger.warning("⚠️ [SearchItemManualSectionsTool] No manual sections available for item '\(itemName)'")
            return "Item '\(itemName)' has no manual sections available."
        }

        do {
            let results = try SemanticSearchHelper.shared.searchSections(
                query: arguments.query,
                in: sections,
                maxResults: maxResults,
                minSimilarity: 0.15
            )

            logger.info("🔎 [SearchItemManualSectionsTool] Found \(results.count) matching sections")

            if results.isEmpty {
                logger.warning("⚠️ [SearchItemManualSectionsTool] No relevant sections found")
                return "No relevant manual sections found for '\(itemName)' and query: '\(arguments.query)'"
            }

            let formattedResults = results.enumerated().map { index, scoredSection in
                let section = scoredSection.section
                let preview = String(section.content.prefix(200))

                logger.info("  ✓ Result \(index + 1): \(section.heading) (relevance: \(String(format: "%.1f%%", scoredSection.percentageScore)))")

                return """
                \(index + 1). \(section.heading)
                   \(section.pageRange)
                   Relevance: \(String(format: "%.1f%%", scoredSection.percentageScore))
                   Preview: \(preview)...
                """
            }.joined(separator: "\n\n")

            let response = "Found \(results.count) relevant section(s) in '\(itemName)':\n\n\(formattedResults)"
            logger.info("✅ [SearchItemManualSectionsTool] Returning response")
            return response
        } catch {
            logger.error("❌ [SearchItemManualSectionsTool] Error: \(error.localizedDescription)")
            return "Error searching sections: \(error.localizedDescription)"
        }
    }
}

// MARK: - Fuzzy Item Matching

private func bestMatchingItem(for query: String, in items: [Item]) -> Item? {
    let normalizedQuery = normalizeMatchString(query)
    if normalizedQuery.isEmpty {
        return nil
    }

    if let exact = items.first(where: { normalizeMatchString($0.name).contains(normalizedQuery) }) {
        return exact
    }

    var bestItem: Item?
    var bestDistance = Int.max

    for item in items {
        let candidate = normalizeMatchString(item.name)
        guard !candidate.isEmpty else { continue }
        let distance = levenshteinDistance(normalizedQuery, candidate)
        if distance < bestDistance {
            bestDistance = distance
            bestItem = item
        }
    }

    guard let match = bestItem else { return nil }
    let threshold = max(2, normalizedQuery.count / 3)
    return bestDistance <= threshold ? match : nil
}

private func normalizeMatchString(_ string: String) -> String {
    let allowed = CharacterSet.alphanumerics
    return string
        .lowercased()
        .unicodeScalars
        .filter { allowed.contains($0) }
        .map(String.init)
        .joined()
}

private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
    let left = Array(lhs)
    let right = Array(rhs)

    if left.isEmpty { return right.count }
    if right.isEmpty { return left.count }

    var distances = Array(0...right.count)

    for (i, leftChar) in left.enumerated() {
        var previous = distances[0]
        distances[0] = i + 1

        for (j, rightChar) in right.enumerated() {
            let current = distances[j + 1]
            if leftChar == rightChar {
                distances[j + 1] = previous
            } else {
                distances[j + 1] = min(previous, distances[j], current) + 1
            }
            previous = current
        }
    }

    return distances[right.count]
}
