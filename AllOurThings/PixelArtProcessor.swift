import UIKit
import CoreImage

// MARK: - Pixel Art Image Processor

class PixelArtProcessor {
    static let shared = PixelArtProcessor()
    private init() {}

    private let context = CIContext()

    // MARK: - Convert Image to Pixel Art

    func convertToPixelArt(imageData: Data, pixelScale: CGFloat = Constants.PixelArt.defaultPixelScale) -> Data? {
        guard let inputImage = UIImage(data: imageData),
              let ciImage = CIImage(image: inputImage) else {
            return nil
        }

        // Get original size
        let originalSize = ciImage.extent.size

        // Apply pixel art effect
        guard let pixelatedImage = applyPixelArtEffect(to: ciImage, pixelScale: pixelScale),
              let posterizedImage = applyPosterization(to: pixelatedImage),
              let sharpened = applySharpen(to: posterizedImage) else {
            return nil
        }

        // Render to UIImage
        guard let cgImage = context.createCGImage(sharpened, from: sharpened.extent) else {
            return nil
        }

        let resultImage = UIImage(cgImage: cgImage)

        // Resize to reasonable size (max dimension to keep file size down)
        let resizedImage = resizeImage(resultImage, maxDimension: Constants.PixelArt.maxImageDimension)

        // Convert to PNG data
        return resizedImage.pngData()
    }

    // MARK: - Apply Pixel Art Effect

    private func applyPixelArtEffect(to image: CIImage, pixelScale: CGFloat) -> CIImage? {
        // Apply pixellation filter
        guard let pixellateFilter = CIFilter(name: "CIPixellate") else {
            return nil
        }

        pixellateFilter.setValue(image, forKey: kCIInputImageKey)
        pixellateFilter.setValue(pixelScale, forKey: kCIInputScaleKey)

        return pixellateFilter.outputImage
    }

    // MARK: - Apply Posterization (Reduce Colors)

    private func applyPosterization(to image: CIImage) -> CIImage? {
        // Apply color posterize to reduce color palette (retro look)
        guard let posterizeFilter = CIFilter(name: "CIColorPosterize") else {
            return nil
        }

        posterizeFilter.setValue(image, forKey: kCIInputImageKey)
        posterizeFilter.setValue(Constants.PixelArt.colorPosterizeLevels, forKey: "inputLevels") // Color levels per channel for retro look

        return posterizeFilter.outputImage
    }

    // MARK: - Apply Sharpening

    private func applySharpen(to image: CIImage) -> CIImage? {
        // Sharpen to make pixels crisp
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else {
            return nil
        }

        sharpenFilter.setValue(image, forKey: kCIInputImageKey)
        sharpenFilter.setValue(Constants.PixelArt.sharpenIntensity, forKey: kCIInputSharpnessKey)

        return sharpenFilter.outputImage
    }

    // MARK: - Resize Image

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Calculate new size maintaining aspect ratio
        var newSize = size
        if size.width > maxDimension || size.height > maxDimension {
            let aspectRatio = size.width / size.height
            if size.width > size.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
        }

        // Render resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return resizedImage
    }
}
