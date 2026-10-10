import Foundation
import CoreGraphics
import ImageIO
import AppKit

public enum ThumbnailGenerator {
    public static let defaultMaxPixelSize: Int = 180

    public static func generateThumbnail(
        from imageData: Data,
        maxPixelSize: Int = defaultMaxPixelSize
    ) -> Data? {
        guard !imageData.isEmpty else { return nil }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        guard CGImageSourceGetCount(source) > 0 else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let rep = NSBitmapImageRep(cgImage: cgThumb)
        return rep.representation(using: .png, properties: [:])
    }

    public static func extractDimensions(from imageData: Data) -> (width: Int, height: Int)? {
        guard !imageData.isEmpty else { return nil }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        guard CGImageSourceGetCount(source) > 0 else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        let rawWidth = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let rawHeight = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard rawWidth > 0 && rawHeight > 0 else { return nil }

        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        if orientation >= 5 && orientation <= 8 {
            return (width: rawHeight, height: rawWidth)
        } else {
            return (width: rawWidth, height: rawHeight)
        }
    }

    public static func dimensions(for imageData: Data) -> (width: Int, height: Int)? {
        extractDimensions(from: imageData)
    }

    public static func isImagePayload(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0
    }
}
