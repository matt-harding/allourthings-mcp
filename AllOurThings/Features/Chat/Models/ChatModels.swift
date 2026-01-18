import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
    let itemsWithManuals: [ItemManualReference]
}

struct ItemManualReference {
    let itemName: String
    let manualFilePath: String
}

struct PDFViewerData: Identifiable {
    let id = UUID()
    let pdfPath: String
    let pageNumber: Int?
    let itemName: String
}
