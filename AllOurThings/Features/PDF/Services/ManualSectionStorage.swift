import Foundation

// MARK: - Manual Section Storage Helper

class ManualSectionStorage {
    static let shared = ManualSectionStorage()
    private init() {}

    private let fileManager = FileManager.default

    // MARK: - Get Sections Directory

    private func getSectionsDirectory() -> URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to get documents directory")
            return nil
        }

        let sectionsDirectory = documentsDirectory.appendingPathComponent("ManualSections", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: sectionsDirectory.path) {
            do {
                try fileManager.createDirectory(at: sectionsDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create sections directory: \(error)")
                return nil
            }
        }

        return sectionsDirectory
    }

    // MARK: - Save Section

    func saveSection(_ section: SectionData, for itemId: UUID, sectionIndex: Int) -> String? {
        guard let sectionsDirectory = getSectionsDirectory() else {
            return nil
        }

        // Generate filename: {itemId}_{sectionIndex}_{sanitizedHeading}.txt
        let sanitizedHeading = sanitizeFilename(section.heading)
        let fileName = "\(itemId.uuidString)_\(sectionIndex)_\(sanitizedHeading).txt"
        let fileURL = sectionsDirectory.appendingPathComponent(fileName)

        do {
            // Create section content with metadata
            let fullContent = """
            HEADING: \(section.heading)
            PAGES: \(section.pageNumbers.map(String.init).joined(separator: ", "))

            \(section.content)
            """

            try fullContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileName
        } catch {
            print("Failed to save section: \(error)")
            return nil
        }
    }

    // MARK: - Load Section

    func loadSection(from fileName: String) -> String? {
        guard let sectionsDirectory = getSectionsDirectory() else {
            return nil
        }

        let fileURL = sectionsDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return try? String(contentsOf: fileURL, encoding: .utf8)
    }

    // MARK: - Delete Section

    func deleteSection(fileName: String) {
        guard let sectionsDirectory = getSectionsDirectory() else {
            return
        }

        let fileURL = sectionsDirectory.appendingPathComponent(fileName)

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print("Failed to delete section (may already be deleted): \(error)")
        }
    }

    // MARK: - Delete All Sections for Item

    func deleteSectionsForItem(itemId: UUID) {
        guard let sectionsDirectory = getSectionsDirectory() else {
            return
        }

        guard let files = try? fileManager.contentsOfDirectory(atPath: sectionsDirectory.path) else {
            return
        }

        let prefix = itemId.uuidString
        for file in files where file.hasPrefix(prefix) {
            let fileURL = sectionsDirectory.appendingPathComponent(file)
            try? fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Helper: Sanitize Filename

    private func sanitizeFilename(_ string: String) -> String {
        // Remove special characters and limit length
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = string.components(separatedBy: allowed.inverted).joined()
        return String(sanitized.prefix(50))
    }
}
