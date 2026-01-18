import Foundation

// MARK: - Image File Storage Helper

class ImageStorageHelper {
    static let shared = ImageStorageHelper()
    private init() {}

    private let fileManager = FileManager.default

    // MARK: - Get Images Directory

    private func getImagesDirectory() -> URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to get documents directory")
            return nil
        }

        let imagesDirectory = documentsDirectory.appendingPathComponent(Constants.Storage.imagesDirectory, isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: imagesDirectory.path) {
            do {
                try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create images directory: \(error)")
                return nil
            }
        }

        return imagesDirectory
    }

    // MARK: - Save Image

    func saveImage(_ imageData: Data, originalFileName: String) -> String? {
        guard let imagesDirectory = getImagesDirectory() else {
            return nil
        }

        // Generate unique filename using timestamp
        let timestamp = Date().timeIntervalSince1970
        let fileName = "\(timestamp)_\(originalFileName)"
        let destinationURL = imagesDirectory.appendingPathComponent(fileName)

        do {
            // Write image data to file
            try imageData.write(to: destinationURL)

            // Return relative path (just the filename)
            return fileName
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    // MARK: - Get Image URL

    func getImageURL(for relativePath: String) -> URL? {
        guard let imagesDirectory = getImagesDirectory() else {
            return nil
        }

        let imageURL = imagesDirectory.appendingPathComponent(relativePath)

        guard fileManager.fileExists(atPath: imageURL.path) else {
            return nil
        }

        return imageURL
    }

    // MARK: - Delete Image

    func deleteImage(at relativePath: String) {
        guard let imageURL = getImageURL(for: relativePath) else {
            return
        }

        do {
            try fileManager.removeItem(at: imageURL)
        } catch {
            // Silently fail - file might already be deleted
            print("Failed to delete image (may already be deleted): \(error)")
        }
    }

}
