import Foundation
import CoreGraphics

enum Constants {
    enum Storage {
        static let manualsDirectory = "Manuals"
        static let imagesDirectory = "Images"
    }

    enum Keychain {
        static let service = "com.allourthings.apikeys"
    }

    enum FileNames {
        static func photoFileName() -> String {
            "photo_\(Date().timeIntervalSince1970).png"
        }

        static func cameraFileName() -> String {
            "camera_\(Date().timeIntervalSince1970).png"
        }
    }

    enum Image {
        static let jpegCompressionQuality: CGFloat = 0.8
    }

    enum Dimensions {
        static let circularButtonSize: CGFloat = 44
        static let imagePreviewMaxHeight: CGFloat = 200
        static let itemRowImageHeight: CGFloat = 120
    }

    enum Timing {
        static let pdfPageNavigationDelay: TimeInterval = 0.1 // Wait for PDF to render before navigating
    }
}
