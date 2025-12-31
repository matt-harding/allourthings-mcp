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
