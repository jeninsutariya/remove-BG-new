//
//  BackgroundImageService.swift
//  Background Removal
//
//  Remote replacement backgrounds listed in `image_urls.json` (bundled resource).
//  Thumbnails and full images are downloaded and cached with SDWebImage.
//  These images are backgrounds only – they never go through background removal.
//

import UIKit
import SDWebImage

enum BackgroundImageError: LocalizedError {
    case catalogMissing
    case catalogInvalid(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .catalogMissing: return "image_urls.json is missing from the app bundle."
        case .catalogInvalid(let reason): return "image_urls.json couldn't be read: \(reason)"
        case .downloadFailed(let reason): return "The background image couldn't be downloaded. \(reason)"
        }
    }
}

final class BackgroundImageService {

    static let shared = BackgroundImageService()

    /// Thumbnail decode size for the gallery (keeps memory low while scrolling).
    static let thumbnailPixelSize = CGSize(width: 320, height: 320)

    private var cachedCatalog: [BackgroundImage]?

    /// Background list from `image_urls.json`. Accepts an array of objects or `{"images": [...]}`.
    func catalog() throws -> [BackgroundImage] {
        if let cachedCatalog { return cachedCatalog }
        guard let url = Bundle.main.url(forResource: "image_urls", withExtension: "json") else {
            throw BackgroundImageError.catalogMissing
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            var images: [BackgroundImage]
            if let list = try? decoder.decode([LossyBackgroundImage].self, from: data) {
                images = list.compactMap(\.value)
            } else {
                let wrapped = try decoder.decode([String: [LossyBackgroundImage]].self, from: data)
                images = wrapped.values.first?.compactMap(\.value) ?? []
            }
            // Remove duplicate ids while keeping the file order.
            var seen = Set<Int>()
            images = images.filter { seen.insert($0.id).inserted }
            cachedCatalog = images
            return images
        } catch {
            throw BackgroundImageError.catalogInvalid(error.localizedDescription)
        }
    }

    /// Loads a gallery thumbnail into an image view (lazy, cached, placeholder while loading).
    func setThumbnail(_ background: BackgroundImage, on imageView: UIImageView,
                      completion: @escaping (Bool) -> Void) {
        imageView.sd_imageIndicator = SDWebImageActivityIndicator.gray
        imageView.sd_setImage(with: background.image,
                              placeholderImage: nil,
                              options: [.retryFailed, .scaleDownLargeImages, .avoidAutoSetImage],
                              context: [.imageThumbnailPixelSize: NSValue(cgSize: Self.thumbnailPixelSize)],
                              progress: nil) { [weak imageView] image, error, _, _ in
            guard let imageView else { return }
            if let image {
                UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve) {
                    imageView.image = image
                }
            }
            completion(error == nil && image != nil)
        }
    }

    func cancelThumbnail(on imageView: UIImageView) {
        imageView.sd_cancelCurrentImageLoad()
    }

    /// Full image used for compositing (downloaded once, then served from SDWebImage's cache).
    func fullImage(for url: URL) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            SDWebImageManager.shared.loadImage(with: url, options: [.retryFailed, .scaleDownLargeImages], progress: nil) {
                image, _, error, _, finished, _ in
                guard finished, !resumed else { return }
                resumed = true
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: BackgroundImageError.downloadFailed(error?.localizedDescription ?? ""))
                }
            }
        }
    }
}

/// Skips individual malformed entries instead of failing the whole catalog.
private struct LossyBackgroundImage: Decodable {
    let value: BackgroundImage?

    init(from decoder: Decoder) throws {
        value = try? BackgroundImage(from: decoder)
    }
}
