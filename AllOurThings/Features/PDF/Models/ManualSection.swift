import Foundation
import SwiftData

// MARK: - Manual Section Model

@Model
final class ManualSection {
    var id: UUID
    var itemId: UUID  // Reference to parent Item
    var heading: String
    var content: String
    var pageNumbers: [Int]  // Pages this section appears on
    var sectionIndex: Int  // Order in the manual
    var fileName: String?  // Optional: file path if stored separately
    var timestamp: Date

    init(
        itemId: UUID,
        heading: String,
        content: String,
        pageNumbers: [Int],
        sectionIndex: Int,
        fileName: String? = nil
    ) {
        self.id = UUID()
        self.itemId = itemId
        self.heading = heading
        self.content = content
        self.pageNumbers = pageNumbers
        self.sectionIndex = sectionIndex
        self.fileName = fileName
        self.timestamp = Date()
    }

    // MARK: - Computed Properties

    var displayHeading: String {
        heading.isEmpty ? "Section \(sectionIndex + 1)" : heading
    }

    var pageRange: String {
        guard !pageNumbers.isEmpty else { return "N/A" }
        if pageNumbers.count == 1 {
            return "Page \(pageNumbers[0])"
        } else {
            let sorted = pageNumbers.sorted()
            return "Pages \(sorted.first!)-\(sorted.last!)"
        }
    }

    var summary: String {
        let preview = content.prefix(100)
        return "\(displayHeading) (\(pageRange)): \(preview)..."
    }
}
