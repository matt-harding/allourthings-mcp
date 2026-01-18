import Foundation
import PDFKit
import NaturalLanguage

// MARK: - PDF Text Extractor with Language Filtering

class PDFTextExtractor {
    static let shared = PDFTextExtractor()
    private init() {}

    // MARK: - Extract English Text from PDF

    func extractEnglishText(from url: URL) -> (text: String, stats: ExtractionStats)? {
        guard let document = PDFDocument(url: url) else {
            print("Failed to load PDF from: \(url)")
            return nil
        }

        var englishPages: [String] = []
        var stats = ExtractionStats()
        stats.totalPages = document.pageCount

        print("📄 Processing PDF: \(document.pageCount) pages")

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            guard let pageText = page.string else { continue }

            // Skip empty pages
            if pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stats.emptyPages += 1
                continue
            }

            // Detect language
            let language = detectLanguage(of: pageText)

            if language == .english {
                // Include page number with the text
                let pageNumber = pageIndex + 1
                let pageWithNumber = "Page \(pageNumber):\n\(pageText)"
                englishPages.append(pageWithNumber)
                stats.englishPages += 1
                print("✅ Page \(pageIndex + 1): English")
            } else {
                stats.nonEnglishPages += 1
                let langName = language?.rawValue ?? "unknown"
                print("⏭️  Page \(pageIndex + 1): \(langName) - skipped")
            }
        }

        // Combine English pages
        let combinedText = englishPages.joined(separator: "\n\n---\n\n")

        print("📊 Extraction complete:")
        print("   Total pages: \(stats.totalPages)")
        print("   English pages: \(stats.englishPages)")
        print("   Non-English pages: \(stats.nonEnglishPages)")
        print("   Empty pages: \(stats.emptyPages)")
        print("   Final text length: \(combinedText.count) characters")

        return (text: combinedText, stats: stats)
    }

    // MARK: - Language Detection

    private func detectLanguage(of text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()

        // Process the text
        recognizer.processString(text)

        // Get dominant language
        guard let language = recognizer.dominantLanguage else {
            return nil
        }

        return language
    }

    // MARK: - Helper: Get File Name

    func getFileName(from url: URL) -> String {
        return url.lastPathComponent
    }

    // MARK: - Extract Sections from English Text

    func extractSections(from text: String) -> [SectionData] {
        var sections: [SectionData] = []
        var currentSection: SectionData?
        var currentPageNumbers: Set<Int> = []

        // Split into lines
        let lines = text.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for page markers
            if let pageNum = extractPageNumber(from: trimmed) {
                currentPageNumbers.insert(pageNum)
                continue
            }

            // Check if line is a heading
            if isHeading(line: trimmed) {
                // Save previous section if exists AND it has content
                if var section = currentSection {
                    // Add any accumulated page numbers to the previous section
                    section.pageNumbers.append(contentsOf: currentPageNumbers)
                    // Remove duplicates and sort
                    section.pageNumbers = Array(Set(section.pageNumbers)).sorted()
                    sections.append(section)
                }

                // Start new section (page numbers will be collected as we go)
                currentSection = SectionData(
                    heading: trimmed,
                    content: "",
                    pageNumbers: []
                )
                // Keep the current page numbers for this new section
            } else if !trimmed.isEmpty {
                // Add content to current section
                if currentSection == nil {
                    // Create default section for content before first heading
                    currentSection = SectionData(
                        heading: "Introduction",
                        content: "",
                        pageNumbers: Array(currentPageNumbers).sorted()
                    )
                    currentPageNumbers.removeAll()
                }
                currentSection?.content += trimmed + "\n"
            }
        }

        // Add final section with remaining page numbers
        if var section = currentSection {
            section.pageNumbers.append(contentsOf: currentPageNumbers)
            // Remove duplicates and sort
            section.pageNumbers = Array(Set(section.pageNumbers)).sorted()
            sections.append(section)
        }

        // If no sections were found, create one section with all content
        if sections.isEmpty && !text.isEmpty {
            sections.append(SectionData(
                heading: "Manual Content",
                content: text,
                pageNumbers: []
            ))
        }

        print("📑 Extracted \(sections.count) sections")
        for (index, section) in sections.enumerated() {
            print("   Section \(index + 1): \(section.heading) - \(section.content.count) chars, pages: \(section.pageNumbers)")
        }

        return sections
    }

    // MARK: - Heading Detection

    private func isHeading(line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip very short or very long lines
        guard trimmed.count >= 3 && trimmed.count <= 100 else { return false }

        // Pattern 1: All caps (e.g., "CLEANING INSTRUCTIONS")
        let isAllCaps = trimmed == trimmed.uppercased() && trimmed.rangeOfCharacter(from: .letters) != nil

        // Pattern 2: Numbered sections (e.g., "1. Introduction", "1.1 Overview")
        let numberedPattern = "^\\d+\\.\\d*\\s+[A-Z]"
        let isNumbered = trimmed.range(of: numberedPattern, options: .regularExpression) != nil

        // Pattern 3: Common heading words
        let headingKeywords = [
            "introduction", "overview", "safety", "installation", "operation",
            "maintenance", "cleaning", "troubleshooting", "specifications",
            "warranty", "care", "instructions", "setup", "features", "usage",
            "getting started", "quick start", "important", "caution", "warning"
        ]
        let lowercased = trimmed.lowercased()
        let hasHeadingKeyword = headingKeywords.contains { lowercased.hasPrefix($0) || lowercased.contains($0) }

        // Pattern 4: Title case and relatively short
        let words = trimmed.components(separatedBy: .whitespaces)
        let isTitleCase = words.count <= 8 && words.allSatisfy { word in
            guard let first = word.first else { return false }
            return first.isUppercase || word.count <= 3  // Allow small words like "the", "and"
        }

        return isAllCaps || isNumbered || (hasHeadingKeyword && trimmed.count < 60) || isTitleCase
    }

    // MARK: - Extract Page Number from Line

    private func extractPageNumber(from line: String) -> Int? {
        // Match "Page X:" pattern
        let pattern = "^Page (\\d+):$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }

        let pageNumberRange = match.range(at: 1)
        guard let pageRange = Range(pageNumberRange, in: line) else { return nil }

        return Int(String(line[pageRange]))
    }
}

// MARK: - Extraction Statistics

struct ExtractionStats {
    var totalPages: Int = 0
    var englishPages: Int = 0
    var nonEnglishPages: Int = 0
    var emptyPages: Int = 0

    var summary: String {
        """
        Total: \(totalPages) pages
        English: \(englishPages) pages
        Other languages: \(nonEnglishPages) pages
        Empty: \(emptyPages) pages
        """
    }
}

// MARK: - Section Data

struct SectionData {
    var heading: String
    var content: String
    var pageNumbers: [Int]
}
