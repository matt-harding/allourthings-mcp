import Foundation
import FoundationModels
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.allourhings.chat", category: "Tools")

// MARK: - Search Items Tool

struct SearchItemsTool: Tool {
    let items: [Item]

    var name: String { "search_items" }

    var description: String {
        """
        Searches through the user's item collection to find relevant items based on semantic similarity.
        Use this when the user asks about a specific item, category, or product.
        Returns item names, categories, and whether they have manuals.
        """
    }

    @Generable
    struct Arguments {
        @Guide(description: "The search query to find relevant items")
        var query: String

        @Guide(description: "Maximum number of results to return, defaults to 5 if not provided")
        var maxResults: Int = 5
    }

    func call(arguments: Arguments) async throws -> String {
        print("========================================")
        print("🔍 SEARCH ITEMS TOOL CALLED")
        print("Query: \(arguments.query)")
        print("Items count: \(items.count)")
        print("========================================")
        logger.info("🔍 [SearchItemsTool] Called with query: '\(arguments.query)', maxResults: \(arguments.maxResults)")
        logger.info("🔍 [SearchItemsTool] Total items available: \(items.count)")

        do {
            let results = try SemanticSearchHelper.shared.searchItems(
                query: arguments.query,
                in: items,
                maxResults: arguments.maxResults
            )

            logger.info("🔍 [SearchItemsTool] Found \(results.count) results")

            if results.isEmpty {
                logger.warning("⚠️ [SearchItemsTool] No results found")
                return "No relevant items found for query: '\(arguments.query)'"
            }

            let formattedResults = results.enumerated().map { index, scoredItem in
                let item = scoredItem.item
                let hasManual = item.manualText != nil && !item.manualText!.isEmpty
                logger.info("  ✓ Result \(index + 1): \(item.name) (relevance: \(String(format: "%.1f%%", scoredItem.percentageScore)), hasManual: \(hasManual))")
                return """
                \(index + 1). \(item.name)
                   Category: \(item.category.isEmpty ? "Uncategorized" : item.category)
                   Manufacturer: \(item.manufacturer.isEmpty ? "Unknown" : item.manufacturer)
                   Location: \(item.location.isEmpty ? "Unknown" : item.location)
                   Has Manual: \(hasManual ? "Yes" : "No")
                   Relevance: \(String(format: "%.1f%%", scoredItem.percentageScore))
                """
            }.joined(separator: "\n\n")

            let response = "Found \(results.count) relevant item(s):\n\n\(formattedResults)"
            logger.info("✅ [SearchItemsTool] Returning response")
            return response
        } catch {
            logger.error("❌ [SearchItemsTool] Error: \(error.localizedDescription)")
            return "Error searching items: \(error.localizedDescription)"
        }
    }
}

// MARK: - List Manual Sections Tool

struct ListManualSectionsTool: Tool {
    let modelContext: ModelContext

    var name: String { "list_manual_sections" }

    var description: String {
        """
        Lists all available manual sections for a specific item by name.
        Use this after finding an item with search_items to see what documentation sections are available.
        Returns section headings and page numbers.
        """
    }

    @Generable
    struct Arguments {
        @Guide(description: "The name of the item to list manual sections for")
        var itemName: String
    }

    func call(arguments: Arguments) async throws -> String {
        logger.info("📋 [ListManualSectionsTool] Called with itemName: '\(arguments.itemName)'")

        // Find item
        let descriptor = FetchDescriptor<Item>()
        guard let items = try? modelContext.fetch(descriptor) else {
            logger.error("❌ [ListManualSectionsTool] Error fetching items from database")
            return "Error fetching items from database."
        }

        logger.info("📋 [ListManualSectionsTool] Total items in database: \(items.count)")

        guard let item = items.first(where: {
            $0.name.lowercased().contains(arguments.itemName.lowercased())
        }) else {
            logger.error("❌ [ListManualSectionsTool] Item '\(arguments.itemName)' not found")
            return "Item '\(arguments.itemName)' not found."
        }

        logger.info("📋 [ListManualSectionsTool] Found item: '\(item.name)'")

        // Fetch sections for this item
        let itemId = item.id
        var sectionDescriptor = FetchDescriptor<ManualSection>(
            sortBy: [SortDescriptor(\.sectionIndex)]
        )
        sectionDescriptor.predicate = #Predicate { section in
            section.itemId == itemId
        }

        guard let sections = try? modelContext.fetch(sectionDescriptor) else {
            logger.error("❌ [ListManualSectionsTool] Error fetching manual sections")
            return "Error fetching manual sections."
        }

        logger.info("📋 [ListManualSectionsTool] Found \(sections.count) sections for item")

        if sections.isEmpty {
            logger.warning("⚠️ [ListManualSectionsTool] No manual sections available for '\(item.name)'")
            return "Item '\(item.name)' has no manual sections available."
        }

        let sectionList = sections.enumerated().map { index, section in
            logger.info("  ✓ Section \(index + 1): \(section.displayHeading) (\(section.pageRange))")
            return "\(index + 1). \(section.displayHeading) (\(section.pageRange))"
        }.joined(separator: "\n")

        let response = "Manual sections for '\(item.name)' (\(sections.count) sections):\n\(sectionList)"
        logger.info("✅ [ListManualSectionsTool] Returning response")
        return response
    }
}

// MARK: - Get Manual Section Tool

struct GetManualSectionTool: Tool {
    let modelContext: ModelContext

    var name: String { "get_manual_section" }

    var description: String {
        """
        Retrieves the full content of a specific manual section by item name and section heading.
        Use this after listing sections with list_manual_sections to get detailed information.
        Returns the complete section content with page numbers.
        """
    }

    @Generable
    struct Arguments {
        @Guide(description: "The name of the item")
        var itemName: String

        @Guide(description: "The heading of the manual section to retrieve")
        var sectionHeading: String
    }

    func call(arguments: Arguments) async throws -> String {
        logger.info("📖 [GetManualSectionTool] Called with itemName: '\(arguments.itemName)', sectionHeading: '\(arguments.sectionHeading)'")

        // Find item
        let descriptor = FetchDescriptor<Item>()
        guard let items = try? modelContext.fetch(descriptor) else {
            logger.error("❌ [GetManualSectionTool] Error fetching items from database")
            return "Error fetching items from database."
        }

        guard let item = items.first(where: {
            $0.name.lowercased().contains(arguments.itemName.lowercased())
        }) else {
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

        let response = """
        Section: \(section.heading)
        \(section.pageRange)

        \(section.content)
        """
        logger.info("✅ [GetManualSectionTool] Returning section content")
        return response
    }
}

// MARK: - Search Manual Sections Tool

struct SearchManualSectionsTool: Tool {
    let modelContext: ModelContext

    var name: String { "search_manual_sections" }

    var description: String {
        """
        Searches through ALL manual sections across all items using semantic similarity.
        Use this when you need to find specific information across multiple manuals.
        Returns the most relevant sections with their item names and page numbers.
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
        logger.info("🔎 [SearchManualSectionsTool] Called with query: '\(arguments.query)', maxResults: \(maxResults)")

        // Fetch all manual sections
        let descriptor = FetchDescriptor<ManualSection>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        guard let allSections = try? modelContext.fetch(descriptor) else {
            logger.error("❌ [SearchManualSectionsTool] Error fetching manual sections")
            return "Error fetching manual sections."
        }

        logger.info("🔎 [SearchManualSectionsTool] Total sections in database: \(allSections.count)")

        if allSections.isEmpty {
            logger.warning("⚠️ [SearchManualSectionsTool] No manual sections available")
            return "No manual sections available in the database."
        }

        // Search sections
        do {
            let results = try SemanticSearchHelper.shared.searchSections(
                query: arguments.query,
                in: allSections,
                maxResults: maxResults
            )

            logger.info("🔎 [SearchManualSectionsTool] Found \(results.count) matching sections")

            if results.isEmpty {
                logger.warning("⚠️ [SearchManualSectionsTool] No relevant sections found")
                return "No relevant manual sections found for query: '\(arguments.query)'"
            }

            // Need to get item names - fetch all items
            let itemDescriptor = FetchDescriptor<Item>()
            let items = (try? modelContext.fetch(itemDescriptor)) ?? []
            let itemsDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })

            let formattedResults = results.enumerated().map { index, scoredSection in
                let section = scoredSection.section
                let itemName = itemsDict[section.itemId] ?? "Unknown Item"
                let preview = String(section.content.prefix(200))

                logger.info("  ✓ Result \(index + 1): \(section.heading) from '\(itemName)' (relevance: \(String(format: "%.1f%%", scoredSection.percentageScore)))")

                return """
                \(index + 1). \(section.heading) (from \(itemName))
                   \(section.pageRange)
                   Relevance: \(String(format: "%.1f%%", scoredSection.percentageScore))
                   Preview: \(preview)...
                """
            }.joined(separator: "\n\n")

            let response = "Found \(results.count) relevant section(s):\n\n\(formattedResults)"
            logger.info("✅ [SearchManualSectionsTool] Returning response")
            return response
        } catch {
            logger.error("❌ [SearchManualSectionsTool] Error: \(error.localizedDescription)")
            return "Error searching sections: \(error.localizedDescription)"
        }
    }
}
