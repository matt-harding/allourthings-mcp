import Foundation

// MARK: - PDF File Storage Helper

class PDFStorageHelper {
    static let shared = PDFStorageHelper()
    private init() {}

    private let fileManager = FileManager.default

    // MARK: - Get Manuals Directory

    private func getManualsDirectory() -> URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to get documents directory")
            return nil
        }

        let manualsDirectory = documentsDirectory.appendingPathComponent("Manuals", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: manualsDirectory.path) {
            do {
                try fileManager.createDirectory(at: manualsDirectory, withIntermediateDirectories: true)
                print("Created Manuals directory at: \(manualsDirectory.path)")
            } catch {
                print("Failed to create Manuals directory: \(error)")
                return nil
            }
        }

        return manualsDirectory
    }

    // MARK: - Save PDF

    func savePDF(from sourceURL: URL) -> String? {
        guard let manualsDirectory = getManualsDirectory() else {
            return nil
        }

        // Generate unique filename using timestamp
        let timestamp = Date().timeIntervalSince1970
        let originalFileName = sourceURL.lastPathComponent
        let fileName = "\(timestamp)_\(originalFileName)"
        let destinationURL = manualsDirectory.appendingPathComponent(fileName)

        do {
            // Start accessing security-scoped resource
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            // Copy file to manuals directory
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("PDF saved to: \(destinationURL.path)")

            // Return relative path (just the filename)
            return fileName
        } catch {
            print("Failed to save PDF: \(error)")
            return nil
        }
    }

    // MARK: - Get PDF URL

    func getPDFURL(for relativePath: String) -> URL? {
        guard let manualsDirectory = getManualsDirectory() else {
            return nil
        }

        let pdfURL = manualsDirectory.appendingPathComponent(relativePath)

        guard fileManager.fileExists(atPath: pdfURL.path) else {
            print("PDF not found at: \(pdfURL.path)")
            return nil
        }

        return pdfURL
    }

    // MARK: - Delete PDF

    func deletePDF(at relativePath: String) {
        guard let pdfURL = getPDFURL(for: relativePath) else {
            return
        }

        do {
            try fileManager.removeItem(at: pdfURL)
            print("Deleted PDF at: \(pdfURL.path)")
        } catch {
            print("Failed to delete PDF: \(error)")
        }
    }
}
