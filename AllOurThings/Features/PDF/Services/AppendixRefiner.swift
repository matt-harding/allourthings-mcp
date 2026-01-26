import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.allourhings.pdf", category: "AppendixRefiner")

final class AppendixRefiner {
    static let shared = AppendixRefiner()
    private init() {}

    private struct AppendixEntryDraft: Codable {
        let pageNumber: Int
        let heading: String
        let preview: String
    }

    private struct RefinedEntry: Codable {
        let pageNumber: Int
        let heading: String
    }

    func refineAppendix(
        _ sections: [SectionData],
        model: SystemLanguageModel,
        onProgress: ((Double) -> Void)? = nil
    ) async -> [SectionData] {
        guard case .available = model.availability else {
            logger.warning("⚠️ [AppendixRefiner] Model not available, skipping refinement")
            return sections
        }

        guard !sections.isEmpty else {
            return sections
        }

        let drafts = sections.map { section in
            AppendixEntryDraft(
                pageNumber: section.pageNumbers.first ?? 0,
                heading: section.heading,
                preview: String(section.content.prefix(160))
            )
        }

        let instructions = """
        You are refining appendix entries for a product manual.

        You will receive JSON entries with pageNumber, heading, and a short preview.
        For each entry, either:
        - KEEP: return a clearer, user-friendly heading
        - DROP: omit the entry if the heading is not useful for an appendix

        Rules:
        - Keep the original order by pageNumber.
        - Do NOT invent page numbers.
        - Headings should be short (<= 8 words) and easy to understand.
        - Be aggressive: remove entries that are blank, repetitive, legal boilerplate, tables of contents, indexes, or only page numbers.
        - Prefer concrete topics a user would look up (e.g., Setup, Safety, Cleaning).

        Return ONLY valid JSON in this format:
        [
          {"pageNumber": 3, "heading": "Setup Instructions"}
        ]
        """

        let batchSize = 10
        var refinedEntries: [RefinedEntry] = []
        refinedEntries.reserveCapacity(drafts.count)

        let batches = drafts.chunked(into: batchSize)
        for (index, batch) in batches.enumerated() {
            if let refined = await refineBatch(batch, instructions: instructions) {
                refinedEntries.append(contentsOf: refined)
            } else {
                // Fallback: keep originals for this batch
                refinedEntries.append(contentsOf: batch.map { RefinedEntry(pageNumber: $0.pageNumber, heading: $0.heading) })
            }

            let progress = Double(index + 1) / Double(max(1, batches.count))
            onProgress?(progress)
        }

        if refinedEntries.isEmpty {
            logger.warning("⚠️ [AppendixRefiner] No refined entries returned, keeping originals")
            return sections
        }

        let normalized = refinedEntries.compactMap { entry -> RefinedEntry? in
            let cleaned = normalizeHeading(entry.heading)
            guard isUsefulHeading(cleaned) else { return nil }
            return RefinedEntry(pageNumber: entry.pageNumber, heading: cleaned)
        }
        if normalized.isEmpty {
            logger.warning("⚠️ [AppendixRefiner] All refined entries filtered out, keeping originals")
            return sections
        }

        let refinedMap = buildRefinedMap(from: normalized)
        let ordered = sections.compactMap { section -> SectionData? in
            guard let page = section.pageNumbers.first else { return nil }
            guard let heading = refinedMap[page] else { return nil }
            var updated = section
            updated.heading = heading.trimmingCharacters(in: .whitespacesAndNewlines)
            return updated
        }

        return ordered.isEmpty ? sections : ordered
    }

    private func refineBatch(_ drafts: [AppendixEntryDraft], instructions: String) async -> [RefinedEntry]? {
        guard let payload = encodeDrafts(drafts) else {
            logger.error("❌ [AppendixRefiner] Failed to encode drafts")
            return nil
        }

        do {
            logger.info("🤖 [AppendixRefiner] Refining batch of \(drafts.count) appendix entries")
            let session = LanguageModelSession(tools: [], instructions: instructions)
            let response = try await session.respond(to: payload)
            let refined = parseRefinedEntries(from: response.content)
            return refined.isEmpty ? nil : refined
        } catch {
            logger.error("❌ [AppendixRefiner] Batch refinement failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func encodeDrafts(_ drafts: [AppendixEntryDraft]) -> String? {
        do {
            let data = try JSONEncoder().encode(drafts)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func parseRefinedEntries(from response: String) -> [RefinedEntry] {
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
            logger.warning("⚠️ [AppendixRefiner] No JSON array found in response")
            return []
        }

        let jsonString = String(cleaned[jsonStart...jsonEnd])

        do {
            guard let jsonData = jsonString.data(using: .utf8) else {
                logger.error("❌ [AppendixRefiner] Failed to convert JSON string to Data")
                return []
            }
            return try JSONDecoder().decode([RefinedEntry].self, from: jsonData)
        } catch {
            logger.error("❌ [AppendixRefiner] JSON parsing failed: \(error.localizedDescription)")
            return []
        }
    }

    private func normalizeHeading(_ text: String) -> String {
        let stripped = stripLeadingMarkers(text)
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let cleaned = stripped
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    private func stripLeadingMarkers(_ text: String) -> String {
        let pattern = "^[\\s\\-•–—*]+|^\\s*\\d+\\s*[\\.)\\-–—]+\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let stripped = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isUsefulHeading(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.count < 3 { return false }
        if trimmed.allSatisfy({ $0.isNumber }) { return false }

        let lowercased = trimmed.lowercased()
        let blocked = [
            "table of contents",
            "contents",
            "index",
            "notes",
            "notes page",
            "warranty",
            "legal",
            "disclaimer"
        ]
        if blocked.contains(where: { lowercased.contains($0) }) {
            return false
        }

        return true
    }

    private func buildRefinedMap(from entries: [RefinedEntry]) -> [Int: String] {
        var grouped: [Int: [String]] = [:]
        for entry in entries {
            grouped[entry.pageNumber, default: []].append(entry.heading)
        }

        var result: [Int: String] = [:]
        for (page, headings) in grouped {
            let unique = Array(Set(headings)).sorted()
            let combined = unique.joined(separator: " / ")
            result[page] = truncateHeading(combined)
        }

        return result
    }

    private func truncateHeading(_ text: String) -> String {
        let maxLength = 120
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        result.reserveCapacity((count + size - 1) / size)
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }
        return result
    }
}
