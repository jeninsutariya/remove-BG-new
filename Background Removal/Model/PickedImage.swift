//
//  PickedImage.swift
//  Background Removal
//
//  A photo chosen in ImageSourcePickerVC. Gallery picks are kept as temporary files
//  (not decoded) so selecting many photos doesn't load every full-resolution bitmap at once.
//

import UIKit

nonisolated struct PickedImage: Sendable {
    enum Source: Sendable {
        case file(URL)
        case image(UIImage)
    }

    let source: Source
    /// Name from the photo library (e.g. "IMG_1234"), used for export file names.
    let suggestedName: String?

    /// Decodes the photo upright, with its longest side ≤ `maxPixel`.
    func loadImage(maxPixel: CGFloat) -> UIImage? {
        switch source {
        case .file(let url):
            return ImageUtilities.downsampledImage(at: url, maxPixel: maxPixel)
        case .image(let image):
            let longest = max(image.size.width, image.size.height) * image.scale
            if longest <= maxPixel, image.imageOrientation == .up { return image }
            return ImageUtilities.uprightCGImage(from: image, maxDimension: maxPixel).map {
                UIImage(cgImage: $0, scale: 1, orientation: .up)
            }
        }
    }

    /// Removes the temporary copy made by the picker.
    func discardTemporaryFile() {
        if case .file(let url) = source {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
