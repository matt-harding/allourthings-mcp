import SwiftUI
import PDFKit

struct PDFViewerView: View {
    let pdfPath: String
    let pageNumber: Int?
    let itemName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if let pdfURL = PDFStorageHelper.shared.getPDFURL(for: pdfPath) {
                    PDFKitView(url: pdfURL, pageNumber: pageNumber)
                } else {
                    VStack(spacing: Theme.Spacing.medium) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.softGray)

                        Text("Manual not found")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.cocoaBrown)

                        Text("The PDF file could not be loaded.")
                            .font(Theme.Fonts.cosyBody())
                            .foregroundColor(Theme.Colors.softGray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(itemName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.blushPink)
                    .font(Theme.Fonts.cosyButton())
                }
            }
        }
    }
}

// MARK: - PDFKit UIViewRepresentable

struct PDFKitView: UIViewRepresentable {
    let url: URL
    let pageNumber: Int?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Only set document if it's not already set or if it's different
        if pdfView.document?.documentURL != url {
            if let document = PDFDocument(url: url) {
                pdfView.document = document

                // Navigate to specific page after a small delay to ensure PDF is rendered
                if let pageNum = pageNumber, pageNum > 0 {
                    let pageIndex = pageNum - 1 // Convert to 0-based index

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if pageIndex < document.pageCount,
                           let page = document.page(at: pageIndex) {
                            pdfView.go(to: page)
                        }
                    }
                }
            }
        }
    }
}
