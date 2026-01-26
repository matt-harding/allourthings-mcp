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

        guard let firstLine = lines.first else {
            return "Page \(pageNumber)"
        }

        let maxLength = 80
        if firstLine.count <= maxLength {
            return firstLine
        }

        let trimmed = String(firstLine.prefix(maxLength))
        return trimmed + "..."
    }
}
