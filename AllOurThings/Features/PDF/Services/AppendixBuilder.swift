import Foundation

final class AppendixBuilder {
    static let shared = AppendixBuilder()
    private init() {}

    private struct PageText {
        let number: Int
        let text: String
    }

    func buildAppendix(from manualText: String) -> [SectionData] {
        let pages = parsePages(from: manualText)
        return pages.map { page in
            let heading = deriveHeading(from: page.text, pageNumber: page.number)
            return SectionData(heading: heading, content: page.text, pageNumbers: [page.number], summary: "")
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

    private func extractPageNumber(from line: String) -> Int? {
        let pattern = "^Page (\\d+):$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }

        let pageNumberRange = match.range(at: 1)
        guard let pageRange = Range(pageNumberRange, in: line) else { return nil }

        return Int(String(line[pageRange]))
    }

    private func deriveHeading(from pageText: String, pageNumber: Int) -> String {
        let lines = pageText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return "Page \(pageNumber)"
        }

        if let headingLine = lines.prefix(15).first(where: { isHeading(line: $0) }) {
            return truncateHeading(stripLeadingMarkers(headingLine))
        }

        return truncateHeading(stripLeadingMarkers(lines[0]))
    }

    private func truncateHeading(_ text: String) -> String {
        let maxLength = 80
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }

    private func isHeading(line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 && trimmed.count <= 100 else { return false }

        let isAllCaps = trimmed == trimmed.uppercased() && trimmed.rangeOfCharacter(from: .letters) != nil
        let numberedPattern = "^\\d+\\.\\d*\\s+[A-Z]"
        let isNumbered = trimmed.range(of: numberedPattern, options: .regularExpression) != nil

        let headingKeywords = [
            "introduction", "overview", "safety", "installation", "operation",
            "maintenance", "cleaning", "troubleshooting", "specifications",
            "warranty", "care", "instructions", "setup", "features", "usage",
            "getting started", "quick start", "important", "caution", "warning"
        ]
        let lowercased = trimmed.lowercased()
        let hasHeadingKeyword = headingKeywords.contains { lowercased.hasPrefix($0) || lowercased.contains($0) }

        let words = trimmed.components(separatedBy: .whitespaces)
        let isTitleCase = words.count <= 8 && words.allSatisfy { word in
            guard let first = word.first else { return false }
            return first.isUppercase || word.count <= 3
        }

        return isAllCaps || isNumbered || (hasHeadingKeyword && trimmed.count < 60) || isTitleCase
    }

    private func stripLeadingMarkers(_ text: String) -> String {
        let pattern = "^[\\s\\-•–—*]+|^\\s*\\d+\\s*[\\.)\\-–—]+\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let stripped = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
